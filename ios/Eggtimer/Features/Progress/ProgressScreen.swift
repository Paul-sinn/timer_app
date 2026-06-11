//
//  ProgressScreen.swift
//  Eggtimer
//
//  기록(Progress) 탭. 다크+골드 톤. 전체 요약(2x2 통계 카드) + 주간 막대그래프 +
//  최근 세션 목록. 좌측 정렬 기본(UI_GUIDE).
//  SwiftUI 내장 `ProgressView`와의 이름 충돌을 피하기 위해 타입명은 `ProgressScreen`.
//  Phase 0(UI 더미): 주입된 [FocusSession]에서 단순 계산만 한다(측정/영속성 없음).
//

import SwiftUI

struct ProgressScreen: View {
    /// 끝난 세션(실데이터는 FocusHistoryStore.sessions 주입, 프리뷰는 더미).
    private let sessions: [FocusSessionResult]

    init(sessions: [FocusSessionResult] = MockData.sampleResults) {
        self.sessions = sessions
    }

    /// 세션에서 통계를 파생(렌더마다 재계산 — sessions 변경 시 자동 갱신).
    private var viewModel: ProgressViewModel { ProgressViewModel(sessions: sessions) }

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

    // MARK: - 본문

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                Text("Progress")
                    .font(.title.weight(.bold))
                    .foregroundStyle(AppColor.textPrimary)

                summarySection
                chartSection
                sessionSection
            }
            .padding(.horizontal, AppSpacing.section)
            .padding(.top, AppSpacing.elementTight)
            .padding(.bottom, AppSpacing.section)
        }
    }

    // MARK: - 전체 요약 (2x2 통계 카드)

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.elementTight) {
            Text("전체 요약")
                .font(AppFont.cardTitle)
                .foregroundStyle(AppColor.textSecondary)

            HStack(spacing: AppSpacing.elementTight) {
                StatCard(icon: "clock.fill", iconColor: AppColor.eggAccent,
                         value: viewModel.totalDurationDisplay, label: "총 집중 시간")
                StatCard(icon: "square.stack.3d.up.fill", iconColor: AppColor.eggAccent,
                         value: "\(viewModel.sessionCount)", label: "세션 수")
            }
            HStack(spacing: AppSpacing.elementTight) {
                StatCard(icon: "flame.fill", iconColor: AppColor.danger,
                         value: viewModel.currentStreakDisplay, label: "현재 연속")
                StatCard(icon: "target", iconColor: AppColor.eggAccent,
                         value: viewModel.averageScoreDisplay, label: "평균 집중 점수")
            }
        }
    }

    // MARK: - 주간 막대그래프

    private var chartSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.element) {
                HStack {
                    Text("집중 시간 (시간)")
                        .font(AppFont.cardTitle)
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("주간")
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                    .font(AppFont.cardTitle)
                    .foregroundStyle(AppColor.textBody)
                }

                WeeklyBarChart(values: viewModel.weeklyHours,
                               labels: viewModel.weekdayLabels,
                               maxValue: viewModel.weeklyMax)
                    .frame(height: 140)
            }
        }
    }

    // MARK: - 최근 세션

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.elementTight) {
            Text("최근 세션")
                .font(AppFont.cardTitle)
                .foregroundStyle(AppColor.textSecondary)

            VStack(spacing: AppSpacing.elementTight) {
                ForEach(viewModel.recentSessions) { SessionRow(session: $0) }
            }
        }
    }

    // MARK: - 빈 상태

    private var emptyState: some View {
        VStack(spacing: AppSpacing.element) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48))
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

/// 통계 카드 한 칸(아이콘 + 값 + 라벨).
private struct StatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(label)
                    .font(AppFont.cardTitle)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
    }
}

/// 주간 막대그래프. 가장 높은 막대는 골드, 나머지는 회색.
private struct WeeklyBarChart: View {
    let values: [Double]
    let labels: [String]
    let maxValue: Double

    var body: some View {
        let maxIdx = values.firstIndex(of: values.max() ?? 0)
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(values.indices, id: \.self) { i in
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        let h = max(geo.size.height * (values[i] / maxValue), 2)
                        VStack {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(i == maxIdx ? AppColor.eggAccent : AppColor.border)
                                .frame(height: h)
                        }
                    }
                    Text(labels[i])
                        .font(.caption2)
                        .foregroundStyle(AppColor.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// 세션 한 건 행(집중 점수 점 + 집중 시간 + 날짜 + 점수/중단 배지).
private struct SessionRow: View {
    let session: FocusSessionResult

    private var dateText: String {
        session.startedAt.formatted(date: .abbreviated, time: .shortened)
    }
    private var durationText: String {
        let h = session.activeMinutes / 60, m = session.activeMinutes % 60
        if h > 0 && m > 0 { return "\(h)시간 \(m)분" }
        if h > 0 { return "\(h)시간" }
        return "\(m)분"
    }
    /// 점수 기반 상태색.
    private var statusColor: Color {
        if session.focusScore >= 80 { return AppColor.success }
        if session.focusScore >= 50 { return AppColor.eggAccent }
        return AppColor.danger
    }

    var body: some View {
        AppCard {
            HStack(spacing: AppSpacing.elementTight) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(durationText)
                            .font(AppFont.body.weight(.semibold))
                            .foregroundStyle(AppColor.textPrimary)
                        if !session.completed {
                            Text("중단")
                                .font(.caption2)
                                .foregroundStyle(AppColor.danger)
                        }
                    }
                    Text(dateText)
                        .font(AppFont.cardTitle)
                        .foregroundStyle(AppColor.textSecondary)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(session.focusScore)점")
                        .font(AppFont.body.weight(.semibold))
                        .foregroundStyle(statusColor)
                    if session.interruptionCount > 0 {
                        Text("이탈 \(session.interruptionCount)")
                            .font(.caption2)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
            }
        }
    }
}

#Preview("populated") {
    ProgressScreen(sessions: MockData.sampleResults)
        .preferredColorScheme(.dark)
}

#Preview("empty") {
    ProgressScreen(sessions: [])
        .preferredColorScheme(.dark)
}
