//
//  HomeView.swift
//  Eggtimer
//
//  홈 탭. 다크+골드 톤. 헤더 / 집중 시간 선택 칩 / 대형 타이머 / 중앙 픽셀 알 /
//  6단계 부화 진행도 / 시작·일시정지·이어서·중단 컨트롤.
//  실제 동작: SessionManager가 타임스탬프 기반으로 카운트다운하고, 목표 도달 시
//  확률표대로 자동 부화 → 결과 시트 → 컬렉션 반영. (Feature 1·2·7)
//

import SwiftUI
import AudioToolbox

struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var session: SessionManager
    private let store: CollectionStore
    private let history: FocusHistoryStore
    /// 로그인 시 부화·세션종료를 원격에 동기화(비로그인 시 무시).
    private let sync: SyncCoordinator?
    /// 부화 후 알 자리를 대체해 표시 중인 생명체("새 알 받기" 전까지 유지).
    @State private var hatchling: Creature?
    /// 캐릭터 말풍선 대사 선택기(Feature 4).
    @State private var dialogue = DialogueManager()
    /// 이번 세션에서 마지막으로 focus tick을 발화한 분. 3분 간격 중복 방지.
    @State private var lastTickMinute = 0
    /// 이번 세션에서 마지막으로 발화한 알 마일스톤(분). 알의 의심→존중→자부심 서사.
    @State private var lastMilestone = 0
    /// 방금 진화한 단계(연출/문구 노출용, 잠시 후 nil). nil = 진화 연출 없음.
    @State private var justEvolvedStage: Int?
    /// 현재 동료의 id(영속). 콜드런치(앱 재시작) 후 컬렉션에서 같은 개체를 복원해 홈에 다시 표시.
    /// 빈 문자열 = 동료 없음(첫 부화 전 또는 '새 알 받기' 직후).
    @AppStorage("companionCreatureID") private var companionID = ""
    /// 부화 순간 borneffect.png 버스트 연출 활성(잠시 후 false).
    @State private var bornEffect = false
    /// 충전 감지(A+ 기믹). 충전 중 집중하면 알이 찌릿하며 부화 살짝 가속.
    @State private var battery = BatteryMonitor()
    /// 찌릿 스파크 연출 순간 토글.
    @State private var zapFlash = false
    /// 직전 찌릿으로 받은 보너스 %(표시용, 잠시 후 nil).
    @State private var zapBonusPercent: Int?
    /// 설정 시트 표시(우상단 기어).
    @State private var showSettings = false
    /// 효과음(부화·진화 시스템 사운드) 사용 여부. 설정 시트와 같은 키를 공유.
    @AppStorage(AppSettings.soundKey) private var soundEnabled = AppSettings.defaultOn
    /// 진동(부화·진화·휴식 진입 햅틱) 사용 여부.
    @AppStorage(AppSettings.hapticsKey) private var hapticsEnabled = AppSettings.defaultOn
    /// 로컬 알림 사용 여부. 백그라운드 알림 예약·권한 요청을 게이트.
    @AppStorage(AppSettings.notificationsKey) private var notificationsEnabled = AppSettings.defaultOn

    /// 집중 중 대사 발화 간격(분). 3분마다 현재 화자 풀에서 한마디.
    private static let tickIntervalMinutes = 3
    /// 알(부화 전) 서사 마일스톤(분). 의심→존중→자부심으로 톤이 진화하는 지점.
    private static let eggMilestones = [5, 10, 15, 30, 45, 60]
    /// 연속일에 해당하는 가장 높은 스트릭 임계값(없으면 nil).
    private static func streakThreshold(for streak: Int) -> Int? {
        [100, 30, 7, 3].first { streak >= $0 }
    }

    init(session: SessionManager,
         store: CollectionStore = CollectionStore(),
         history: FocusHistoryStore = FocusHistoryStore(),
         sync: SyncCoordinator? = nil) {
        _session = State(initialValue: session)
        self.store = store
        self.history = history
        self.sync = sync
    }

    /// 집중 시간 선택지(초). DEBUG에서는 빠른 검수용 10초 포함.
    private var durationOptions: [(label: String, seconds: Int)] {
        #if DEBUG
        return [("10초 (테스트)", 10), ("25분", 25 * 60), ("50분", 50 * 60)]
        #else
        return [("25분", 25 * 60), ("50분", 50 * 60)]
        #endif
    }

    private var selectedDurationLabel: String {
        durationOptions.first { $0.seconds == session.plannedSeconds }?.label ?? "집중 모드"
    }

    /// 포모도로 안내 캡션(집중/휴식/부화 임계).
    private var pomodoroCaption: String {
        let f = PomodoroConfig.focusBlock, b = PomodoroConfig.breakLength, h = PomodoroConfig.hatchThreshold
        func fmt(_ s: Int) -> String { s >= 60 ? "\(s / 60)분" : "\(s)초" }
        return "\(fmt(f)) 집중 · \(fmt(b)) 휴식 · 누적 \(fmt(h))이면 부화"
    }

    /// 부화 처리(자동·수동 공통 단일 진입점). 캐릭터를 알 자리에 유지하고 성격대로 인사시킨다.
    private func triggerHatch() {
        guard hatchling == nil, !bornEffect else { return }   // 중복 방지(버스트 중 재진입 차단)
        let born = store.hatch()                      // 확률 부화 + 컬렉션 반영(영속)
        sync?.pushNewCreature(born)                   // 로그인 시 원격 동기화
        if soundEnabled { AudioServicesPlaySystemSound(1025) }   // 부화 효과음(설정 게이트)
        bornEffect = true                             // 알 자리에 버스트 재생(몬스터 아직 X)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(660))   // 버스트 재생(5프레임 × 120ms + 여유)
            hatchling = born                          // 버스트 끝 → 태어난 캐릭터 노출
            companionID = born.id.uuidString          // 콜드런치 복원용 영속
            session.companionID = born.id             // 이후 세션을 이 캐릭터에 귀속(진화 단계)
            dialogue.fire(.greeting, speaker: .creature(born.personality))  // 성격 대사
            session.acknowledgeCompletion()           // 완료 소비 → idle, 인라인 리빌 노출
            bornEffect = false
        }
    }

    /// 집중 시작(시작/이어서 집중) — 알림 권한을 1회 요청하고 세션을 시작한다.
    private func beginFocus() {
        justEvolvedStage = nil
        if notificationsEnabled { Task { await FocusNotifier.requestAuthorization() } }
        session.start()
    }

    /// 현재 동료를 보내고 새 알을 받는다(진행 중이면 세션 중단·기록 후 알로 리셋).
    private func takeNewEgg() {
        session.stop()
        hatchling = nil
        justEvolvedStage = nil
        companionID = ""                              // 의도적으로 동료 비움 → 복원 안 함
        session.companionID = nil                     // 알 단계 세션은 귀속 없음
    }

    /// 콜드런치 후 저장된 동료를 컬렉션에서 복원(개체가 남아있을 때만).
    private func restoreCompanionIfNeeded() {
        guard hatchling == nil, !companionID.isEmpty else { return }
        if let saved = store.creatures.first(where: { $0.id.uuidString == companionID }) {
            hatchling = saved
            session.companionID = saved.id            // 복원된 동료에 이후 세션 귀속
        } else {
            companionID = ""                          // 개체가 사라졌으면(삭제 등) 플래그 정리
        }
    }

    /// 백그라운드 진입 시 다음 전환(부화/휴식 종료)까지 남은 실시간에 1회 알림 예약.
    private func scheduleFocusNotification() {
        guard notificationsEnabled else { return }   // 알림 끄면 예약 안 함
        if session.isOnBreak {
            FocusNotifier.schedule(title: "휴식 끝! ☕️",
                                   body: "다시 집중할 시간이에요.",
                                   after: session.breakRemainingSeconds)
        } else if session.isRunning {
            let secs = session.countdownSeconds
            if secs >= session.remainingSeconds {   // 다음 전환이 목표 도달(부화)
                FocusNotifier.schedule(title: "부화 준비 완료! 🥚",
                                       body: "집중이 끝났어요. 앱을 열어 부화를 확인하세요.",
                                       after: secs)
            } else {                                 // 다음 전환이 포모도로 휴식
                FocusNotifier.schedule(title: "휴식 시간이에요 ☕️",
                                       body: "잠깐 쉬어가요.",
                                       after: secs)
            }
        }
    }

    var body: some View {
        ZStack {
            AppColor.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                if session.isIdle && hatchling == nil {
                    modeAndDurationSection
                }
                timerHeader
                    .padding(.top, AppSpacing.element)
                dialogueBubble
                    .padding(.top, AppSpacing.elementTight)
                centerStage
                    .overlay(alignment: .topTrailing) {
                        if battery.isCharging && !bornEffect { chargeBadge.padding(6) }   // 알 옆 충전 표시
                    }
                    .overlay { if zapFlash { ZapBurstView().allowsHitTesting(false) } }    // 찌릿 스파크
                    .padding(.vertical, AppSpacing.elementTight)
                if hasCompanion && !session.isOnBreak {
                    EvolutionBadge(stage: companionStage)
                        .animation(.easeInOut(duration: 0.3), value: companionStage)
                }
                if justHatched, let hatchling {
                    HatchRevealCard(creature: hatchling)
                        .padding(.top, AppSpacing.elementTight)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                Spacer(minLength: 0)
                if !hasCompanion && !session.isOnBreak { progressSection }
                controlButtons
                    .padding(.top, AppSpacing.element)
            }
            .padding(.horizontal, AppSpacing.section)
            .animation(.easeInOut(duration: 0.3), value: hasCompanion)
        }
        .onChange(of: session.isCompleted) { _, completed in
            guard completed else { return }
            if hatchling == nil {
                triggerHatch()                    // 첫 부화: 알 → 캐릭터
            } else if companionStage >= Creature.maxEvolutionStage {
                // 최종 진화 상태: 더 진화할 게 없으니 멈춤·연출·선택 없이 다음 집중을 끊김없이 이어감.
                session.acknowledgeCompletion()
                session.start()
            } else {
                session.acknowledgeCompletion()   // 비최종: idle → 진화 연출 + 이어서/새 알 선택
            }
        }
        .onChange(of: companionStage) { old, new in
            // 동료가 한 단계 진화(이어서 집중 1세션 완료). 등장 연출은 centerStage의 .id 변화가 재생.
            guard new > old, hatchling != nil else { return }
            justEvolvedStage = new
            if soundEnabled { AudioServicesPlaySystemSound(1025) }   // 진화 효과음(설정 게이트)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                if justEvolvedStage == new { justEvolvedStage = nil }   // 연출 문구 자동 해제
            }
        }
        .onChange(of: session.isOnBreak) { _, onBreak in
            if onBreak { dialogue.fire(.breakStart) }   // 휴식 진입 시 알 한마디
        }
        .onChange(of: session.isRunning) { _, running in
            // 새 시작(activeSecondsLive == 0)에만 시작/스트릭 대사. resume에는 발화 안 함.
            guard running, session.activeSecondsLive == 0 else { return }
            lastTickMinute = 0
            lastMilestone = 0
            let streak = StatsEngine.currentStreak(history.sessions)
            if let t = Self.streakThreshold(for: streak) {
                dialogue.fire(.streak(days: t))       // 스트릭 인정(의심→존중→자부심)
            } else {
                dialogue.fire(.sessionStart)
            }
        }
        .onChange(of: session.activeSecondsLive) { _, secs in
            guard session.isRunning else { return }
            let minutes = secs / 60
            // 알(부화 전): 5·10·15·30·45·60분 서사 마일스톤 우선(의심→존중→자부심).
            if hatchling == nil,
               let m = Self.eggMilestones.last(where: { $0 <= minutes && $0 > lastMilestone }) {
                lastMilestone = m
                lastTickMinute = minutes                 // 같은 분 tick 중복 방지
                dialogue.fire(.focusMilestone(minutes: m))
                return
            }
            // 그 외(빈 구간·부화 후): 3분마다 현재 화자 풀에서 랜덤 한마디.
            if minutes >= lastTickMinute + Self.tickIntervalMinutes {
                lastTickMinute = minutes
                let speaker: DialogueSpeaker = hatchling.map { .creature($0.personality) } ?? .egg
                dialogue.fire(.focusTick, speaker: speaker)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                FocusNotifier.cancel()             // 복귀 시 예약 알림 취소(화면에서 직접 보임)
                session.handleForeground()
                if session.lastAwaySeconds > 0 {   // 집중 중 이탈했다가 복귀
                    dialogue.fire(.appReturn(ReturnBucket.from(awaySeconds: session.lastAwaySeconds)))
                }
            case .background:
                session.handleBackground()
                scheduleFocusNotification()        // 백그라운드에서 다음 전환(부화/휴식 종료) 알림 예약
            default:
                break
            }
        }
        .sensoryFeedback(trigger: hatchling?.id) { _, _ in hapticsEnabled ? .success : nil }        // 부화 순간 햅틱
        .sensoryFeedback(trigger: companionStage) { _, _ in hapticsEnabled ? .success : nil }       // 진화 순간 햅틱
        .sensoryFeedback(trigger: session.isOnBreak) { _, _ in hapticsEnabled ? .impact(weight: .medium) : nil }  // 휴식 진입 햅틱
        .sheet(isPresented: $showSettings) { SettingsView() }
        .onAppear {
            restoreCompanionIfNeeded()   // 콜드런치 후 동료 복원(알이 아니라 키우던 캐릭터로)
            // 세션 종료(완료/중단) 시 이력에 기록(영속 + 통계) + 로그인 시 원격 동기화.
            session.onSessionEnd = { result in
                history.record(result)
                sync?.pushNewSession(result)
            }
            if session.isIdle && hatchling == nil { dialogue.fire(.idle) }
        }
        .task {
            // 충전 중 집중하면 랜덤 주기로 "찌릿" → 부화 +1~2% 보너스(A+). 실기기에서만 충전 감지됨.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 8...15)))
                guard battery.isCharging, session.isRunning else { continue }
                let applied = session.applyChargeBonus(fraction: Double.random(in: 0.01...0.02))
                guard applied > 0 else { continue }
                zapBonusPercent = max(1, Int((applied * 100).rounded()))
                zapFlash = true
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500)); zapFlash = false
                    try? await Task.sleep(for: .milliseconds(1300)); zapBonusPercent = nil
                }
            }
        }
    }

    /// 알 옆 충전 표시. 평소 "충전 중", 찌릿 순간엔 "+N%"로 바뀌며 강조.
    private var chargeBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "bolt.fill").font(.caption2)
            Text(zapBonusPercent.map { "+\($0)%" } ?? "충전 중").font(.caption2.weight(.semibold))
        }
        .foregroundStyle(AppColor.eggAccent)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppColor.cardBackground)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppColor.eggAccent.opacity(0.5), lineWidth: AppSpacing.borderWidth))
        .scaleEffect(zapBonusPercent != nil ? 1.12 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: zapBonusPercent)
    }

    // MARK: - 상단 헤더

    private var header: some View {
        HStack {
            Text("Home")
                .font(.title.weight(.bold))
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
            // 최종 진화 상태에선 집중이 끊김없이 이어지므로, 새 종을 받고 싶은 유저용
            // 작은 "새 알" 토글을 우상단에 배치(UI 방해 최소화). 그 외엔 설정 아이콘.
            if hasCompanion && companionStage >= Creature.maxEvolutionStage {
                newEggButton
            } else {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundStyle(AppColor.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, AppSpacing.elementTight)
    }

    /// 우상단 소형 "새 알 받기" 토글(최종 진화 시 노출).
    private var newEggButton: some View {
        Button { takeNewEgg() } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption2)
                Text("새 알")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(AppColor.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppColor.cardBackground)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppColor.border, lineWidth: AppSpacing.borderWidth))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 모드 선택 + 집중 시간 칩 (idle일 때만)

    private var modeAndDurationSection: some View {
        VStack(spacing: AppSpacing.elementTight) {
            modeToggle
            if session.mode == .free {
                durationChip
            } else {
                Text(pomodoroCaption)
                    .font(AppFont.cardTitle)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
    }

    /// 일반 / 뽀모도로 세그먼트 토글.
    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(TimerMode.allCases, id: \.self) { m in
                let selected = session.mode == m
                Button { session.mode = m } label: {
                    Text(m == .free ? "일반" : "뽀모도로")
                        .font(AppFont.cardTitle.weight(selected ? .bold : .regular))
                        .foregroundStyle(selected ? AppColor.pageBackground : AppColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selected ? AppColor.eggAccent : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(AppColor.cardBackground)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppColor.border, lineWidth: AppSpacing.borderWidth))
        .frame(maxWidth: 220)
        .animation(.easeInOut(duration: 0.2), value: session.mode)
    }

    /// 집중 시간 선택 칩(일반 모드 전용).
    private var durationChip: some View {
        Menu {
            ForEach(durationOptions, id: \.seconds) { opt in
                Button(opt.label) { session.plannedSeconds = opt.seconds }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "leaf").font(.caption)
                Text(selectedDurationLabel).font(AppFont.cardTitle)
                Image(systemName: "chevron.down").font(.caption2)
            }
            .foregroundStyle(AppColor.textBody)
            .padding(.horizontal, AppSpacing.elementTight)
            .padding(.vertical, 7)
            .background(AppColor.cardBackground)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppColor.border, lineWidth: AppSpacing.borderWidth))
        }
    }

    // MARK: - 중앙 무대 (알 ↔ 부화한 캐릭터)

    /// 부화한 동료가 화면에 있는지(부화 후 알 자리를 영구히 차지하고 집중 세션 내내 유지·진화).
    private var hasCompanion: Bool { hatchling != nil }
    /// 방금 부화해 쉬는 중(축하 카드·탄생 문구 노출 — 집중 중에는 숨김).
    private var justHatched: Bool { hatchling != nil && session.isIdle }

    /// 현재 동료의 진화 단계(부화 후 완료한 집중 세션 수로 파생, 0…max).
    private var companionStage: Int {
        guard let h = hatchling else { return 0 }
        return h.evolutionStage(completedSessionsSinceHatch: history.completedSessions(forCompanion: h.id))
    }

    /// 타이머 아래 부제(진화/부화 연출 우선, 그 외 상태 문구). 두 번째 값은 골드 강조 여부.
    private var headerSubtitle: (text: String, highlight: Bool) {
        let name = hatchling?.name ?? ""
        if let s = justEvolvedStage {
            return s >= Creature.maxEvolutionStage
                ? ("\(name)이(가) 최종 진화했어요! ✨", true)
                : ("\(name)이(가) 진화했어요! (\(s)/\(Creature.maxEvolutionStage))", true)
        }
        if justHatched { return ("\(name)이(가) 태어났어요! 🎉", true) }
        return (session.statusText, false)
    }

    @ViewBuilder
    private var centerStage: some View {
        if bornEffect {
            HatchBurstView()          // 부화 버스트 재생 중(알도 몬스터도 아님) → 끝나면 몬스터 노출
        } else if session.isOnBreak {
            BreakView()
                .transition(.scale.combined(with: .opacity))
        } else if let hatchling {
            // 부화 후엔 idle/집중 무관하게 캐릭터가 알 자리를 유지(집중 세션 완료마다 단계 진화).
            HatchedCenter(creature: hatchling, stage: companionStage)
                .id("\(hatchling.id.uuidString)-\(companionStage)")   // 캐릭터·단계 바뀔 때마다 등장(진화) 연출 재생
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        } else {
            EggView(stageIndex: session.eggStageIndex)   // 알은 첫 부화 전까지만(15분마다 crack)
                .transition(.opacity)
        }
    }

    // MARK: - 캐릭터 말풍선 (Feature 4)

    @ViewBuilder
    private var dialogueBubble: some View {
        // 말풍선(아래 꼬리로 알/캐릭터를 가리킴). 집중 방해 없게 은은한 카드톤 + 최대 2줄.
        // 레이아웃 점프 방지를 위해 최소 높이를 확보하고, 대사 유무로 내용만 토글.
        ZStack {
            if let line = dialogue.currentLine {
                Text(line.text)
                    .font(AppFont.cardTitle)
                    .foregroundStyle(AppColor.textBody)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.top, 9)
                    .padding(.bottom, 15)          // 꼬리 공간 확보
                    .background(BubbleShape().fill(AppColor.cardBackground))
                    .overlay(BubbleShape().stroke(AppColor.border, lineWidth: AppSpacing.borderWidth))
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    .id(line.id)
            }
        }
        .frame(minHeight: 56)
        .animation(.easeInOut(duration: 0.25), value: dialogue.currentLine?.id)
    }

    // MARK: - 타이머 표시

    private var timerHeader: some View {
        VStack(spacing: AppSpacing.elementTight) {
            Text(session.timerDisplay)
                .font(AppFont.timer)
                .foregroundStyle(AppColor.textPrimary)
                .monospacedDigit()
                .opacity(justHatched || justEvolvedStage != nil ? 0.3 : 1)
            Text(headerSubtitle.text)
                .font(AppFont.body)
                .foregroundStyle(headerSubtitle.highlight ? AppColor.eggAccent : AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 부화 진행도 (6단계 스텝퍼)

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.elementTight) {
            HStack {
                Text("부화 진행도")
                    .font(AppFont.cardTitle)
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text(session.stageCaption)
                    .font(AppFont.cardTitle)
                    .foregroundStyle(AppColor.textSecondary)
            }
            StageStepper(current: session.stageIndex, total: EggState.visualStages)
        }
    }

    // MARK: - 컨트롤 (상태별)

    @ViewBuilder
    private var controlButtons: some View {
        VStack(spacing: AppSpacing.elementTight) {
            if session.isOnBreak {
                PrimaryButton("건너뛰기") { session.skipBreak() }
                DangerButton("중단") { session.stop() }
            } else {
                switch session.phase {
                case nil:
                    if hatchling != nil {
                        // 부화 후: 동료를 유지한 채 집중을 이어가거나(진화), 새 알을 받아 다른 종 수집.
                        PrimaryButton("이어서 집중") { beginFocus() }       // 캐릭터 유지(알 X)
                        SecondaryButton("새 알 받기") { takeNewEgg() }  // 알만 리셋(컬렉션은 유지)
                    } else {
                        PrimaryButton("시작") { beginFocus() }
                    }
                case .running:
                    PrimaryButton("일시정지") { session.pause() }
                    DangerButton("중단") { session.stop() }
                case .paused:
                    PrimaryButton("이어서 집중") { session.resume() }
                    DangerButton("중단") { session.stop() }
                case .completed:
                    PrimaryButton("부화 확인") { triggerHatch() }
                }
            }
        }
        .padding(.bottom, AppSpacing.element)
    }
}

