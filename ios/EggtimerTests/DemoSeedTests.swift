//
//  DemoSeedTests.swift
//  EggtimerTests
//
//  스크린샷용 데모 시드 생성기 검증(순수 로직). DEBUG 전용.
//  30일치 이력 → Weekly 막대(월·화) + Monthly 추세 라인 + 요약 타일이 모두 현실적인지.
//

#if DEBUG
import Testing
import Foundation
@testable import Eggtimer

struct DemoSeedTests {

    /// 고정된 화요일(2026-08-04) + 월요일 시작 달력으로 결정적 검증.
    private func fixedTuesday() -> (Date, Calendar) {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let now = cal.date(from: DateComponents(year: 2026, month: 8, day: 4, hour: 12))!
        return (now, cal)
    }

    @Test func seedShapeIsRealistic() {
        let (now, cal) = fixedTuesday()
        let s = DemoSeed.sessions(now: now, calendar: cal)
        // rethrows 호출은 #expect 밖에서 평가(매크로 try 오진 회피).
        let allCompleted = s.allSatisfy { $0.completed }
        let total = StatsEngine.totalActiveMinutes(s)
        let streak = StatsEngine.currentStreak(s, now: now, calendar: cal)
        let avg = StatsEngine.averageFocusScore(s)

        #expect(s.count > 30)                    // 30일 다세션
        #expect(allCompleted)
        #expect(total >= 1500 && total <= 4000)  // 25~66h = 한 달치로 그럴듯
        #expect(streak >= 14)                    // 최근 2주+ 연속
        #expect(avg >= 85)                       // 높은 집중 질
    }

    @Test func weeklyChartHasBars() {
        let (now, cal) = fixedTuesday()
        let s = DemoSeed.sessions(now: now, calendar: cal)
        let wk = StatsEngine.weeklyHours(s, now: now, calendar: cal)
        // 이번 주(월 시작) = 월·화만 과거 → 두 막대가 채워진다.
        let mon = wk[0], tue = wk[1]
        #expect(mon > 0)
        #expect(tue > 0)
    }

    @Test func monthlyTrendIsMostlyFilled() {
        let (now, cal) = fixedTuesday()
        let s = DemoSeed.sessions(now: now, calendar: cal)
        let daily = StatsEngine.dailyHours(s, days: 30, now: now, calendar: cal)

        #expect(daily.count == 30)
        let last = daily.last ?? 0
        #expect(last > 0)                                 // 오늘 데이터 있음(라인 오른쪽 끝)
        let filled = daily.filter { $0 > 0 }.count
        #expect(filled >= 18)                             // 대부분 채워짐(라인이 비지 않음)
        let rest = daily.filter { $0 == 0 }.count
        #expect(rest >= 1)                                // rest day 존재(자연스러운 변화)
    }
}
#endif
