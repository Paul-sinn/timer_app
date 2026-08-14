//
//  HomeView.swift
//  Eggtimer
//
//  홈 탭. 다크+골드 톤. 헤더 / 집중 시간 선택 칩 / 대형 타이머 / 중앙 픽셀 알 /
//  6단계 Hatch progress / Start·Pause·이어서·Stop 컨트롤.
//  실제 동작: SessionManager가 타임스탬프 기반으로 카운트다운하고, 목표 도달 시
//  확률표대로 자동 부화 → 결과 시트 → 컬렉션 반영. (Feature 1·2·7)
//

import SwiftUI
import AudioToolbox
import AVFoundation

struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var session: SessionManager
    private let store: CollectionStore
    private let history: FocusHistoryStore
    /// 로그인 시 부화·세션종료를 원격에 동기화(비로그인 시 무시).
    private let sync: SyncCoordinator?
    /// 부화 후 알 자리를 대체해 표시 중인 생명체("Get new egg" 전까지 유지).
    @State private var hatchling: Creature?
    /// 캐릭터 말풍선 대사 선택기(Feature 4).
    @State private var dialogue = DialogueManager()
    /// 이번 세션에서 마지막으로 focus tick을 발화한 분. 3분 간격 중복 방지.
    @State private var lastTickMinute = 0
    /// 이번 세션에서 마지막으로 발화한 알 마일스톤(분). 알의 의심→존중→자부심 서사.
    @State private var lastMilestone = 0
    /// 방금 진화한 단계(연출/문구 노출용, 잠시 후 nil). nil = 진화 연출 없음.
    @State private var justEvolvedStage: Int?
    /// 현재 동료의 id(영속). 콜드런치(앱 재Start) 후 컬렉션에서 같은 개체를 복원해 홈에 다시 표시.
    /// 빈 문자열 = 동료 없음(첫 부화 전 또는 'Get new egg' 직후).
    @AppStorage("companionCreatureID") private var companionID = ""
    /// 부화 순간 borneffect.png 버스트 연출 활성(잠시 후 false).
    @State private var bornEffect = false
    /// 충전 감지(A+ 기믹). Charging 집중하면 알이 찌릿하며 부화 살짝 가속.
    @State private var battery = BatteryMonitor()
    /// 찌릿 스파크 연출 순간 토글.
    @State private var zapFlash = false
    /// 직전 찌릿으로 받은 보너스 %(표시용, 잠시 후 nil).
    @State private var zapBonusPercent: Int?
    /// Settings 시트 표시(우상단 기어).
    @State private var showSettings = false
    /// "New egg" OK 다이얼로그 표시(실수 탭 방지).
    @State private var showNewEggConfirm = false
    /// 집중 시간 보상 안내 시트 표시("?" 버튼·첫 실행 1회).
    @State private var showLuckCard = false
    @State private var showPomodoroInfo = false
    /// 보상 안내를 이미 봤는지(첫 실행에만 자동 노출). 이후엔 "?" 버튼으로만.
    @AppStorage("home.seenFocusLuckTip") private var seenFocusLuckTip = false
    /// 효과음(부화·진화 시스템 사운드) 사용 여부. Settings 시트와 같은 키를 공유.
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
        return [(String(localized: "10 sec (test)"), 10), (String(localized: "25 min"), 25 * 60), (String(localized: "50 min"), 50 * 60), (String(localized: "75 min"), 75 * 60)]
        #else
        return [(String(localized: "25 min"), 25 * 60), (String(localized: "50 min"), 50 * 60), (String(localized: "75 min"), 75 * 60)]
        #endif
    }

    private var selectedDurationLabel: String {
        durationOptions.first { $0.seconds == session.plannedSeconds }?.label ?? String(localized: "Focus mode")
    }

    /// 포모도로 안내 캡션(집중/휴식/보상 규칙).
    private var pomodoroCaption: String {
        let f = PomodoroConfig.focusBlock, b = PomodoroConfig.breakLength
        let lb = PomodoroConfig.longBreakLength, every = PomodoroConfig.longBreakEvery
        func fmt(_ s: Int) -> String { s >= 60 ? String(localized: "\(s / 60) min") : String(localized: "\(s) sec") }
        return String(localized: "\(fmt(f)) focus · hatch/evolve after each \(fmt(b)) break · long \(fmt(lb)) break every \(every) blocks")
    }

    /// 현재 휴식에 보여줄 장면. 롱브레이크=낮잠, 짧은 휴식=커피/스트레칭 번갈아.
    private var breakScene: BreakScene {
        if session.isLongBreak { return .nap }
        return session.pomodoroBlock % 2 == 0 ? .stretch : .coffee
    }

    /// 부화 처리(자동·수동 공통 단일 진입점). 캐릭터를 알 자리에 유지하고 성격대로 인사시킨다.
    private func triggerHatch() {
        guard hatchling == nil, !bornEffect else { return }   // 중복 방지(버스트 중 재진입 차단)
        let draws = FocusReward.draws(focusSeconds: session.activeSecondsLive)  // 집중 길이 보상(best-of-N)
        let born = store.hatch(draws: draws)          // 확률 부화 + 컬렉션 반영(영속)
        sync?.pushNewCreature(born)                   // 로그인 시 원격 동기화
        if soundEnabled { AudioServicesPlaySystemSound(1025) }   // 부화 효과음(Settings 게이트)
        bornEffect = true                             // 알 자리에 버스트 재생(몬스터 아직 X)
        Task { @MainActor in
            // 버스트 전체 재생(영상 2.8초 / PNG 폴백 1.8초) 후 캐릭터 노출.
            try? await Task.sleep(for: .seconds(HatchBurstView.totalDuration + 0.05))
            hatchling = born                          // 버스트 끝 → 태어난 캐릭터 노출
            companionID = born.id.uuidString          // 콜드런치 복원용 영속
            session.companionID = born.id             // 이후 세션을 이 캐릭터에 귀속(진화 단계)
            dialogue.fire(.greeting, speaker: .creature(born.personality))  // 성격 대사
            advanceAfterReward(startFresh: false)     // 포모도로=Next 블록 / free=idle(인라인 리빌)
            bornEffect = false
        }
    }

    /// 보상 소비 후 Next 상태로. 포모도로는 끊김없이 Next 집중 블록으로 이어가고,
    /// free는 idle로 돌아간다(startFresh=최종진화 후 새 세션 자동 Start으로 흐름 유지).
    private func advanceAfterReward(startFresh: Bool) {
        if session.activeMode == .pomodoro {
            session.startNextBlock()
        } else {
            session.acknowledgeCompletion()
            if startFresh { session.start() }
        }
    }

    /// 집중 Start(Start/Keep focusing) — 알림 권한을 1회 요청하고 세션을 Start한다.
    private func beginFocus() {
        justEvolvedStage = nil
        if notificationsEnabled { Task { await FocusNotifier.requestAuthorization() } }
        session.start()
    }

    /// 현재 동료를 보내고 New egg을 받는다(진행 중이면 세션 Stop·기록 후 알로 리셋).
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
            companionID = ""                          // 개체가 사라졌으면(Delete 등) 플래그 정리
        }
    }

    /// 백그라운드 진입 시 알림 예약.
    /// - On a break: 벽시계로 계속 흐르므로 "휴식 끝" 단건 예약(유효).
    /// - 집중 중: 이탈=자동 Pause라 백그라운드에서 진행 안 됨 → 진행 알림 대신
    ///   "돌아와" 이탈 넛지를 드물게(2·15·40분) 예약. 복귀 시 cancel()로 전부 Cancel.
    private func scheduleFocusNotification() {
        guard notificationsEnabled else { return }   // 알림 끄면 예약 안 함
        if session.isOnBreak {
            FocusNotifier.schedule(title: String(localized: "Break's over! ☕️"),
                                   body: String(localized: "Time to focus again."),
                                   after: session.breakRemainingSeconds)
        } else if session.isRunning {
            FocusNotifier.scheduleDistractionNudges([
                ("Hatcho", String(localized: "🐣 Your focus paused — come back and continue"), 120),
                ("Hatcho", String(localized: "⏰ Still away? Come back for a bit?"), 900),
                ("Hatcho", String(localized: "😴 Tired of waiting… come back soon"), 2400),
            ])
        }
    }

    var body: some View {
        ZStack {
            ThemedBackground()

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
                triggerHatch()                    // 첫 부화(첫 블록): 알 → 캐릭터
            } else if companionStage >= Creature.maxEvolutionStage {
                // 최종 진화: 더 진화 없음 → 포모도로는 Next 블록, free는 Next 세션으로 끊김없이.
                advanceAfterReward(startFresh: true)
            } else {
                advanceAfterReward(startFresh: false)   // 진화 연출 후 이어감(포모도로)/idle(free)
            }
        }
        .onChange(of: companionStage) { old, new in
            // 동료가 한 단계 진화(Keep focusing 1세션 Done). 등장 연출은 centerStage의 .id 변화가 재생.
            guard new > old, hatchling != nil else { return }
            justEvolvedStage = new
            if soundEnabled { AudioServicesPlaySystemSound(1025) }   // 진화 효과음(Settings 게이트)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                if justEvolvedStage == new { justEvolvedStage = nil }   // 연출 문구 자동 해제
            }
        }
        .onChange(of: session.isOnBreak) { _, onBreak in
            if onBreak { dialogue.fire(.breakStart) }   // 휴식 진입 시 알 한마디
        }
        .onChange(of: session.isRunning) { _, running in
            // 새 Start(activeSecondsLive == 0)에만 Start/스트릭 대사. resume에는 발화 안 함.
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
                FocusNotifier.cancel()             // 복귀 시 예약 알림 Cancel(화면에서 직접 보임)
                session.handleForeground()
                if session.lastAwaySeconds > 0 {   // 집중 중 이탈했다가 복귀
                    dialogue.fire(.appReturn(ReturnBucket.from(awaySeconds: session.lastAwaySeconds)))
                }
            case .background:
                session.handleBackground()
                scheduleFocusNotification()        // 백그라운드에서 Next 전환(부화/휴식 종료) 알림 예약
            default:
                break
            }
        }
        .sensoryFeedback(trigger: hatchling?.id) { _, _ in hapticsEnabled ? .success : nil }        // 부화 순간 햅틱
        .sensoryFeedback(trigger: companionStage) { _, _ in hapticsEnabled ? .success : nil }       // 진화 순간 햅틱
        .sensoryFeedback(trigger: session.isOnBreak) { _, _ in hapticsEnabled ? .impact(weight: .medium) : nil }  // 휴식 진입 햅틱
        .sheet(isPresented: $showSettings) { SettingsView() }
        .overlay { if showLuckCard { luckCardModal } }
        .overlay { if showPomodoroInfo { pomodoroInfoModal } }
        .alert("Get a new egg?", isPresented: $showNewEggConfirm) {
            Button("Get new egg", role: .destructive) { takeNewEgg() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your current friend stays in your collection, but Home restarts from a new egg.")
        }
        .onAppear {
            restoreCompanionIfNeeded()   // 콜드런치 후 동료 복원(알이 아니라 키우던 캐릭터로)
            // 세션 종료(Done/Stop) 시 이력에 기록(영속 + 통계) + 로그인 시 원격 동기화.
            session.onSessionEnd = { result in
                history.record(result)
                sync?.pushNewSession(result)
            }
            if session.isIdle && hatchling == nil { dialogue.fire(.idle) }
            // 첫 실행 1회만 보상 안내 자동 노출(이후엔 "?" 버튼으로).
            if !seenFocusLuckTip {
                seenFocusLuckTip = true
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showLuckCard = true }
            }
            // 부화 버스트 사전 로딩 → 첫 재생 시 디코딩 버벅임 방지.
            // 영상 경로면 플레이어를 미리 세워두고, PNG 폴백 경로면 이미지를 미리 디코딩한다.
            if HatchBurstAsset.isAvailable {
                HatchBurstPlayback.shared.prepare()
            } else {
                for name in HatchBurstView.assetNames { _ = UIImage(named: name) }
            }
        }
        .task {
            // Charging 집중하면 랜덤 주기로 "찌릿" → 부화 +1~2% 보너스(A+). 실기기에서만 충전 감지됨.
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

    /// 알 옆 충전 표시. 평소 "Charging", 찌릿 순간엔 "+N%"로 바뀌며 강조.
    private var chargeBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "bolt.fill").font(.caption2)
            Text(zapBonusPercent.map { String(localized: "+\($0)%") } ?? String(localized: "Charging")).font(.caption2.weight(.semibold))
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
            // 작은 "New egg" 토글을 우상단에 배치(UI 방해 최소화). 그 외엔 Settings 아이콘.
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

    /// 우상단 소형 "Get new egg" 토글(최종 진화 시 노출).
    private var newEggButton: some View {
        Button { showNewEggConfirm = true } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption2)
                Text("New egg")
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
                HStack(spacing: 8) {
                    durationChip
                    luckHelpButton
                }
            } else {
                // 규칙 문장이 길어 잘리므로 "?" 버튼으로 접고, 탭하면 전체를 카드로 보여준다.
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showPomodoroInfo = true }
                } label: {
                    HStack(spacing: 6) {
                        Text("Pomodoro rules")
                            .font(AppFont.cardTitle)
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 18))
                    }
                    .foregroundStyle(AppColor.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("How Pomodoro works"))
            }
        }
    }

    /// 일반 / Pomodoro 세그먼트 토글.
    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(TimerMode.allCases, id: \.self) { m in
                let selected = session.mode == m
                Button { session.mode = m } label: {
                    Text(m == .free ? String(localized: "mode.normal", defaultValue: "Timer") : String(localized: "Pomodoro"))
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

    /// 현재 동료의 진화 단계(부화 후 Done한 집중 세션 수로 파생, 0…max).
    private var companionStage: Int {
        guard let h = hatchling else { return 0 }
        return h.evolutionStage(completedSessionsSinceHatch: history.completedSessions(forCompanion: h.id))
    }

    /// 타이머 아래 부제(진화/부화 연출 우선, 그 외 상태 문구). 두 번째 값은 골드 강조 여부.
    private var headerSubtitle: (text: String, highlight: Bool) {
        let name = hatchling?.name ?? ""
        if let s = justEvolvedStage {
            return s >= Creature.maxEvolutionStage
                ? (String(localized: "\(name) reached its final form! ✨"), true)
                : (String(localized: "\(name) evolved! (\(s)/\(Creature.maxEvolutionStage))"), true)
        }
        if justHatched { return (String(localized: "\(name) hatched! 🎉"), true) }
        return (session.statusText, false)
    }

    @ViewBuilder
    private var centerStage: some View {
        if bornEffect {
            HatchBurstView()          // 부화 버스트 재생 중(알도 몬스터도 아님) → 끝나면 몬스터 노출
        } else if session.isOnBreak {
            BreakView(scene: breakScene)
                .transition(.scale.combined(with: .opacity))
        } else if let hatchling {
            // 부화 후엔 idle/집중 무관하게 캐릭터가 알 자리를 유지(집중 세션 Done마다 단계 진화).
            HatchedCenter(creature: hatchling, stage: companionStage)
                .id("\(hatchling.id.uuidString)-\(companionStage)")   // 캐릭터·단계 바뀔 때마다 등장(진화) 연출 재생
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        } else {
            EggView(stageIndex: session.stageIndex)   // 알은 첫 부화 전까지만(진행도 → crack 6단계)
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

    // MARK: - Hatch progress (6단계 스텝퍼)

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.elementTight) {
            HStack {
                Text("Hatch progress")
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

    /// 집중 시간 칩 옆 도움말 "?" 버튼 — 중앙 카드형 보상 안내를 연다.
    private var luckHelpButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showLuckCard = true }
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 18))
                .foregroundStyle(AppColor.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("About focus rewards"))
    }

    private func dismissLuckCard() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { showLuckCard = false }
    }

    private func dismissPomodoroInfo() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { showPomodoroInfo = false }
    }

    /// 포모도로 규칙 안내 카드("?" 버튼). 잘리던 전체 캡션을 여기서 다 보여준다. 스크림 탭·CTA로 닫힘.
    private var pomodoroInfoModal: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { dismissPomodoroInfo() }

            VStack(spacing: AppSpacing.element) {
                Image(systemName: "timer")
                    .font(.system(size: 40))
                    .foregroundStyle(AppColor.eggAccent)
                Text("How Pomodoro works")
                    .font(AppFont.screenTitle)
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(pomodoroCaption)
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.textBody)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                PrimaryButton("Got it") { dismissPomodoroInfo() }
                    .padding(.top, AppSpacing.elementTight)
            }
            .padding(AppSpacing.section)
            .frame(maxWidth: 320)
            .background(AppColor.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
            .overlay(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .stroke(AppColor.border, lineWidth: AppSpacing.borderWidth))
            .padding(AppSpacing.section)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }

    /// 중앙 카드형 보상 안내(첫 실행 1회 + "?" 버튼). 스크림 탭 또는 CTA로 닫힘. 결과 중심 문구.
    private var luckCardModal: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { dismissLuckCard() }

            VStack(spacing: AppSpacing.element) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [AppColor.eggAccent.opacity(0.28), .clear],
                                             center: .center, startRadius: 2, endRadius: 72))
                        .frame(width: 132, height: 132)
                    Image("ChickenSmartStage1Idle")   // 너드 닭(Bookworm Hen) 히어로
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                }
                Text("Focus longer, luckier hatches")
                    .font(AppFont.screenTitle)
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("The longer you focus in one session, the better your odds of hatching a rarer friend.")
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.textBody)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: AppSpacing.elementTight) {
                    luckOddsPill("25 min", "Base", filled: 1)
                    luckOddsPill("50 min", "Higher", filled: 2)
                    luckOddsPill("75 min+", "Best", filled: 3)
                }
                .padding(.top, 2)
                PrimaryButton("Let's focus") { dismissLuckCard() }
                    .padding(.top, AppSpacing.elementTight)
            }
            .padding(AppSpacing.section)
            .frame(maxWidth: 320)
            .background(AppColor.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
            .overlay(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .stroke(AppColor.border, lineWidth: AppSpacing.borderWidth))
            .padding(AppSpacing.section)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }

    /// 확률 상승을 시각화하는 작은 pill(시간 + 채워진 점 + 라벨).
    private func luckOddsPill(_ time: String, _ label: String, filled: Int) -> some View {
        VStack(spacing: 5) {
            Text(time)
                .font(AppFont.cardTitle)
                .foregroundStyle(AppColor.textPrimary)
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i < filled ? AppColor.eggAccent : AppColor.border)
                        .frame(width: 5, height: 5)
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.elementTight)
        .background(AppColor.pageBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - 컨트롤 (상태별)

    @ViewBuilder
    private var controlButtons: some View {
        VStack(spacing: AppSpacing.elementTight) {
            if session.isOnBreak {
                PrimaryButton("Skip") { session.skipBreak() }
                DangerButton("Stop") { session.stop() }
            } else {
                switch session.phase {
                case nil:
                    if hatchling != nil {
                        // 부화 후: 동료를 유지한 채 집중을 이어가거나(진화), New egg을 받아 다른 종 수집.
                        PrimaryButton("Keep focusing") { beginFocus() }       // 캐릭터 유지(알 X)
                        SecondaryButton("Get new egg") { takeNewEgg() }  // 알만 리셋(컬렉션은 유지)
                    } else {
                        PrimaryButton("Start") { beginFocus() }
                    }
                case .running:
                    PrimaryButton("Pause") { session.pause() }
                    DangerButton("Stop") { session.stop() }
                case .paused:
                    PrimaryButton("Keep focusing") { session.resume() }
                    DangerButton("Stop") { session.stop() }
                case .completed:
                    PrimaryButton("Reveal") { triggerHatch() }
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

            // 진화 단계별 아트 + idle/action 2프레임 모션(에셋이 없는 종은 기존 이미지로 폴백).
            AnimatedCreatureView(base: creature.displayImageName(stage: stage), stage: stage)
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
            Text("Keep focusing to evolve ✨")
                .font(AppFont.body)
                .foregroundStyle(AppColor.textSecondary)
            Text("Added to your collection")
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

/// 포모도로 On a break앙 화면. 따뜻한 톤의 휴식 안내.
private struct BreakView: View {
    let scene: BreakScene
    var height: CGFloat = 240

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [AppColor.eggAccent.opacity(0.16), .clear],
                                     center: .center, startRadius: 4, endRadius: height * 0.6))
                .frame(width: height * 1.3, height: height * 1.3)

            VStack(spacing: AppSpacing.elementTight) {
                BreakSceneView(scene: scene)
                    .frame(height: height * 0.62)   // 비율 유지(scaledToFit), 아래 문구 자리 확보
                Text(caption)
                    .font(AppFont.cardTitle)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .frame(height: height)
        .accessibilityLabel(Text("On a break"))
    }

    private var caption: String {
        switch scene {
        case .coffee:  return String(localized: "Coffee break ☕")
        case .nap:     return String(localized: "Rest up 💤")
        case .stretch: return String(localized: "Stretch it out 🌱")
        }
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
