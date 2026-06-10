//
//  HomeView.swift
//  Eggtimer
//
//  홈 탭 화면. UI_GUIDE "알이 주인공" 원칙대로 중앙 알을 시각적 중심에 두고,
//  그 위에 대형 모노스페이스 타이머를, 아래에 부화 진행/컨트롤을 배치한다.
//  Phase 0(UI 더미): 시작/중단은 isRunning(@State)만 토글하며 실제 타이머는 없다.
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel: HomeViewModel
    /// 실제 카운트다운 없이 UI 상태만 토글하는 진행 플래그.
    @State private var isRunning = false

    init(viewModel: HomeViewModel = HomeViewModel(snapshot: MockData.populated)) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            AppColor.pageBackground.ignoresSafeArea()

            VStack(spacing: AppSpacing.sectionLoose) {
                Spacer(minLength: 0)

                timerHeader

                EggView(crackStage: viewModel.egg.crackStage)

                progressSection

                Spacer(minLength: 0)

                controlButton
            }
            .padding(.horizontal, AppSpacing.section)
            .padding(.vertical, AppSpacing.section)
        }
    }

    // MARK: - 타이머 표시

    private var timerHeader: some View {
        VStack(spacing: AppSpacing.elementTight) {
            Text(viewModel.timerDisplay)
                .font(AppFont.timer)
                .foregroundStyle(AppColor.textPrimary)
                .monospacedDigit()
            Text(isRunning ? "집중하는 중이에요" : "집중을 시작해 알을 부화시켜요")
                .font(AppFont.body)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    // MARK: - 부화 진행 표시

    private var progressSection: some View {
        VStack(spacing: AppSpacing.elementTight) {
            ProgressBar(progress: viewModel.egg.progress)
                .frame(height: 8)

            HStack {
                Text(viewModel.crackCaption)
                Spacer()
                Text(viewModel.progressCaption)
            }
            .font(AppFont.cardTitle)
            .foregroundStyle(AppColor.textSecondary)
        }
    }

    // MARK: - 시작/중단 컨트롤

    @ViewBuilder
    private var controlButton: some View {
        if isRunning {
            DangerButton("중단") { isRunning = false }
        } else {
            PrimaryButton("집중 시작") { isRunning = true }
        }
    }
}

/// 부화 진행도(0...1) 가로 막대. eggAccent 채움.
private struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColor.border)
                Capsule()
                    .fill(AppColor.eggAccent)
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
            }
        }
        .accessibilityLabel(Text("부화 진행도"))
        .accessibilityValue(Text("\(Int((progress * 100).rounded()))퍼센트"))
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
        egg: EggState(targetMinutes: 60, focusedMinutes: 58)
    ))
    .preferredColorScheme(.dark)
}
