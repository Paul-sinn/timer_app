//
//  SessionManager.swift
//  Eggtimer
//
//  집중 세션의 단일 소스(Feature 1). 상태머신(idle→running↔paused→completed)을
//  타임스탬프 기반으로 운영하고, 화면 갱신용 1초 틱과 scenePhase 복귀 시 재계산을 한다.
//  활성 세션 1건은 UserDefaults에 즉시 영속 → 강제종료/크래시 후 복구(이어하기/완료).
//  실제 영속 이력(SwiftData)·통계 연동은 Phase 2-2 범위.
//
//  성장/부화 규칙은 EggState와 동일: 진행도(0...1) → 6단계 알 이미지, 목표 도달 시 부화.
//

import SwiftUI

@Observable
@MainActor
final class SessionManager {
    /// 인사용 표시 이름.
    let displayName: String

    /// 진행 중 세션(nil = idle).
    private(set) var session: ActiveSession?

    /// 화면 갱신을 구동하는 실시간 유효 집중초(틱마다 갱신 → Observation 트리거).
    private(set) var activeSecondsLive: Int = 0

    private var _plannedSeconds: Int

    /// 다음 세션의 목표 시간(초). idle일 때만 변경 가능(진행 중엔 무시).
    var plannedSeconds: Int {
        get { _plannedSeconds }
        set { if session == nil { _plannedSeconds = newValue } }
    }

    private var ticker: Timer?
    private let clock: () -> Date
    private let persists: Bool
    private static let persistKey = "active_session_v1"

    /// 세션이 끝날 때(완료/중단) 결과를 전달(영속/통계 기록용). HomeView가 주입.
    var onSessionEnd: ((FocusSessionResult) -> Void)?

    // 이탈 추적(Feature 6) — 현재 세션 누적.
    private var interruptionCount = 0
    private var distracted = false
    private var leftAt: Date?

    init(plannedSeconds: Int = 25 * 60,
         displayName: String = "집중하는 너구리",
         clock: @escaping () -> Date = { Date() },
         persists: Bool = true) {
        self._plannedSeconds = plannedSeconds
        self.displayName = displayName
        self.clock = clock
        self.persists = persists
        restore()
    }

    // MARK: - 파생 상태

    var phase: SessionPhase? { session?.phase }
    var isIdle: Bool { session == nil }
    var isRunning: Bool { session?.phase == .running }
    var isPaused: Bool { session?.phase == .paused }
    var isCompleted: Bool { session?.phase == .completed }

    /// 표시용 목표 시간(idle이면 선택값, 진행 중이면 세션값).
    private var targetSeconds: Int { session?.plannedSeconds ?? plannedSeconds }

    /// 남은 시간(초). idle이면 목표 전체.
    var remainingSeconds: Int { max(targetSeconds - activeSecondsLive, 0) }

    /// 진행도 0...1.
    var progress: Double {
        guard targetSeconds > 0 else { return 0 }
        return min(Double(activeSecondsLive) / Double(targetSeconds), 1)
    }

    /// 알 이미지 단계(0...5) — EggState와 동일 규칙.
    var stageIndex: Int {
        min(max(Int(progress * Double(EggState.visualStages)), 0), EggState.visualStages - 1)
    }