/// 부화 직후 알 자리를 대체해 표시되는 생명체. 등장 시 글로우 버스트 + 스파클로 "부화 순간"을 연출한다.
private struct HatchedCenter: View {
    let creature: Creature
    /// 진화 단계(0…max). 단계가 높을수록 글로우가 강해져 "성장한 느낌"을 준다.
    var stage: Int = 0
    var height: CGFloat = 240
    @State private var appeared = false
    @State private var burst = false

    /// 스파클이 퍼지는 방향(8방향).
    private let sparkAngles: [Double] = stride(from: 0, to: 360, by: 45).map { $0 }

    /// 단계에 따른 글로우 가중(0단계 1.0 → 최종 단계로 갈수록 진해짐).
    private var stageGlow: Double { 1.0 + Double(stage) * 0.25 }

    var body: some View {
        ZStack {
            // 등급색 글로우(등장 시 한 번 확 퍼짐, 진화 단계가 높을수록 강해짐).
            Circle()
                .fill(
                    RadialGradient(
                        colors: [creature.rarity.color.opacity(min((burst ? 0.45 : 0.28) * stageGlow, 0.7)), .clear],
                        center: .center, startRadius: 4, endRadius: height * (burst ? 0.7 : 0.55)
                    )
                )
                .frame(width: height * 1.3, height: height * 1.3)
                .animation(.easeOut(duration: 0.6), value: burst)

            // 스파클 버스트.
            ForEach(Array(sparkAngles.enumerated()), id: \.offset) { _, angle in
                Image(systemName: "sparkle")
                    .font(.system(size: 12))
                    .foregroundStyle(creature.rarity.color)
                    .offset(x: cos(angle * .pi / 180) * (burst ? height * 0.55 : 0),
                            y: sin(angle * .pi / 180) * (burst ? height * 0.55 : 0))
                    .opacity(burst ? 0 : 1)
                    .scaleEffect(burst ? 1.4 : 0.2)
                    .animation(.easeOut(duration: 0.7), value: burst)
            }

            Image(creature.displayImageName(stage: stage))
                .interpolation(.none)            // 픽셀아트 선명하게
                .resizable()
                .scaledToFit()
                .frame(height: height * 0.82)
                .scaleEffect(appeared ? 1 : 0.4)
                .rotationEffect(.degrees(appeared ? 0 : -8))
                .animation(.spring(response: 0.55, dampingFraction: 0.55), value: appeared)
        }
        .frame(height: height)
        .onAppear {
            appeared = true
            burst = true
        }
        .accessibilityLabel(Text("\(creature.rarity.label) \(creature.name)"))
    }
}

