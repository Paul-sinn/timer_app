//
//  DialogueTests.swift
//  EggtimerTests
//
//  대사 선택 엔진 검증(트리거+화자 필터 / 비반복 / 쿨다운 / 가중치). dialoguesystem.md 신모델.
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
            .init(id: "i1", text: "idle1", trigger: .idle, cooldown: 100),
            .init(id: "i2", text: "idle2", trigger: .idle, cooldown: 100),
            .init(id: "i3", text: "idle3", trigger: .idle, cooldown: 100),
            .init(id: "s1", text: "start1", trigger: .sessionStart, cooldown: 100),
            .init(id: "s2", text: "start2", trigger: .sessionStart, cooldown: 100),
            .init(id: "c1", text: "redA", speaker: .creature(.redChicken), trigger: .greeting, cooldown: 100),
            .init(id: "c2", text: "redB", speaker: .creature(.redChicken), trigger: .greeting, cooldown: 100),
        ]
    }

    @Test func picksOnlyMatchingTrigger() {
        let clock = Clock()
        let m = DialogueManager(lines: sampleLines(), clock: { clock.now })
        var g = SeededGen(1)
        m.fire(.sessionStart, using: &g)
        #expect(m.currentLine?.trigger == .sessionStart)
        #expect(m.currentLine?.id.hasPrefix("s") == true)
    }

    @Test func speakerFiltersPool() {
        let clock = Clock()
        let m = DialogueManager(lines: sampleLines(), clock: { clock.now })
        var g = SeededGen(2)
        // greeting을 egg로 쏘면 후보 없음 → 변화 없음.
        m.fire(.greeting, speaker: .egg, using: &g)
        #expect(m.currentLine == nil)
        // creature(.redChicken)으로 쏘면 그 풀에서만.
        m.fire(.greeting, speaker: .creature(.redChicken), using: &g)
        #expect(m.currentLine?.speaker == .creature(.redChicken))
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
        #expect(first != second)
    }

    @Test func globalCooldownBlocksIdle() {
        let clock = Clock()
        let m = DialogueManager(lines: sampleLines(), globalCooldown: 10, clock: { clock.now })
        var g = SeededGen(3)
        m.fire(.idle, using: &g)
        let first = m.currentLine?.id
        m.fire(.idle, using: &g)               // 즉시 재호출 → idle 전역 쿨다운으로 무시
        #expect(m.currentLine?.id == first)
    }

    @Test func contextTriggerBypassesGlobalCooldown() {
        let clock = Clock()
        let m = DialogueManager(lines: sampleLines(), globalCooldown: 10, clock: { clock.now })
        var g = SeededGen(5)
        m.fire(.idle, using: &g)
        m.fire(.sessionStart, using: &g)       // 맥락 대사는 쿨다운 무시
        #expect(m.currentLine?.trigger == .sessionStart)
    }

    @Test func noCandidatesLeavesLineUnchanged() {
        let clock = Clock()
        let m = DialogueManager(lines: sampleLines(), clock: { clock.now })
        var g = SeededGen(9)
        m.fire(.idle, using: &g)
        let before = m.currentLine?.id
        m.fire(.focusMilestone(minutes: 30), using: &g)   // 해당 줄 없음 → 변화 없음
        #expect(m.currentLine?.id == before)
    }
}
