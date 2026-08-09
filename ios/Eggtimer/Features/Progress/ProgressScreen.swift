//
//  ProgressScreen.swift
//  Eggtimer
//
//  기록(Progress) 탭. 다크+골드 톤. Summary(2x2 통계 카드) + Weekly 막대그래프 +
//  Recent sessions 목록. 좌측 정렬 기본(UI_GUIDE).
//  SwiftUI 내장 `ProgressView`와의 이름 충돌을 피하기 위해 타입명은 `ProgressScreen`.
//  Phase 0(UI 더미): 주입된 [FocusSession]에서 단순 계산만 한다(측정/영속성 없음).
//

import SwiftUI

struct ProgressScreen: View {
    /// 끝난 세션(실데이터는 FocusHistoryStore.sessions 주입, 프리뷰는 더미).
    private let sessions: [FocusSessionResult]

    /// 통계 값 설명 모달(nil = 닫힘). Focus quality·Streak 공용.
    @State private var info: StatInfo?
    /// 차트 범위(Weekly 막대 / Monthly 추세 라인).
    @State private var chartMode: ChartMode = .weekly

    private enum ChartMode {
        case weekly, monthly
        var label: LocalizedStringKey { self == .weekly ? "Weekly" : "Monthly" }
    }

    /// 설명이 필요한 통계 종류.
    private enum StatInfo: Identifiable {
        case focusQuality, streak
        var id: Int { self == .focusQuality ? 0 : 1 }
        var icon: String { self == .focusQuality ? "target" : "flame.fill" }
        var iconColor: Color { self == .focusQuality ? AppColor.eggAccent : AppColor.danger }
        var title: LocalizedStringKey {
            self == .focusQuality ? "What's Focus quality?" : "How streaks work"
        }
        var message: LocalizedStringKey {
            switch self {
            case .focusQuality:
                return "Each finished session scores up to 100. You lose points for ending early, leaving the app, or long distractions. This is the average across your sessions."
            case .streak:
                return "The number of days in a row with a finished session. Miss a whole day and it resets — but today never counts against you until it's over."
            }
        }
    }

    /// 차트 플롯(막대/라인) 영역 높이. y축·플롯이 이 높이로 정렬된다(x라벨은 아래 별도).
    private static let plotHeight: CGFloat = 120

    init(sessions: [FocusSessionResult] = MockData.sampleResults) {
        self.sessions = sessions
    }

    /// 세션에서 통계를 파생(렌더마다 재계산 — sessions 변경 시 자동 갱신).
    private var viewModel: ProgressViewModel { ProgressViewModel(sessions: sessions) }

    var body: some View {
        ZStack {
            ThemedBackground()
            if viewModel.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .overlay { if let info { infoModal(info) } }
    }

    /// 통계 값 설명 카드(스크림 탭·CTA로 닫힘). Focus quality·Streak 공용 — 인앱 설명 부재 해소.
    private func infoModal(_ info: StatInfo) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { dismissInfo() }

            VStack(spacing: AppSpacing.element) {
                Image(systemName: info.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(info.iconColor)
                Text(info.title)
                    .font(AppFont.screenTitle)
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(info.message)
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.textBody)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                PrimaryButton("Got it") { dismissInfo() }
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

    private func dismissInfo() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { info = nil }
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

    // MARK: - Summary (2x2 통계 카드)

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.elementTight) {
            Text("All-time")
                .font(AppFont.cardTitle)
                .foregroundStyle(AppColor.textSecondary)

            HStack(spacing: AppSpacing.elementTight) {
                StatCard(icon: "clock.fill", iconColor: AppColor.eggAccent,
                         value: viewModel.totalDurationDisplay, label: "Total focus")
                StatCard(icon: "square.stack.3d.up.fill", iconColor: AppColor.eggAccent,
                         value: "\(viewModel.sessionCount)", label: "Sessions")
            }
            HStack(spacing: AppSpacing.elementTight) {
                StatCard(icon: "flame.fill", iconColor: AppColor.danger,
                         value: viewModel.currentStreakDisplay, label: "Current streak",
                         onInfo: { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { info = .streak } })
                StatCard(icon: "target", iconColor: AppColor.eggAccent,
                         value: viewModel.averageScoreDisplay, label: "Focus quality",
                         onInfo: { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { info = .focusQuality } })
            }
        }
    }

    // MARK: - Weekly 막대그래프

