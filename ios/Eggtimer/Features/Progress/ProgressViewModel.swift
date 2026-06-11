//
//  ProgressViewModel.swift
//  Eggtimer
//
//  기록(Progress) 화면의 상태 소스(MVVM). 끝난 세션(FocusSessionResult)에서
//  StatsEngine으로 통계를 파생한다(Phase 2-3b: 실데이터 연결).
//

import SwiftUI

@Observable
final class ProgressViewModel {
    /// 통계의 단일 소스가 되는 끝난 세션 배열.
    let sessions: [FocusSessionResult]

    init(sessions: [FocusSessionResult]) {
        self.sessions = sessions
    }

    var isEmpty: Bool { sessions.isEmpty }

    // MARK: - 요약 통계

    var totalDurationDisplay: String { Self.durationText(StatsEngine.totalActiveMinutes(sessions)) }
    var sessionCount: Int { sessions.count }
    var currentStreakDisplay: String { "\(StatsEngine.currentStreak(sessions))일" }
    var averageScoreDisplay: String { "\(StatsEngine.averageFocusScore(sessions))점" }

    // MARK: - 주간 막대그래프

    let weekdayLabels = ["월", "화", "수", "목", "금", "토", "일"]
    var weeklyHours: [Double] { StatsEngine.weeklyHours(sessions) }
    var weeklyMax: Double { max(weeklyHours.max() ?? 0, 1) }

    // MARK: - 최근 세션 (최신순, 최대 10건)

    var recentSessions: [FocusSessionResult] {
        Array(sessions.sorted { $0.startedAt > $1.startedAt }.prefix(10))
    }

    // MARK: - 헬퍼

    private static func durationText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 { return "\(hours)시간 \(mins)분" }
        if hours > 0 { return "\(hours)시간" }
        return "\(mins)분"
    }
}