    /// "MM:SS" 타이머 표시(남은 시간).
    var timerDisplay: String {
        let s = remainingSeconds
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    /// 부화 진행 스텝 캡션 "n/6".
    var stageCaption: String { "\(stageIndex + 1)/\(EggState.visualStages)" }

    /// 상태 문구.
    var statusText: String {
        switch phase {
        case .running:   return "집중하는 중이에요"
        case .paused:    return "잠시 멈췄어요"
        case .completed: return "부화 준비 완료!"
        case nil:        return "집중할 준비가 되었나요?"
        }
    }

    // MARK: - 생명주기

    func start() {
        guard session == nil else { return }
        var s = ActiveSession(plannedSeconds: plannedSeconds, startedAt: clock())
        s.phase = .running
        session = s
        activeSecondsLive = 0
        interruptionCount = 0
        distracted = false
        leftAt = nil
        ScreenAwake.set(true)
        startTicker()
        persist()
    }

    func pause() {
        guard var s = session, s.phase == .running else { return }
        s.accumulatedActiveSeconds = s.activeSeconds(now: clock())
        s.lastResumedAt = nil
        s.phase = .paused
        session = s
        stopTicker()
        ScreenAwake.set(false)
        persist()
    }

    func resume() {
        guard var s = session, s.phase == .paused else { return }
        s.lastResumedAt = clock()
        s.phase = .running
        session = s
        ScreenAwake.set(true)
        startTicker()
        recompute()
        persist()
    }

    /// 중단(부화 없음). 의미 있는 집중이 있었으면 미완료 세션으로 기록.
    func stop() {
        recompute()
        if let s = session, activeSecondsLive > 0 {
            onSessionEnd?(buildResult(from: s, completed: false))
        }
        clearSession()
    }

    /// 완료 처리 후 호출 — 부화 소비가 끝났으니 idle로 리셋.
    func acknowledgeCompletion() {
        guard session?.phase == .completed else { return }
        clearSession()
    }

    // MARK: - 틱 / 재계산

    /// scenePhase 복귀·틱에서 호출. running 중 목표 도달 시 완료 전이.
    func recompute() {
        guard let s = session else { return }
        activeSecondsLive = s.activeSeconds(now: clock())
        if s.phase == .running, s.isComplete(now: clock()) {
            complete()
        }
    }

    /// 백그라운드 진입 시(화면 유지 해제). 진행은 타임스탬프로 보존되므로 멈추지 않는다.
    /// running 중 이탈이면 이탈 시작 시각을 기록(복귀 시 분류).
    func handleBackground() {
        if session?.phase == .running { leftAt = clock() }
        ScreenAwake.set(false)
    }

    /// 포그라운드 복귀 시: 이탈 시간 분류 → 재계산 → 화면 유지 재적용.
    func handleForeground() {
        if let left = leftAt, session?.phase == .running {
            let away = max(0, Int(clock().timeIntervalSince(left)))
            let severity = Interruption.severity(awaySeconds: away)
            if severity.counts { interruptionCount += 1 }
            if severity == .distracted { distracted = true }
        }
        leftAt = nil
        recompute()
        if session?.phase == .running { ScreenAwake.set(true) }
    }

    private func complete() {
        guard var s = session else { return }
        s.accumulatedActiveSeconds = s.plannedSeconds
        s.lastResumedAt = nil
        s.phase = .completed
        session = s
        activeSecondsLive = s.plannedSeconds
        stopTicker()
        ScreenAwake.set(false)
        onSessionEnd?(buildResult(from: s, completed: true))
        persist()
    }

    /// 현재 누적 상태로 세션 결과 값을 만든다.
    private func buildResult(from s: ActiveSession, completed: Bool) -> FocusSessionResult {
        FocusSessionResult(
            startedAt: s.startedAt,
            plannedSeconds: s.plannedSeconds,
            activeSeconds: activeSecondsLive,
            interruptionCount: interruptionCount,
            distracted: distracted,
            completed: completed
        )
    }

    private func clearSession() {
        session = nil
        activeSecondsLive = 0
        stopTicker()
        ScreenAwake.set(false)
        UserDefaults.standard.removeObject(forKey: Self.persistKey)
    }

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.recompute() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    // MARK: - 영속 / 복구

    private func persist() {
        guard persists, let s = session else { return }
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: Self.persistKey)
        }
    }

    private func restore() {
        guard persists,
              let data = UserDefaults.standard.data(forKey: Self.persistKey),
              let s = try? JSONDecoder().decode(ActiveSession.self, from: data)
        else { return }

        session = s
        activeSecondsLive = s.activeSeconds(now: clock())
        switch s.phase {
        case .running:
            if s.isComplete(now: clock()) { complete() }   // 백그라운드 동안 완료된 경우
            else { startTicker() }
        case .paused, .completed:
            break
        }
    }
}

extension SessionManager {
    /// 검수/프리뷰용: 특정 진행도에서 일시정지된 세션을 가진 매니저(영속 X).
    static func preview(progress: Double, plannedSeconds: Int = 60 * 60,
                        displayName: String = "집중하는 너구리") -> SessionManager {
        let m = SessionManager(plannedSeconds: plannedSeconds, displayName: displayName, persists: false)
        var s = ActiveSession(plannedSeconds: plannedSeconds, startedAt: Date(), phase: .paused)
        s.accumulatedActiveSeconds = Int(Double(plannedSeconds) * min(max(progress, 0), 1))
        m.session = s
        m.activeSecondsLive = s.accumulatedActiveSeconds
        return m
    }
}
