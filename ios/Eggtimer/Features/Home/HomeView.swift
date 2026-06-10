//
//  HomeView.swift
//  Eggtimer
//
//  홈 탭. 다크+골드 톤. 상단 헤더(Home + 설정) / 집중 모드 칩 / 대형 타이머 /
//  중앙 픽셀 알(골드 글로우) / 6단계 부화 진행도 / 시작·중단 버튼.
//  Phase 0(UI 더미): 시작/중단은 isRunning(@State)만 토글하며 실제 타이머는 없다.
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel: HomeViewModel
    @State private var isRunning = false

    init(viewModel: HomeViewModel = HomeViewModel(snapshot: MockData.populated)) {
        _viewModel = State(initialValue: viewModel)
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

                EggView(stageIndex: viewModel.stageIndex)
                    .padding(.vertical, AppSpacing.section)

                Spacer(minLength: 0)

                progressSection

                controlButtons
                    .padding(.top, AppSpacing.element)
            }
            .padding(.horizontal, AppSpacing.section)
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

    // MARK: - 집중 모드 칩

    private var focusModeChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "leaf")
                .font(.caption)
            Text("집중 모드")
                .font(AppFont.cardTitle)
            Image(systemName: "chevron.down")
                .font(.caption2)
        }
        .foregroundStyle(AppColor.textBody)
        .padding(.horizontal, AppSpacing.elementTight)
        .padding(.vertical, 7)
        .background(AppColor.cardBackground)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppColor.border, lineWidth: AppSpacing.borderWidth))
    }

    // MARK: - 타이머 표시

    private var timerHeader: some View {
        VStack(spacing: AppSpacing.elementTight) {
            Text(viewModel.timerDisplay)
                .font(AppFont.timer)
                .foregroundStyle(AppColor.textPrimary)
                .monospacedDigit()
            Text(isRunning ? "집중하는 중이에요" : "집중할 준비가 되었나요?")
                .font(AppFont.body)
                .foregroundStyle(AppColor.textSecondary)
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
                Text(viewModel.stageCaption)
                    .font(AppFont.cardTitle)
                    .foregroundStyle(AppColor.textSecondary)
            }
            StageStepper(current: viewModel.stageIndex, total: EggState.visualStages)
        }
    }

    // MARK: - 시작/중단 컨트롤

    @ViewBuilder
    private var controlButtons: some View {
        VStack(spacing: AppSpacing.elementTight) {
            PrimaryButton(isRunning ? "일시정지" : "시작") {
                isRunning.toggle()
            }
            DangerButton("중단") { isRunning = false }
        }
        .padding(.bottom, AppSpacing.element)
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
    HomeView(viewModel: HomeViewModel(
        displayName: "집중하는 너구리",
        egg: EggState(targetMinutes: 60, focusedMinutes: 0)
    ))
    .preferredColorScheme(.dark)
}

#Preview("부화 임박") {
    HomeView(viewModel: HomeViewModel(
        displayName: "집중하는 너구리",
        egg: EggState(targetMinutes: 60, focusedMinutes: 56)
    ))
    .preferredColorScheme(.dark)
}