/// 부화한 생명체의 이름·등급 카드(중앙 무대 아래 인라인). 모달 대신 화면에 머문다.
private struct HatchRevealCard: View {
    let creature: Creature

    var body: some View {
        VStack(spacing: 4) {
            Text(creature.name)
                .font(AppFont.screenTitle)
                .foregroundStyle(AppColor.textPrimary)
            Text(creature.rarity.label)
                .font(AppFont.cardTitle)
                .foregroundStyle(creature.rarity.color)
            Text("이어서 집중하면 진화해요 ✨")
                .font(AppFont.body)
                .foregroundStyle(AppColor.textSecondary)
            Text("컬렉션에 추가됐어요")
                .font(AppFont.body)
                .foregroundStyle(AppColor.textSecondary)
                .padding(.top, 2)
        }
        .padding(.horizontal, AppSpacing.element)
        .padding(.vertical, AppSpacing.elementTight)
        .frame(maxWidth: .infinity)
        .background(AppColor.cardBackground)
        .overlay(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
            .stroke(creature.rarity == .legendary ? AppColor.eggAccent : AppColor.border,
                    lineWidth: creature.rarity == .legendary ? 1.5 : AppSpacing.borderWidth))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }
}

/// 포모도로 휴식 중앙 화면. 따뜻한 톤의 휴식 안내.
private struct BreakView: View {
    var height: CGFloat = 240
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [AppColor.success.opacity(0.22), .clear],
                                     center: .center, startRadius: 4, endRadius: height * 0.55))
                .frame(width: height * 1.25, height: height * 1.25)

            VStack(spacing: AppSpacing.elementTight) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(AppColor.success)
                    .scaleEffect(pulse ? 1.06 : 0.94)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)
                Text("잠깐 쉬어가요")
                    .font(AppFont.cardTitle)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .frame(height: height)
        .onAppear { pulse = true }
        .accessibilityLabel(Text("휴식 중"))
    }
}

