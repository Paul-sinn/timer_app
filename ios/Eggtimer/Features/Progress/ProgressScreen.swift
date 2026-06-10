//
//  ProgressScreen.swift
//  Eggtimer
//
//  기록(Progress) 탭 화면. 내가 얼마나 집중했는지(화면을 끄지 않고 유지했는지) 기록을 본다.
//  상단 요약 통계(AppCard) + 최신순 세션 목록으로 구성한다. 좌측 정렬 기본(UI_GUIDE).
//  SwiftUI 내장 `ProgressView`와의 이름 충돌을 피하기 위해 타입명은 `ProgressScreen`.
//  Phase 0(UI 더미): 주입된 [FocusSession]에서 단순 계산만 한다(측정/영속성 없음).
//

import SwiftUI

struct ProgressScreen: View {
    @State private var viewModel: ProgressViewModel

    init(viewModel: ProgressViewModel = ProgressViewModel(snapshot: MockData.populated)) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            AppColor.pageBackground.ignoresSafeArea()

            if viewModel.isEmpty {
                emptyState
            } else {
                content
            }
        }
    }

    // MARK: - 본문(요약 + 목록)

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                SectionHeader("기록")

                summaryCard

                sessionList
            }
            .padding(.horizontal, AppSpacing.section)
            .padding(.vertical, AppSpacing.section)
        }
    }

    // MARK: - 요약 통계 카드

    private var summaryCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.element) {
                Text("요약")
                    .font(AppFont.cardTitle)
                    .foregroundStyle(AppColor.textSecondary)

                HStack(alignment: .top, spacing: AppSpacing.element) {
                    SummaryStat(
                        label: "총 집중 시간",
                        value: viewModel.totalDurationDisplay,
                        valueColor: AppColor.eggAccent
                    )
                    SummaryStat(
                        label: "세션 수",
                        value: "\(viewModel.sessionCount)회",
                        valueColor: AppColor.textPrimary
                    )
                    SummaryStat(
                        label: "화면 유지",
                        value: viewModel.keptScreenOnDisplay,
                        valueColor: AppColor.success
                    )
                }
            }
        }
    }

    // MARK: - 세션 기록 목록(최신순)

    private var sessionList: some View {
        VStack(alignment: .leading, spacing: AppSpacing.elementTight) {
            Text("세션 기록")
                .font(AppFont.cardTitle)
                .foregroundStyle(AppColor.textSecondary)

            VStack(spacing: AppSpacing.elementTight) {
                ForEach(viewModel.recentSessions) { session in
                    SessionRow(session: session)
                }
            }
        }
    }

    // MARK: - 빈 상태

    private var emptyState: some View {
        VStack(spacing: AppSpacing.element) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(AppColor.textDisabled)
            Text("아직 기록이 없어요")
                .font(AppFont.body)
                .foregroundStyle(AppColor.textBody)
            Text("집중 세션을 마치면 여기에 기록이 쌓여요")
                .font(AppFont.cardTitle)
                .foregroundStyle(AppColor.textSecondary)
        }
        .padding(AppSpacing.section)
    }
}

/// 요약 카드 안의 통계 한 칸(라벨 + 값). 값만 시맨틱 색으로 강조.
private struct SummaryStat: View {
    let label: String
    let value: String
    let valueColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(AppFont.screenTitle)
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(AppFont.cardTitle)
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 세션 한 건 행(날짜 + 집중 시간 + 화면 유지 배지). AppCard 컨테이너.
private struct SessionRow: View {
    let session: FocusSession

    private var dateText: String {
        session.date.formatted(date: .abbreviated, time: .omitted)
    }

    private var durationText: String {
        let hours = session.durationMinutes / 60
        let mins = session.durationMinutes % 60
        if hours > 0 && mins > 0 { return "\(hours)시간 \(mins)분" }
        if hours > 0 { return "\(hours)시간" }
        return "\(mins)분"
    }

    var body: some View {
        AppCard {
            HStack(spacing: AppSpacing.element) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(durationText)
                        .font(AppFont.body.weight(.semibold))
                        .foregroundStyle(AppColor.textPrimary)
                    Text(dateText)
                        .font(AppFont.cardTitle)
                        .foregroundStyle(AppColor.textSecondary)
                }

                Spacer(minLength: 0)

                KeptScreenOnBadge(keptScreenOn: session.keptScreenOn)
            }
        }
    }
}

/// 화면 유지 여부 배지. 유지=success, 중단=danger. AppColor 토큰만 사용.
private struct KeptScreenOnBadge: View {
    let keptScreenOn: Bool

    private var color: Color { keptScreenOn ? AppColor.success : AppColor.danger }
    private var label: String { keptScreenOn ? "화면 유지" : "화면 꺼짐" }
    private var symbol: String { keptScreenOn ? "checkmark.circle" : "xmark.circle" }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(label)
        }
        .font(AppFont.cardTitle)
        .foregroundStyle(color)
        .padding(.horizontal, AppSpacing.elementTight)
        .padding(.vertical, 4)
        .background(color.opacity(0.18))
        .overlay(
            Capsule().stroke(color.opacity(0.5), lineWidth: AppSpacing.borderWidth)
        )
        .clipShape(Capsule())
    }
}

#Preview("populated") {
    ProgressScreen(viewModel: ProgressViewModel(sessions: MockData.populated.sessions))
        .preferredColorScheme(.dark)
}

#Preview("empty") {
    ProgressScreen(viewModel: ProgressViewModel(sessions: MockData.empty.sessions))
        .preferredColorScheme(.dark)
}
