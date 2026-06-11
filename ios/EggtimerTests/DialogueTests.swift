//
//  DialogueTests.swift
//  EggtimerTests
//
//  대사 선택 로직 검증(트리거 필터 / 비반복 / 쿨다운 / 조건 / 가중치).
//

import Testing
import Foundation
@testable import Eggtimer

@MainActor
private final class Clock {
    var now = Date(timeIntervalSince1970: 1_000_000)
    func advance(_ s: TimeInterval) { now += s }
}

private struct SeededGen: RandomNumberGenerator {
    var state: UInt64
    init(_ seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

@MainActor
struct DialogueTests {

    private func sampleLines() -> [DialogueLine] {
        [
            .init(id: "i1", text: "idle1", trigger: .idle, weight: 10, cooldown: 100),
            .init(id: "i2", text: "idle2", trigger: .idle, weight: 10, cooldown: 100),
            .init(id: "i3", text: "idle3", trigger: .idle, weight: 10, cooldown: 100),
            .init(id: "d1", text: "done", trigger: .sessionComplete, weight: 10, cooldown: 100),
            .init(id: "s3", text: "streak3", trigger: .sessionComplete, weight: 10, minStreak: 3, cooldown: 100)
        ]
    }

    @Test func picksOnlyMatchingTrigger() {
        let clock = Clock()
        let m = DialogueManager(lines: sampleLines(), clock: { clock.now })
        var g = SeededGen(1)
        m.fire(.sessionComplete, streak: 0, using: &g)
        #expect(m.currentLine?.trigger == .sessionComplete)
        #expect(m.currentLine?.id == "d1")     // streak3는 조건 미달로 제외
    }

    @Test func streakConditionGatesLines() {
        let clock = Clock()
        let m = DialogueManager(lines: sampleLines(), clock: { clock.now })
        // streak 0 → s3 불가
        for seed in UInt64(0)..<20 {
            var g = SeededGen(seed)
            let m2 = DialogueManager(lines: sampleLines(), clock: { clock.now })
            m2.fire(.sessionComplete, streak: 0, using: &g)
            #expect(m2.currentLine?.id != "s3")
        }
        _ = m
    }

    @Test func avoidsImmediateRepetition() {
        let clock = Clock()
        let m = DialogueManager(lines: sampleLines(), recentWindow: 2,
                                globalCooldown: 0, clock: { clock.now })
        var g = SeededGen(7)
        m.fire(.idle, using: &g)
        let first = m.currentLine?.id
        clock.advance(1)
        m.fire(.idle, using: &g)
        let second = m.currentLine?.id
        #expect(first != nil && second != nil)
        #expect(first != second)               // 최근 표시는 다시 안 뽑힘
    }

    @Test func globalCooldownBlocksNonComplete() {
        let clock = Clock()
        let m = DialogueManager(lines: sampleLines(), globalCooldown: 10, clock: { clock.now })
        var g = SeededGen(3)
        m.fire(.idle, using: &g)
        let first = m.currentLine?.id
        m.fire(.idle, using: &g)               // 즉시 재호출 → 전역 쿨다운으로 무시
        #expect(m.currentLine?.id == first)
    }

    @Test func sessionCompleteBypassesGlobalCooldown() {
        let clock = Clock()
        let m = DialogueManager(lines: sampleLines(), globalCooldown: 10, clock: { clock.now })
        var g = SeededGen(5)
        m.fire(.idle, using: &g)
        m.fire(.sessionComplete, streak: 0, using: &g)  // 완료는 쿨다운 무시
        #expect(m.currentLine?.trigger == .sessionComplete)
    }

    @Test func noCandidatesLeavesLineUnchanged() {
        let clock = Clock()
        let m = DialogueManager(lines: sampleLines(), clock: { clock.now })
        var g = SeededGen(9)
        m.fire(.idle, using: &g)
        let before = m.currentLine?.id
        m.fire(.focusing, using: &g)           // focusing 줄 없음 → 변화 없음(크래시 X)
        #expect(m.currentLine?.id == before)
    }
}