    private var chartSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.element) {
                HStack {
                    Text("Focus time (hours)")
                        .font(AppFont.cardTitle)
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer()
                    Menu {
                        Button("Weekly") { chartMode = .weekly }
                        Button("Monthly") { chartMode = .monthly }
                    } label: {
                        HStack(spacing: 4) {
                            Text(chartMode.label)
                            Image(systemName: "chevron.down").font(.caption2)
                        }
                        .font(AppFont.cardTitle)
                        .foregroundStyle(AppColor.textBody)
                    }
                }

                let maxV = chartMode == .weekly ? viewModel.weeklyMax : viewModel.monthlyMax
                HStack(alignment: .top, spacing: 8) {
                    ChartYAxis(maxValue: maxV, height: Self.plotHeight)
                    if chartMode == .weekly {
                        WeeklyBarChart(values: viewModel.weeklyHours,
                                       labels: viewModel.weekdayLabels,
                                       maxValue: viewModel.weeklyMax,
                                       plotHeight: Self.plotHeight)
                    } else {
                        MonthlyLineChart(values: viewModel.monthlyHours,
                                         maxValue: viewModel.monthlyMax,
                                         plotHeight: Self.plotHeight)
                    }
                }
            }
        }
    }

    // MARK: - Recent sessions

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.elementTight) {
            Text("Recent sessions")
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
            Text("No records yet")
                .font(AppFont.body)
                .foregroundStyle(AppColor.textBody)
            Text("Finish a focus session and it'll show up here")
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
    let label: LocalizedStringKey
    /// 지정 시 우상단 "?" 버튼 노출(값 설명 모달 열기).
    var onInfo: (() -> Void)? = nil

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 0) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(iconColor)
                    Spacer(minLength: 0)
                    if let onInfo {
                        Button(action: onInfo) {
                            Image(systemName: "questionmark.circle")
                                .font(.footnote)
                                .foregroundStyle(AppColor.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("What's Focus quality?"))
                    }
                }
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

/// 시간값 라벨("2.1h").
private func hoursLabel(_ v: Double) -> String {
    v <= 0 ? "0h" : String(format: "%.1fh", v)
}

/// 차트 좌측 y축 — 시간 눈금(max / 중간 / 0h). 플롯 높이에 맞춰 정렬돼 막대·라인 높이를 읽게 한다.
private struct ChartYAxis: View {
    let maxValue: Double
    let height: CGFloat

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(hoursLabel(maxValue))
            Spacer()
            Text(hoursLabel(maxValue / 2))
            Spacer()
            Text("0h")
        }
        .font(.system(size: 9))
        .foregroundStyle(AppColor.textSecondary)
        .frame(width: 30, height: height, alignment: .trailing)
    }
}

/// Weekly 막대그래프(플롯만 — 좌측 y축이 시간 스케일 제공). 최고 막대는 골드.
private struct WeeklyBarChart: View {
    let values: [Double]
    let labels: [String]
    let maxValue: Double
    let plotHeight: CGFloat

    var body: some View {
        let maxIdx = values.firstIndex(of: values.max() ?? 0)
        return VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(values.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(i == maxIdx ? AppColor.eggAccent : AppColor.border)
                        .frame(height: max(plotHeight * (values[i] / maxValue), 2))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: plotHeight, alignment: .bottom)
            HStack(spacing: 8) {
                ForEach(labels.indices, id: \.self) { i in
                    Text(labels[i])
                        .font(.caption2)
                        .foregroundStyle(AppColor.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

/// Monthly 추세 라인차트. 최근 30일 일별 집중 시간을 area+line으로(막대 30개 대신 시계열).
private struct MonthlyLineChart: View {
    let values: [Double]
    let maxValue: Double
    let plotHeight: CGFloat

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let n = max(values.count, 1)
                let pts: [CGPoint] = values.enumerated().map { i, v in
                    let x = n == 1 ? w / 2 : w * CGFloat(i) / CGFloat(n - 1)
                    let y = h - CGFloat(min(v / maxValue, 1)) * h
                    return CGPoint(x: x, y: y)
                }
                ZStack {
                    // 하단으로 닫은 area(그라데이션 채움).
                    Path { p in
                        guard let first = pts.first else { return }
                        p.move(to: CGPoint(x: first.x, y: h))
                        p.addLine(to: first)
                        for pt in pts.dropFirst() { p.addLine(to: pt) }
                        if let last = pts.last { p.addLine(to: CGPoint(x: last.x, y: h)) }
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [AppColor.eggAccent.opacity(0.35),
                                                  AppColor.eggAccent.opacity(0.02)],
                                         startPoint: .top, endPoint: .bottom))
                    // 추세 라인.
                    Path { p in
                        guard let first = pts.first else { return }
                        p.move(to: first)
                        for pt in pts.dropFirst() { p.addLine(to: pt) }
                    }
                    .stroke(AppColor.eggAccent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(height: plotHeight)
            HStack {
                Text("30 days ago")
                Spacer()
                Text("Today")
            }
            .font(.caption2)
            .foregroundStyle(AppColor.textSecondary)
        }
    }
}

/// 세션 한 건 행(집중 점수 점 + 집중 시간 + 날짜 + 점수/Stop 배지).
private struct SessionRow: View {
    let session: FocusSessionResult

    private var dateText: String {
        session.startedAt.formatted(date: .abbreviated, time: .shortened)
    }
    private var durationText: String {
        let h = session.activeMinutes / 60, m = session.activeMinutes % 60
        if h > 0 && m > 0 { return String(localized: "\(h)h \(m)m") }
        if h > 0 { return String(localized: "\(h)h") }
        return String(localized: "\(m)m")
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
                            Text(String(localized: "session.stopped", defaultValue: "Stop"))
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
                    Text("\(session.focusScore) pts")
                        .font(AppFont.body.weight(.semibold))
                        .foregroundStyle(statusColor)
                    if session.interruptionCount > 0 {
                        Text("Distractions \(session.interruptionCount)")
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
