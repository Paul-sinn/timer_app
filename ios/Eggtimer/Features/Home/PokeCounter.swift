//
//  PokeCounter.swift
//  Eggtimer
//
//  홈 동료를 짧은 시간에 연달아 탭했는지 센다 → `.pestered`("그만 만져") 대사 트리거.
//  순수 값 타입이라 시각을 주입해 유닛 테스트한다.
//

import Foundation

nonisolated struct PokeCounter {
    /// `window`초 안에 `threshold`번 탭하면 "너무 많이 만짐".
    static let window: TimeInterval = 3
    static let threshold = 5

    private var taps: [Date] = []

    /// 탭 1회 기록. 임계에 닿으면 true를 돌려주고 다시 0부터 센다(계속 만지면 또 투덜댄다).
    mutating func register(at now: Date) -> Bool {
        taps = taps.filter { now.timeIntervalSince($0) < Self.window } + [now]
        guard taps.count >= Self.threshold else { return false }
        taps = []
        return true
    }
}
