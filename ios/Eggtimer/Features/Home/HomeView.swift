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
    /// 부화 결과 시트로 띄울 새 생명체.
    @State private var hatchedCreature: Creature?
    /// 부화 후 알 자리를 대체해 표시 중인 생명체(idle 상태에서만 노출).
    @State private var hatchling: Creature?

    init(session: SessionManager, store: CollectionStore = CollectionStore()) {
        _session = State(initialValue: session)
        self.store = store
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

    var body: some View {
        ZStack {
            AppColor.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                focusModeChip
                timerHeader
                    .padding(.top, AppSpacing.element)
                centerStage
                    .padding(.vertical, AppSpacing.section)
                Spacer(minLength: 0)
                if !showingHatchling { progressSection }
                controlButtons
                    .padding(.top, AppSpacing.element)
            }
            .padding(.horizontal, AppSpacing.section)
        }
        .sheet(item: $hatchedCreature, onDismiss: { session.acknowledgeCompletion() }) {
            HatchResultSheet(creature: $0)
        }
        .onChange(of: session.isCompleted) { _, completed in
            if completed && hatchedCreature == nil {
                let born = store.hatch()          // 목표 도달 → 확률 부화 + 컬렉션 반영
                hatchedCreature = born            // 결과 시트
                hatchling = born                  // 알 자리를 태어난 캐릭터로 대체
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:     session.handleForeground()
            case .background: session.handleBackground()
            default:          break
            }
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

    // MARK: - 집중 시간 선택 칩 (idle일 때만 변경 가능)

    private var focusModeChip: some View {
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
        .disabled(!session.isIdle)
        .opacity(session.isIdle ? 1 : 0.5)
    }

    // MARK: - 중앙 무대 (알 ↔ 부화한 캐릭터)

    /// idle 상태에서 부화한 캐릭터를 알 자리에 표시 중인지.
    private var showingHatchling: Bool { session.isIdle && hatchling != nil }

    @ViewBuilder
    private var centerStage: some View {
        if showingHatchling, let hatchling {
            HatchedCenter(creature: hatchling)
        } else {
            EggView(stageIndex: session.stageIndex)
        }
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
            switch session.phase {
            case nil:
                if hatchling != nil {
                    PrimaryButton("새 알 받기") { hatchling = nil }
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
                PrimaryButton("부화 확인") {
                    if hatchedCreature == nil { hatchedCreature = store.hatch() }
                }
            }
        }
        .padding(.bottom, AppSpacing.element)
    }
}

/// 부화 직후 알 자리를 대체해 표시되는 생명체. 알과 동일한 footprint + 등급색 글로우.
private struct HatchedCenter: View {
    let creature: Creature
    var height: CGFloat = 240
    @State private var appeared = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [creature.rarity.color.opacity(0.30), .clear],
                        center: .center, startRadius: 4, endRadius: height * 0.62
                    )
                )
                .frame(width: height * 1.25, height: height * 1.25)

            Image(creature.displayImageName)
                .interpolation(.none)            // 픽셀아트 선명하게
                .resizable()
                .scaledToFit()
                .frame(height: height * 0.82)
                .scaleEffect(appeared ? 1 : 0.7)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: appeared)
        }
        .frame(height: height)
        .onAppear { appeared = true }
        .accessibilityLabel(Text("\(creature.rarity.label) \(creature.name)"))
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
