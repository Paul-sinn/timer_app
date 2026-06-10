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
        displayName: "집중하는 너구리",
        creatures: sampleCreatures,
        sessions: sampleSessions,
        egg: EggState(targetMinutes: 60, focusedMinutes: 38)
    )

    /// 데이터가 비어 있는 상태(빈 화면 검수용).
    static let empty = AppSnapshot(
        displayName: "새로운 사용자",
        creatures: [],
        sessions: [],
        egg: EggState(targetMinutes: 60, focusedMinutes: 0)
    )

    // MARK: - 더미 컬렉션

    private static let sampleCreatures: [Creature] = [
        Creature(name: "이끼 달팽이",   rarity: .common,    imageName: "creature_moss_snail",   hatchedAt: daysAgo(1)),
        Creature(name: "조약돌 거북",   rarity: .common,    imageName: "creature_pebble_turtle", hatchedAt: daysAgo(2)),
        Creature(name: "안개 여우",     rarity: .rare,      imageName: "creature_mist_fox",      hatchedAt: daysAgo(4)),
        Creature(name: "달빛 올빼미",   rarity: .rare,      imageName: "creature_moon_owl",      hatchedAt: daysAgo(7)),
        Creature(name: "수정 사슴",     rarity: .epic,      imageName: "creature_crystal_deer",  hatchedAt: daysAgo(12)),
        Creature(name: "불씨 도롱뇽",   rarity: .epic,      imageName: "creature_ember_newt",    hatchedAt: daysAgo(20)),
        Creature(name: "별가루 용",     rarity: .legendary, imageName: "creature_stardust_dragon", hatchedAt: daysAgo(31))
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

    // MARK: - 헬퍼

    private static func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }
}
