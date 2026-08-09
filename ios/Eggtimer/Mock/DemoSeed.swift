//
//  DemoSeed.swift
//  Eggtimer
//
//  DEBUG 전용 — App Store 스크린샷용 "현실적인" 집중 이력 생성기(순수·결정적).
//  릴리스 빌드엔 존재하지 않는다. 세션만 만든다(생명체 컬렉션은 안 건드림).
//
//  설계: 최근 30일치. 최근 ~14일은 매일 활동(연속 스트릭), 오래된 절반엔 rest day 몇 개(자연스러운 변화).
//  이번 주 월·화(달력주)엔 튼실한 시간 → Weekly 막대. 30일 일별 = Monthly 추세 라인.
//  최근일수록 조금 더 무겁게(완만한 상승 추세). 대부분 완주 → 점수 높음.
//

#if DEBUG
import Foundation

enum DemoSeed {
    /// 일자별 세션 계획(offset 0 = 오늘). 결정적.
    private static func dayPlan(offset: Int) -> [(minutes: Int, interruptions: Int)] {
        // 오래된 절반에만 rest day(최근 14일은 항상 활동 → 스트릭 보장).
        if offset >= 15 && offset % 6 == 0 { return [] }        // rest: offset 18, 24

        let durations = [50, 25, 75, 50]                        // 순환
        let count: Int
        switch offset {
        case 0...1:  count = 3                                  // 이번 주 월·화 튼실
        case 2...6:  count = offset % 2 == 0 ? 3 : 2
        case 7...13: count = 2
        default:     count = offset % 3 == 0 ? 2 : 1            // 오래된 날 가볍게
        }
        var day: [(Int, Int)] = []
        for i in 0..<count {
            let minutes = durations[(offset + i) % durations.count]
            let interruptions = (i == count - 1 && offset % 4 == 0) ? 1 : 0   // 가끔 이탈
            day.append((minutes, interruptions))
        }
        return day
    }

    /// 스크린샷용 세션 이력(최근 30일). 주입형 now/calendar로 테스트 가능.
    static func sessions(now: Date = Date(), calendar: Calendar = .current) -> [FocusSessionResult] {
        var out: [FocusSessionResult] = []
        let today = calendar.startOfDay(for: now)
        for offset in 0..<30 {
            guard let base = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            for (i, s) in dayPlan(offset: offset).enumerated() {
                let started = calendar.date(byAdding: .hour, value: 9 + i * 3, to: base) ?? base
                let planned = s.minutes * 60
                out.append(FocusSessionResult(
                    startedAt: started,
                    plannedSeconds: planned,
                    activeSeconds: planned,          // 완주
                    interruptionCount: s.interruptions,
                    distracted: false,
                    completed: true,
                    mode: .free))
            }
        }
        return out
    }
}
#endif
