//
//  ProgressViewModel.swift
//  Eggtimer
//
//  기록(Progress) 화면의 상태 소스(MVVM). Phase 0이므로 주입된 [FocusSession]에서
//  단순 계산만 한다(실제 측정/집계/영속성 없음 — Phase 2 범위).
//

import SwiftUI

@Observable
final class ProgressViewModel {
    /// 통계·목록의 단일 소스가 되는 세션 배열(외부 주입).
    let sessions: [FocusSession]

    init(sessions: [FocusSession]) {
        self.sessions = sessions
    }

    /// AppSnapshot에서 기록에 필요한 부분만 추려 주입.
    convenience init(snapshot: AppSnapshot) {
        self.init(sessions: snapshot.sessions)
    }

    /// 기록이 하나도 없는 빈 상태인지.
    var isEmpty: Bool { sessions.isEmpty }

    // MARK: - 요약 통계

    /// 총 누적 집중 시간(분).
    var totalMinutes: Int {
        sessions.reduce(0) { $0 + $1.durationMinutes }
    }

    /// 총 집중 시간 표시값(예: "5시간 12분", "45분").
    var totalDurationDisplay: String {
        Self.durationText(totalMinutes)
    }

    /// 총 세션 수.
    var sessionCount: Int { sessions.count }

    /// 화면 유지 비율(0...1). keptScreenOn == true 세션 비율.
    var keptScreenOnRatio: Double {
        guard !sessions.isEmpty else { return 0 }
        let kept = sessions.filter(\.keptScreenOn).count
        return Double(kept) / Double(sessions.count)
    }

    /// 화면 유지 비율 표시값(예: "75%").
    var keptScreenOnDisplay: String {
        "\(Int((keptScreenOnRatio * 100).rounded()))%"
    }

    /// 현재 연속 집중 일수(더미 — Phase 2에서 실제 계산).
    let currentStreakDisplay = "12일"

    /// 최고 기록(더미 — Phase 2에서 실제 계산).
    let bestRecordDisplay = "23회"

    // MARK: - 주간 막대그래프

    /// 요일 라벨(월~일).
    let weekdayLabels = ["월", "화", "수", "목", "금", "토", "일"]

    /// 요일별 집중 시간(시간 단위, 월=0 ... 일=6). 주입 세션에서 집계.
    var weeklyHours: [Double] {
        var arr = [Double](repeating: 0, count: 7)
        let cal = Calendar.current
        for s in sessions {
            let wd = cal.component(.weekday, from: s.date) // 1=일 ... 7=토
            let idx = (wd + 5) % 7                          // 월=0 ... 일=6
            arr[idx] += Double(s.durationMinutes) / 60.0
        }
        return arr
    }

    /// 그래프 Y축 상한(가장 큰 막대 기준, 최소 1).
    var weeklyMax: Double { max(weeklyHours.max() ?? 0, 1) }

    // MARK: - 세션 기록(최신순)

    /// 최신순으로 정렬된 세션 목록.
    var recentSessions: [FocusSession] {
        sessions.sorted { $0.date > $1.date }
    }

    // MARK: - 헬퍼

    /// 분 단위를 "N시간 M분" / "M분" 형태로 변환한다.
    private static func durationText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 { return "\(hours)시간 \(mins)분" }
        if hours > 0 { return "\(hours)시간" }
        return "\(mins)분"
    }
}
