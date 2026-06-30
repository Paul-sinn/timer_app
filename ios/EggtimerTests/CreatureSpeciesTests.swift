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

    @Test func rarityTierWeightsSumTo100() {
        // 등급 확률 합은 항상 100(불변). 종 weight는 등급 내 상대값이라 합100일 필요 없음.
        let total = Rarity.allCases.reduce(0) { $0 + $1.tierWeight }
        #expect(total == 100)
    }

    /// 종의 실제 출현 확률(%) = 등급% × (종 weight / 같은 등급 weight 합).
    private func effectiveProbability(_ species: CreatureSpecies) -> Double {
        let tierSum = CreatureSpecies.allCases
            .filter { $0.rarity == species.rarity }
            .reduce(0) { $0 + $1.weight }
        return Double(species.rarity.tierWeight) * Double(species.weight) / Double(tierSum)
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

    @Test func dexEnumeratesEachImageVariantAsForm() {
        let forms = CreatureForm.all
        // 닭 6표정 + 나머지 6종 1개씩 = 12폼.
        #expect(forms.count == 12)
        // 닭 변형은 서로 다른 이름으로 따로 수집된다.
        let chickenNames = Set(forms.filter { $0.species == .chicken }.map(\.name))
        #expect(chickenNames.count == 6)
        // 폼 id(imageName)는 고유.
        #expect(Set(forms.map(\.id)).count == forms.count)
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
            let expected = effectiveProbability(species)
            // 흔한 종은 ±2%, 희귀종은 절대 오차 ±0.5% 이내.
            let tolerance = expected >= 5 ? 2.0 : 0.5
            #expect(abs(observed - expected) <= tolerance,
                    "\(species.name): 기대 \(expected)% / 관측 \(observed)%")
        }
    }

    @Test func evolutionStagesByCompletedSessions() {
        let tiger = Creature(species: .whiteTiger, hatchedAt: .now)
        // 완료 세션 수 → 단계(0…max, 캡).
        #expect(tiger.evolutionStage(completedSessionsSinceHatch: 0) == 0)
        #expect(tiger.evolutionStage(completedSessionsSinceHatch: 2) == 2)
        #expect(tiger.evolutionStage(completedSessionsSinceHatch: 99) == Creature.maxEvolutionStage)

        // 최종 단계 판정.
        #expect(tiger.isFinalEvolved(stage: Creature.maxEvolutionStage - 1) == false)
        #expect(tiger.isFinalEvolved(stage: Creature.maxEvolutionStage) == true)
    }

    @Test func finalArtSpeciesUseEvolvedImageAtFinalStage() {
        let tiger = Creature(species: .whiteTiger, hatchedAt: .now)
        // 전용 진화 아트 보유 종은 최종 단계에서 진화 이미지로 교체.
        #expect(tiger.displayImageName(stage: Creature.maxEvolutionStage - 1) == tiger.imageName)
        #expect(tiger.displayImageName(stage: Creature.maxEvolutionStage) == "WhiteTigerEvolved")

        // 전용 아트 없는 종은 최종 단계여도 기본 이미지 유지(단계는 연출/배지로 표현).
        let chicken = Creature(species: .chicken, hatchedAt: .now)
        #expect(chicken.hasFinalArt == false)
        #expect(chicken.displayImageName(stage: Creature.maxEvolutionStage) == chicken.imageName)
    }

    @Test func hatchProducesValidCreature() {
        var gen = SeededGenerator(seed: 42)
        let creature = Creature.hatch(using: &gen)
        #expect(creature.species.imageVariants.contains(creature.imageName))
    }
}
