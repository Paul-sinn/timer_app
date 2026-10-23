//
//  PokeCounterTests.swift
//  EggtimerTests
//
//  동료 연타 감지("그만 만져" 대사 트리거) 규칙 검증.
//

import Testing
import Foundation
@testable import Eggtimer

struct PokeCounterTests {

    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    /// t0부터 `gap`초 간격으로 `count`번 탭한 결과.
    private func tap(_ counter: inout PokeCounter, count: Int, gap: TimeInterval, from start: TimeInterval = 0) -> [Bool] {
        (0..<count).map { counter.register(at: t0.addingTimeInterval(start + Double($0) * gap)) }
    }

    @Test func aFewQuickTapsAreFine() {
        var c = PokeCounter()
        #expect(tap(&c, count: PokeCounter.threshold - 1, gap: 0.2).allSatisfy { !$0 })
    }

    @Test func tooManyQuickTapsComplainOnTheLastOne() {
        var c = PokeCounter()
        let results = tap(&c, count: PokeCounter.threshold, gap: 0.2)
        #expect(results.dropLast().allSatisfy { !$0 })
        #expect(results.last == true)
    }

    @Test func slowTapsNeverComplain() {
        // 1초 간격이면 3초 창 안에 최대 3번 → 임계(5) 미달.
        var c = PokeCounter()
        #expect(tap(&c, count: 20, gap: 1).allSatisfy { !$0 })
    }

    @Test func countStartsOverAfterComplaining() {
        var c = PokeCounter()
        _ = tap(&c, count: PokeCounter.threshold, gap: 0.2)
        let again = tap(&c, count: PokeCounter.threshold, gap: 0.2, from: 1.0)
        #expect(again.dropLast().allSatisfy { !$0 })
        #expect(again.last == true)
    }
}
