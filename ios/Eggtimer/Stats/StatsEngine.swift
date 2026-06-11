//
//  StatsEngine.swift
//  Eggtimer
//
//  집중 통계 집계(Feature 5). 끝난 세션 목록에서 순수 함수로 계산한다.
//  시계/달력을 주입받아 테스트 가능. (대규모 최적화는 추후 DailyStat 롤업으로 — FEATURE_DESIGN)
//

import Foundation

enum StatsEngine {

    /// 총 누적 유효 집중 시간(분).
    static func totalActiveMinutes(_ sessions: [FocusSessionResult]) -> Int {
        sessions.reduce(0) { $0 + $1.activeSeconds } / 60
    }

    static func completedCount(_ sessions: [FocusSessionResult]) -> Int {
        sessions.filter(\.completed).count
    }

    /// 완료율 0...1 (완료 / 전체).
    static func completionRate(_ sessions: [FocusSessionResult]) -> Double {
        guard !sessions.isEmpty else { return 0 }
        return Double(completedCount(sessions)) / Double(sessions.count)
    }

    /// 평균 집중 점수(0...100). 세션 없으면 0.
    static func averageFocusScore(_ sessions: [FocusSessionResult]) -> Int {
        guard !sessions.isEmpty else { return 0 }
        let sum = sessions.reduce(0) { $0 + $1.focusScore }
        return Int((Double(sum) / Double(sessions.count)).rounded())
    }

    static func totalInterruptions(_ sessions: [FocusSessionResult]) -> Int {
        sessions.reduce(0) { $0 + $1.interruptionCount }
    }

    /// 이번 주(월~일) 요일별 집중 시간(시간 단위). index 0=월 ... 6=일.
    static func weeklyHours(_ sessions: [FocusSessionResult],
                            now: Date = Date(), calendar: Calendar = .current) -> [Double] {
        var hours = [Double](repeating: 0, count: 7)
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return hours }
        for s in sessions where week.contains(s.startedAt) {
            let wd = calendar.component(.weekday, from: s.startedAt) // 1=일 ... 7=토
            let idx = (wd + 5) % 7                                   // 월=0 ... 일=6
            hours[idx] += Double(s.activeSeconds) / 3600.0
        }
        return hours
    }

    /// 오늘 누적 집중 시간(분).
    static func todayActiveMinutes(_ sessions: [FocusSessionResult],
                                   now: Date = Date(), calendar: Calendar = .current) -> Int {
        sessions
            .filter { calendar.isDate($0.startedAt, inSameDayAs: now) }
            .reduce(0) { $0 + $1.activeSeconds } / 60
    }

    /// 현재 연속 집중 일수. 오늘(또는 어제부터 이어진) 기준 완료 세션이 있는 연속 일자 수.
    static func currentStreak(_ sessions: [FocusSessionResult],
                              now: Date = Date(), calendar: Calendar = .current) -> Int {
        let activeDays = Set(sessions
            .filter { $0.completed }
            .map { calendar.startOfDay(for: $0.startedAt) })
        guard !activeDays.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: now)
        // 오늘 활동이 없으면 어제부터 카운트(아직 오늘이 안 끝났을 수 있음).
        var cursor = activeDays.contains(today)
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today)!
        var streak = 0
        while activeDays.contains(cursor) {
            streak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        return streak
    }
}