/// 6단계 부화 진행 스텝퍼. 채워진 단계는 골드 점, 사이는 연결선.
private struct StageStepper: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i <= current ? AppColor.eggAccent : AppColor.border)
                    .frame(width: i == current ? 12 : 9, height: i == current ? 12 : 9)
                if i < total - 1 {
                    Rectangle()
                        .fill(i < current ? AppColor.eggAccent : AppColor.border)
                        .frame(height: 2)
                }
            }
        }
    }
}

/// 부화 순간 알이 쩍 갈라져 "빡!" 터지는 프레임 시퀀스(4-2egg → 4-7egg). 한 번 재생 후 몬스터 노출.
/// 6프레임 모두 1254² 동일 캔버스 → 정렬 안정. 높이 340pt면 알 코어(캔버스의 ~68%)가 정적 알(240)과 일치.
/// 프레임 에셋이 없으면 단일 borneffect 플래시로 폴백.
private struct HatchBurstView: View {
    // 부화 버스트: 4-3egg→4-7egg 순서대로(알 쩍→황금 폭발). 모두 665×864 동일 박스라 정렬 일관.
    // (4-5~4-7은 흰 배경이라 흰색→투명 키잉 처리 — 흰 플래시 자리는 황금 광선이 채움.)
    private let frames = ["4-3egg", "4-4egg", "4-5egg", "4-6egg", "4-7egg"]
    private let frameDuration: Double = 0.12
    /// 알과 동일 크기(4egg와 일치). centerStage 알 높이와 같게.
    var height: CGFloat = 240
    @State private var idx = 0

