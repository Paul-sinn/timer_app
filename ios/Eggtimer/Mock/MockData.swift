//
//  MockData.swift
//  Eggtimer
//
//  Phase 0(UI 우선) 전용 더미 데이터. 로그인·백엔드 없이 모든 화면이
//  이 Mock만으로 렌더된다. ViewModel이 AppSnapshot을 주입받아 화면을 그린다.
//  화면 검수를 위해 populated/empty 두 상태를 모두 제공한다.
//

import Foundation

/// 한 화면 세트를 그리는 데 필요한 더미 상태 묶음.
struct AppSnapshot {
    let displayName: String
    let creatures: [Creature]
    let sessions: [FocusSession]
    let egg: EggState
}

enum MockData {
    /// 생명체·세션이 골고루 채워진 상태(다양한 레어도/날짜 포함).
    static let populated = AppSnapshot(
        displayName: String(localized: "Focused Racoon"),
        creatures: sampleCreatures,
        sessions: sampleSessions,
        egg: EggState(targetMinutes: 60, focusedMinutes: 38)
    )

    /// 데이터가 비어 있는 상태(빈 화면 검수용).
    static let empty = AppSnapshot(
        displayName: String(localized: "New user"),
        creatures: [],
        sessions: [],
        egg: EggState(targetMinutes: 60, focusedMinutes: 0)
    )

    // MARK: - 더미 컬렉션
    // 7종 중 일부만 발견(나머지는 컬렉션에서 미발견 실루엣으로 노출).
    // 백호는 daysAgo(3)으로 부화 → 진화(20분 경과) 상태로 보인다.

    private static let sampleCreatures: [Creature] = [
        Creature(species: .chicken,    imageName: "ChickenBro", hatchedAt: daysAgo(1)),
        Creature(species: .slime,                               hatchedAt: daysAgo(2)),
        Creature(species: .dino,                                hatchedAt: daysAgo(4)),
        Creature(species: .blackCat,                            hatchedAt: daysAgo(7)),
        Creature(species: .whiteTiger,                          hatchedAt: daysAgo(3))
    ]

    // MARK: - 더미 세션

    private static let sampleSessions: [FocusSession] = [
        FocusSession(date: daysAgo(0), durationMinutes: 25, keptScreenOn: true),
        FocusSession(date: daysAgo(0), durationMinutes: 50, keptScreenOn: true),
        FocusSession(date: daysAgo(1), durationMinutes: 15, keptScreenOn: false),
        FocusSession(date: daysAgo(1), durationMinutes: 45, keptScreenOn: true),
        FocusSession(date: daysAgo(2), durationMinutes: 30, keptScreenOn: true),
        FocusSession(date: daysAgo(3), durationMinutes: 60, keptScreenOn: true),
        FocusSession(date: daysAgo(4), durationMinutes: 20, keptScreenOn: false),
        FocusSession(date: daysAgo(6), durationMinutes: 90, keptScreenOn: true)
    ]

    // MARK: - 더미 세션 결과(프리뷰/검수용 — 실데이터는 FocusHistoryStore)

    static let sampleResults: [FocusSessionResult] = [
        result(daysAgo(0), minutes: 25, interruptions: 0, distracted: false, completed: true),
        result(daysAgo(0), minutes: 50, interruptions: 1, distracted: false, completed: true),
        result(daysAgo(1), minutes: 15, interruptions: 0, distracted: false, completed: false),
        result(daysAgo(1), minutes: 45, interruptions: 2, distracted: true,  completed: true),
        result(daysAgo(2), minutes: 30, interruptions: 0, distracted: false, completed: true),
        result(daysAgo(3), minutes: 60, interruptions: 1, distracted: false, completed: true),
        result(daysAgo(4), minutes: 20, interruptions: 3, distracted: true,  completed: false),
        result(daysAgo(6), minutes: 50, interruptions: 0, distracted: false, completed: true)
    ]

    // MARK: - 헬퍼

    private static func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }

    private static func result(_ date: Date, minutes: Int, interruptions: Int,
                               distracted: Bool, completed: Bool) -> FocusSessionResult {
        FocusSessionResult(startedAt: date, plannedSeconds: minutes * 60,
                           activeSeconds: minutes * 60, interruptionCount: interruptions,
                           distracted: distracted, completed: completed)
    }
}
