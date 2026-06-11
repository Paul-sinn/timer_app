//
//  StatsTests.swift
//  EggtimerTests
//
//  이탈 분류 · 집중 점수 · 통계 집계(순수 로직) 검증.
//

import Testing
import Foundation
@testable import Eggtimer

struct StatsTests {

    // MARK: - 이탈 분류 (Feature 6)

    @Test func interruptionSeverityThresholds() {
        #expect(Interruption.severity(awaySeconds: 0) == .ignored)
        #expect(Interruption.severity(awaySeconds: 29) == .ignored)
        #expect(Interruption.severity(awaySeconds: 30) == .minor)
        #expect(Interruption.severity(awaySeconds: 179) == .minor)
        #expect(Interruption.severity(awaySeconds: 180) == .interruption)
        #expect(Interruption.severity(awaySeconds: 599) == .interruption)
        #expect(Interruption.severity(awaySeconds: 600) == .distracted)
        #expect(Interruption.severity(awaySeconds: 99999) == .distracted)
    }

    @Test func ignoredDoesNotCount() {
        #expect(Interruption.severity(awaySeconds: 10).counts == false)
        #expect(Interruption.severity(awaySeconds: 60).counts == true)
    }

    // MARK: - 집중 점수

    @Test func perfectSessionScores100() {
        let s = FocusScore.compute(plannedSeconds: 1500, activeSeconds: 1500,
                                   interruptionCount: 0, distracted: false)
        #expect(s == 100)
    }

    @Test func interruptionsAndDistractedPenalize() {
        // 100 - 2*8 = 84
        #expect(FocusScore.compute(plannedSeconds: 1500, activeSeconds: 1500,
                                   interruptionCount: 2, distracted: false) == 84)
        // 100 - 8 - 20 = 72
        #expect(FocusScore.compute(plannedSeconds: 1500, activeSeconds: 1500,
                                   interruptionCount: 1, distracted: true) == 72)
    }

    @Test func shortfallPenalizesUpTo30() {
        // 절반만 집중(중단): 100 - 0.5*30 = 85
        #expect(FocusScore.compute(plannedSeconds: 1500, activeSeconds: 750,
                                   interruptionCount: 0, distracted: false) == 85)
    }

    @Test func scoreClampsToZero() {
        let s = FocusScore.compute(plannedSeconds: 1500, activeSeconds: 0,
                                   interruptionCount: 20, distracted: true)
        #expect(s == 0)
    }

    // MARK: - 통계 집계 (Feature 5)

    private func result(_ daysAgo: Int, minutes: Int, completed: Bool = true,
                        cal: Calendar = .current, now: Date = Date()) -> FocusSessionResult {
        let date = cal.date(byAdding: .day, value: -daysAgo, to: now)!
        return FocusSessionResult(startedAt: date, plannedSeconds: minutes * 60,
                                  activeSeconds: minutes * 60, interruptionCount: 0,
                                  distracted: false, completed: completed)
    }

    @Test func totalsAndCompletionRate() {
        let sessions = [result(0, minutes: 25), result(1, minutes: 50),
                        result(2, minutes: 10, completed: false)]
        #expect(StatsEngine.totalActiveMinutes(sessions) == 85)
        #expect(StatsEngine.completedCount(sessions) == 2)
        #expect(abs(StatsEngine.completionRate(sessions) - 2.0/3.0) < 0.001)
    }

    @Test func emptyStatsAreZero() {
        #expect(StatsEngine.totalActiveMinutes([]) == 0)
        #expect(StatsEngine.completionRate([]) == 0)
        #expect(StatsEngine.averageFocusScore([]) == 0)
        #expect(StatsEngine.currentStreak([]) == 0)
    }

    @Test func currentStreakCountsConsecutiveDays() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        // 오늘, 어제, 그제 완료 → 3일. 4일 전은 비어 끊김.
        let sessions = [result(0, minutes: 25, cal: cal, now: now),
                        result(1, minutes: 25, cal: cal, now: now),
                        result(2, minutes: 25, cal: cal, now: now),
                        result(5, minutes: 25, cal: cal, now: now)]
        #expect(StatsEngine.currentStreak(sessions, now: now, calendar: cal) == 3)
    }

    @Test func streakAllowsStartingYesterday() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        // 오늘은 없고 어제·그제만 → 2일(아직 오늘이 안 끝났을 수 있음).
        let sessions = [result(1, minutes: 25, cal: cal, now: now),
                        result(2, minutes: 25, cal: cal, now: now)]
        #expect(StatsEngine.currentStreak(sessions, now: now, calendar: cal) == 2)
    }
}
