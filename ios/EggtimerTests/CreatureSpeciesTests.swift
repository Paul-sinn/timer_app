//
//  CreatureSpeciesTests.swift
//  EggtimerTests
//
//  확률표(가중치) 추첨·진화 로직 검증.
//

import Testing
import Foundation
@testable import Eggtimer

/// 결정적 테스트를 위한 시드 가능한 RNG(SplitMix64).
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

struct CreatureSpeciesTests {

    @Test func weightsSumTo100() {
        let total = CreatureSpecies.allCases.reduce(0) { $0 + $1.weight }
        #expect(total == 100)
    }

    @Test func everySpeciesHasImageAndName() {
        for species in CreatureSpecies.allCases {
            #expect(!species.name.isEmpty)
            #expect(!species.imageVariants.isEmpty)
            #expect(species.weight > 0)
        }
    }

    @Test func chickenHasMultipleRandomVariants() {
        #expect(CreatureSpecies.chicken.imageVariants.count > 1)
        // 다른 종은 단일 이미지.
        #expect(CreatureSpecies.slime.imageVariants.count == 1)
    }

    @Test func onlyLegendariesEvolve() {
        for species in CreatureSpecies.allCases {
            let evolves = species.evolvedImageName != nil
            #expect(evolves == (species.rarity == .legendary))
        }
    }

    /// 시드 RNG로 대량 추첨해 분포가 가중치에 수렴하는지 확인.
    @Test func rollDistributionMatchesWeights() {
        var gen = SeededGenerator(seed: 0xC0FFEE)
        let n = 200_000
        var counts: [CreatureSpecies: Int] = [:]
        for _ in 0..<n {
            counts[CreatureSpecies.roll(using: &gen), default: 0] += 1
        }
        // 모든 종이 최소 한 번은 등장.
        #expect(counts.count == CreatureSpecies.allCases.count)
        for species in CreatureSpecies.allCases {
            let observed = Double(counts[species] ?? 0) / Double(n) * 100
            // 흔한 종은 ±2%, 희귀종은 절대 오차 ±0.5% 이내.
            let tolerance = species.weight >= 5 ? 2.0 : 0.5
            #expect(abs(observed - Double(species.weight)) <= tolerance,
                    "\(species.name): 기대 \(species.weight)% / 관측 \(observed)%")
        }
    }

    @Test func evolutionTriggersAfter20Minutes() {
        let justNow = Creature(species: .whiteTiger, hatchedAt: .now)
        #expect(justNow.isEvolved == false)
        #expect(justNow.displayImageName == justNow.imageName)

        let old = Creature(species: .whiteTiger, hatchedAt: Date().addingTimeInterval(-21 * 60))
        #expect(old.isEvolved == true)
        #expect(old.displayImageName == "WhiteTigerEvolved")

        // 진화하지 않는 종은 시간이 지나도 그대로.
        let oldChicken = Creature(species: .chicken, hatchedAt: Date().addingTimeInterval(-60 * 60))
        #expect(oldChicken.isEvolved == false)
    }

    @Test func hatchProducesValidCreature() {
        var gen = SeededGenerator(seed: 42)
        let creature = Creature.hatch(using: &gen)
        #expect(creature.species.imageVariants.contains(creature.imageName))
    }
}