    private var hasFrames: Bool { UIImage(named: frames[0]) != nil }

    var body: some View {
        Group {
            if hasFrames {
                Image(frames[min(idx, frames.count - 1)])
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(height: height)
            } else if UIImage(named: "borneffect") != nil {
                Image("borneffect")
                    .interpolation(.none).resizable().scaledToFit().frame(height: height)
            }
        }
        .onAppear {
            guard hasFrames else { return }
            Task { @MainActor in
                for i in frames.indices {
                    idx = i
                    try? await Task.sleep(for: .seconds(frameDuration))
                }
            }
        }
    }
}

/// 말풍선 모양 — 둥근 사각형 본체 + 하단 중앙 아래로 향하는 작은 꼬리(아래의 캐릭터를 가리킴).
private struct BubbleShape: Shape {
    var radius: CGFloat = 14
    var tailWidth: CGFloat = 14
    var tailHeight: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let body = CGRect(x: rect.minX, y: rect.minY,
                          width: rect.width, height: max(0, rect.height - tailHeight))
        p.addRoundedRect(in: body, cornerSize: CGSize(width: radius, height: radius))
        let cx = rect.midX
        p.move(to: CGPoint(x: cx - tailWidth / 2, y: body.maxY - 0.5))
        p.addLine(to: CGPoint(x: cx, y: rect.maxY))
        p.addLine(to: CGPoint(x: cx + tailWidth / 2, y: body.maxY - 0.5))
        p.closeSubpath()
        return p
    }
}

/// 충전 "찌릿" 스파크. 알 주위로 번개 심볼이 확 퍼지며 한 번 재생.
private struct ZapBurstView: View {
    @State private var burst = false
    private let angles = stride(from: 0, to: 360, by: 60).map { Double($0) }

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [AppColor.eggAccent.opacity(burst ? 0 : 0.35), .clear],
                                     center: .center, startRadius: 4, endRadius: 120))
                .frame(width: 200, height: 200)
            ForEach(Array(angles.enumerated()), id: \.offset) { _, a in
                Image(systemName: "bolt.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(AppColor.eggAccent)
                    .offset(x: cos(a * .pi / 180) * (burst ? 105 : 15),
                            y: sin(a * .pi / 180) * (burst ? 105 : 15))
                    .opacity(burst ? 0 : 1)
                    .scaleEffect(burst ? 1.3 : 0.4)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.45)) { burst = true } }
    }
}

#Preview("초기 알") {
    HomeView(session: .preview(progress: 0))
        .preferredColorScheme(.dark)
}

#Preview("부화 임박") {
    HomeView(session: .preview(progress: 0.95))
        .preferredColorScheme(.dark)
}
