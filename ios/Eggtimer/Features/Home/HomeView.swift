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
    /// 이번 세션에서 마지막으로 발화한 집중 마일스톤(분). 중복 발화 방지.
    @State private var lastMilestone = 0

    /// 집중 경과 대사 마일스톤(분). 알의 톤이 의심→존중→자부심으로 진화하는 지점.
    private static let focusMilestones = [5, 10, 15, 30, 45, 60]
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
        guard hatchling == nil else { return }       // 중복 방지
        let born = store.hatch()                      // 확률 부화 + 컬렉션 반영(영속)
        sync?.pushNewCreature(born)                   // 로그인 시 원격 동기화
        hatchling = born                              // 알 자리를 태어난 캐릭터로 대체(유지)
        dialogue.fire(.greeting, speaker: .creature(born.personality))  // 성격 대사
        session.acknowledgeCompletion()               // 완료 소비 → idle, 인라인 리빌 노출
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
                    .padding(.vertical, AppSpacing.elementTight)
                if showingHatchling, let hatchling {
                    HatchRevealCard(creature: hatchling)
                        .padding(.top, AppSpacing.elementTight)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                Spacer(minLength: 0)
                if !showingHatchling && !session.isOnBreak { progressSection }
                controlButtons
                    .padding(.top, AppSpacing.element)
            }
            .padding(.horizontal, AppSpacing.section)
            .animation(.easeInOut(duration: 0.3), value: showingHatchling)
        }
        .onChange(of: session.isCompleted) { _, completed in
            if completed { triggerHatch() }   // 목표 도달 → 즉시 부화(자동 경로)
        }
        .onChange(of: session.isOnBreak) { _, onBreak in
            if onBreak { dialogue.fire(.breakStart) }   // 휴식 진입 시 알 한마디
        }
        .onChange(of: session.isRunning) { _, running in
            // 새 시작(activeSecondsLive == 0)에만 시작/스트릭 대사. resume에는 발화 안 함.
            guard running, session.activeSecondsLive == 0 else { return }
            lastMilestone = 0
            let streak = StatsEngine.currentStreak(history.sessions)
            if let t = Self.streakThreshold(for: streak) {
                dialogue.fire(.streak(days: t))       // 스트릭 인정(의심→존중→자부심)
            } else {
                dialogue.fire(.sessionStart)
            }
        }
        .onChange(of: session.activeSecondsLive) { _, secs in
            // 집중 경과 마일스톤(5·10·15·30·45·60분) 도달 시 1회 발화.
            guard session.isRunning else { return }
            let minutes = secs / 60
            if let m = Self.focusMilestones.last(where: { $0 <= minutes && $0 > lastMilestone }) {
                lastMilestone = m
                dialogue.fire(.focusMilestone(minutes: m))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                session.handleForeground()
                if session.lastAwaySeconds > 0 {   // 집중 중 이탈했다가 복귀
                    dialogue.fire(.appReturn(ReturnBucket.from(awaySeconds: session.lastAwaySeconds)))
                }
            case .background:
                session.handleBackground()
            default:
                break
            }
        }
        .onAppear {
            // 세션 종료(완료/중단) 시 이력에 기록(영속 + 통계) + 로그인 시 원격 동기화.
            session.onSessionEnd = { result in
                history.record(result)
                sync?.pushNewSession(result)
            }
            if session.isIdle { dialogue.fire(.idle) }
        }
    }

    // MARK: - 상단 헤더

    private var header: some View {
        HStack {
            Text("Home")
                .font(.title.weight(.bold))
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
            Image(systemName: "gearshape")
                .font(.title3)
                .foregroundStyle(AppColor.textSecondary)
        }
        .padding(.top, AppSpacing.elementTight)
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

    /// idle 상태에서 부화한 캐릭터를 알 자리에 표시 중인지.
    private var showingHatchling: Bool { session.isIdle && hatchling != nil }

    @ViewBuilder
    private var centerStage: some View {
        if session.isOnBreak {
            BreakView()
                .transition(.scale.combined(with: .opacity))
        } else if showingHatchling, let hatchling {
            HatchedCenter(creature: hatchling)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        } else {
            EggView(stageIndex: session.stageIndex)
                .transition(.opacity)
        }
    }

    // MARK: - 캐릭터 말풍선 (Feature 4)

    @ViewBuilder
    private var dialogueBubble: some View {
        // 레이아웃 점프 방지를 위해 높이를 확보하고, 대사 유무로 내용만 토글.
        ZStack {
            if let line = dialogue.currentLine {
                Text(line.text)
                    .font(AppFont.cardTitle)
                    .foregroundStyle(AppColor.textBody)
                    .padding(.horizontal, AppSpacing.element)
                    .padding(.vertical, 8)
                    .background(AppColor.cardBackground)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppColor.border, lineWidth: AppSpacing.borderWidth))
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .id(line.id)
            }
        }
        .frame(height: 36)
        .animation(.easeInOut(duration: 0.25), value: dialogue.currentLine?.id)
    }

    // MARK: - 타이머 표시

    private var timerHeader: some View {
        VStack(spacing: AppSpacing.elementTight) {
            Text(session.timerDisplay)
                .font(AppFont.timer)
                .foregroundStyle(AppColor.textPrimary)
                .monospacedDigit()
                .opacity(showingHatchling ? 0.3 : 1)
            Text(showingHatchling ? "\(hatchling?.name ?? "")이(가) 태어났어요! 🎉" : session.statusText)
                .font(AppFont.body)
                .foregroundStyle(showingHatchling ? AppColor.eggAccent : AppColor.textSecondary)
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
                        // 부화 후: 바로 다음 집중을 이어가거나, 알만 새로 받기.
                        PrimaryButton("이어서 집중") { hatchling = nil; session.start() }
                        SecondaryButton("새 알 받기") { hatchling = nil }
                    } else {
                        PrimaryButton("시작") { session.start() }
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
    var height: CGFloat = 240
    @State private var appeared = false
    @State private var burst = false

    /// 스파클이 퍼지는 방향(8방향).
    private let sparkAngles: [Double] = stride(from: 0, to: 360, by: 45).map { $0 }

    var body: some View {
        ZStack {
            // 등급색 글로우(등장 시 한 번 확 퍼짐).
            Circle()
                .fill(
                    RadialGradient(
                        colors: [creature.rarity.color.opacity(burst ? 0.45 : 0.28), .clear],
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

            Image(creature.displayImageName)
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
            if creature.canEvolve {
                Text("20분 더 집중하면 진화해요 ✨")
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.textSecondary)
            }
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

#Preview("초기 알") {
    HomeView(session: .preview(progress: 0))
        .preferredColorScheme(.dark)
}

#Preview("부화 임박") {
    HomeView(session: .preview(progress: 0.95))
        .preferredColorScheme(.dark)
}
