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

/// 포모도로 사이클 상수. DEBUG는 검수를 위해 대폭 단축한다.
enum PomodoroConfig {
    #if DEBUG
    static let focusBlock = 10      // 집중 블록(초) — 검수용
    static let breakLength = 5       // 휴식(초) — 검수용
    static let hatchThreshold = 30   // 누적 집중 부화 임계(초) — 검수용
    #else
    static let focusBlock = 25 * 60      // 25분 집중
    static let breakLength = 5 * 60      // 5분 휴식
    static let hatchThreshold = 60 * 60  // 누적 1시간이면 부화
    #endif
}

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

    private var _mode: TimerMode = .free
    /// 타이머 모드(idle일 때만 변경 가능). pomodoro면 25/5 사이클 + 누적 1시간 부화.
    var mode: TimerMode {
        get { _mode }
        set { if session == nil { _mode = newValue } }
    }

    private var ticker: Timer?
    private let clock: () -> Date
    private let persists: Bool
    private static let persistKey = "active_session_v2"

    /// 세션이 끝날 때(완료/중단) 결과를 전달(영속/통계 기록용). HomeView가 주입.
    var onSessionEnd: ((FocusSessionResult) -> Void)?

    /// 현재 동료 캐릭터 id(HomeView가 동료 변화 시 주입). 세션 결과에 귀속 → 진화 단계 정확화.
    /// 알 단계(동료 없음)에선 nil.
    var companionID: UUID?

    /// 충전 중 "찌릿" 보너스로 추가된 부화 진행 초(A+ 기믹). 세션 시작 시 0으로 리셋(비영속).
    private var bonusSeconds = 0

    // 이탈 추적(Feature 6) — 현재 세션 누적.
    private var interruptionCount = 0
    private var distracted = false
    private var leftAt: Date?
    /// 직전 포그라운드 복귀 시 이탈했던 시간(초). 복귀 대사 버킷 판정용. 0 = 이탈 없음.
    private(set) var lastAwaySeconds: Int = 0

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
    /// 활성 집중 중(휴식은 제외).
    var isRunning: Bool { session?.phase == .running && !isOnBreak }
    var isPaused: Bool { session?.phase == .paused }
    var isCompleted: Bool { session?.phase == .completed }

    /// 포모도로 휴식 중인지.
    var isOnBreak: Bool { session?.isOnBreak ?? false }
    /// 현재 모드(진행 중이면 세션 모드, idle이면 선택 모드).
    var activeMode: TimerMode { session?.mode ?? mode }

    /// 표시용 목표 시간(idle이면 모드별 기본, 진행 중이면 세션값).
    private var targetSeconds: Int {
        session?.plannedSeconds ?? (mode == .pomodoro ? PomodoroConfig.hatchThreshold : plannedSeconds)
    }

    /// 남은 시간(초). idle이면 목표 전체.
    var remainingSeconds: Int { max(targetSeconds - activeSecondsLive, 0) }

    /// 타이머에 표시할 카운트다운(초). 휴식 중=휴식 남은시간, 포모도로 집중=다음 휴식/부화까지, free=목표까지.
    var countdownSeconds: Int {
        if isOnBreak { return breakRemainingSeconds }
        guard let s = session else {
            return mode == .pomodoro ? PomodoroConfig.focusBlock : plannedSeconds
        }
        if s.mode == .pomodoro {
            return max(min(s.nextBreakAt, s.plannedSeconds) - activeSecondsLive, 0)
        }
        return max(s.plannedSeconds - activeSecondsLive, 0)
    }

    /// 휴식 남은 시간(초).
    var breakRemainingSeconds: Int {
        guard let end = session?.breakEndsAt else { return 0 }
        return max(0, Int(end.timeIntervalSince(clock())))
    }

    /// 현재(진행/완료한) 집중 블록 번호(1부터). 포모도로 캡션용.
    var pomodoroBlock: Int {
        let total = PomodoroConfig.hatchThreshold / PomodoroConfig.focusBlock
        return min(activeSecondsLive / PomodoroConfig.focusBlock + 1, max(total, 1))
    }

    /// 진행도 0...1.
    var progress: Double {
        guard targetSeconds > 0 else { return 0 }
        return min(Double(activeSecondsLive) / Double(targetSeconds), 1)
    }

    /// 알 이미지 단계(0...5) — EggState와 동일 규칙. (부화 진행 스텝퍼용)
    var stageIndex: Int {
        min(max(Int(progress * Double(EggState.visualStages)), 0), EggState.visualStages - 1)
    }

    /// 알 이미지 7단계 인덱스(0...6). 진행도 7분할.
    /// Egg0(무결) → 2egg → secondcrack → thirdcrack → 3egg → 4egg → 4-2egg(부화 직전 황금 균열, 두근두근).
    /// 목표 도달 시 부화 버스트(4-3egg→4-7egg) → 몬스터.
    var eggStageIndex: Int {
        min(max(Int(progress * 7), 0), 6)
    }

    /// "MM:SS" 타이머 표시(맥락별 카운트다운).
    var timerDisplay: String {
        let s = countdownSeconds
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    /// 부화 진행 스텝 캡션 "n/6".
    var stageCaption: String { "\(stageIndex + 1)/\(EggState.visualStages)" }

    /// 상태 문구.
    var statusText: String {
        if isOnBreak { return "잠깐 쉬어가요 ☕" }
        switch phase {
        case .running:   return activeMode == .pomodoro ? "집중 블록 \(pomodoroBlock) 진행 중" : "집중하는 중이에요"
        case .paused:    return "잠시 멈췄어요"
        case .completed: return "부화 준비 완료!"
        case nil:        return "집중할 준비가 되었나요?"
        }
    }

    // MARK: - 생명주기

    func start() {
        guard session == nil else { return }
        let planned = mode == .pomodoro ? PomodoroConfig.hatchThreshold : plannedSeconds
        let nextBreak = mode == .pomodoro ? PomodoroConfig.focusBlock : Int.max
        var s = ActiveSession(plannedSeconds: planned, startedAt: clock(), mode: mode, nextBreakAt: nextBreak)
        s.phase = .running
        session = s
        activeSecondsLive = 0
        bonusSeconds = 0
        interruptionCount = 0
        distracted = false
        leftAt = nil
        ScreenAwake.set(true)
        startTicker()
        persist()
    }

    func pause() {
        guard var s = session, s.phase == .running, !s.isOnBreak else { return }
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

    /// scenePhase 복귀·틱에서 호출. 휴식 종료/휴식 진입/목표 도달을 처리한다.
    func recompute() {
        guard let s = session else { return }
        let now = clock()

        // 휴식 중: 카운트다운만, 종료 시 집중 재개.
        if s.isOnBreak {
            if let end = s.breakEndsAt, now >= end { endBreak(at: now) }
            return
        }

        // 타임스탬프 유효 집중초 + 충전 보너스(목표치로 캡).
        activeSecondsLive = min(s.activeSeconds(now: now) + bonusSeconds, s.plannedSeconds)

        // 포모도로: 다음 휴식 도달 & 아직 부화 전 → 휴식 진입.
        if s.mode == .pomodoro, s.phase == .running,
           activeSecondsLive >= s.nextBreakAt, activeSecondsLive < s.plannedSeconds {
            enterBreak(at: now)
            return
        }

        if s.phase == .running, activeSecondsLive >= s.plannedSeconds {
            complete()
        }
    }

    /// 포모도로 휴식 진입: 집중 누적 고정 + 5분 휴식 시작 + 다음 휴식 지점 전진.
    private func enterBreak(at now: Date) {
        guard var s = session else { return }
        s.accumulatedActiveSeconds = s.activeSeconds(now: now)
        s.lastResumedAt = nil
        s.breakEndsAt = now.addingTimeInterval(Double(PomodoroConfig.breakLength))
        s.nextBreakAt += PomodoroConfig.focusBlock
        session = s
        activeSecondsLive = s.accumulatedActiveSeconds
        ScreenAwake.set(false)
        persist()
    }

    /// 휴식 종료(자동/건너뛰기) → 집중 재개.
    private func endBreak(at now: Date) {
        guard var s = session, s.isOnBreak else { return }
        s.breakEndsAt = nil
        s.lastResumedAt = now
        s.phase = .running
        session = s
        ScreenAwake.set(true)
        recompute()
        persist()
    }

    /// 휴식 건너뛰고 바로 다음 집중 블록 시작.
    func skipBreak() {
        guard isOnBreak else { return }
        endBreak(at: clock())
    }

    /// 백그라운드 진입 시: 집중 중이면 **자동 일시정지**(누적 고정, 백그라운드 시간 미포함).
    /// 세션은 유지되므로 복귀/재실행 시 이어서 진행(초기화 아님). 이탈 시작 시각도 기록(복귀 분류용).
    /// 휴식 중 이탈은 집중 이탈로 치지 않으며 휴식 카운트다운은 계속 흐른다.
    func handleBackground() {
        if isRunning, var s = session {
            leftAt = clock()
            s.accumulatedActiveSeconds = s.activeSeconds(now: clock())
            s.lastResumedAt = nil        // 벽시계 카운트 정지(누적만 남김)
            session = s
            stopTicker()
            persist()
        }
        ScreenAwake.set(false)
    }

    /// 포그라운드 복귀 시: 이탈 시간 분류 → 얼려둔 집중 자동 재개 → 재계산 → 화면 유지 재적용.
    func handleForeground() {
        if let left = leftAt, isRunning {
            let away = max(0, Int(clock().timeIntervalSince(left)))
            lastAwaySeconds = away
            let severity = Interruption.severity(awaySeconds: away)
            if severity.counts { interruptionCount += 1 }
            if severity == .distracted { distracted = true }
        } else {
            lastAwaySeconds = 0
        }
        leftAt = nil
        // 백그라운드에서 얼려둔 집중 재개(누적 유지, 지금부터 다시 카운트).
        if var s = session, s.phase == .running, !s.isOnBreak, s.lastResumedAt == nil {
            s.lastResumedAt = clock()
            session = s
            startTicker()
        }
        recompute()
        if isRunning { ScreenAwake.set(true) }
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
            completed: completed,
            companionID: companionID,
            mode: s.mode
        )
    }

    /// 충전 중 "찌릿" 부화 보너스(A+ 기믹). 집중 중일 때만, 목표의 fraction만큼 진행도 추가.
    /// 반환: 실제 적용된 보너스 비율(0이면 미적용). 표시용.
    @discardableResult
    func applyChargeBonus(fraction: Double) -> Double {
        guard isRunning, let s = session else { return 0 }
        let add = max(1, Int(Double(s.plannedSeconds) * fraction))
        bonusSeconds += add
        recompute()
        persist()
        return Double(add) / Double(max(s.plannedSeconds, 1))
    }

    private func clearSession() {
        session = nil
        activeSecondsLive = 0
        bonusSeconds = 0
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
              var s = try? JSONDecoder().decode(ActiveSession.self, from: data)
        else { return }

        // 콜드런치 = 포그라운드 진입. 백그라운드에서 얼려둔(lastResumedAt=nil) 집중을 재개.
        // 휴식 중이면 건드리지 않음(휴식 카운트다운은 recompute가 처리).
        if s.phase == .running, !s.isOnBreak, s.lastResumedAt == nil {
            s.lastResumedAt = clock()
        }
        session = s
        activeSecondsLive = s.activeSeconds(now: clock())
        switch s.phase {
        case .running:
            startTicker()
            recompute()   // 백그라운드 동안의 휴식 종료/목표 도달을 즉시 반영
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
