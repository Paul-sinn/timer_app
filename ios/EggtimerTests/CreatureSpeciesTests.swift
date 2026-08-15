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

    // MARK: - best-of-N (집중 길이 보상)

    /// draws=1은 기존 단일 추첨과 완전히 동일해야 한다(하위호환 · 등급/종 weight 불변).
    @Test func singleDrawMatchesLegacyRoll() {
        var a = SeededGenerator(seed: 7)
        var b = SeededGenerator(seed: 7)
        for _ in 0..<2000 {
            #expect(CreatureSpecies.roll(using: &a) == CreatureSpecies.roll(draws: 1, using: &b))
        }
    }

    /// draw가 늘수록 전설 확률이 keep-best 공식(1 - 0.98^N)대로 단조 증가한다.
    @Test func moreDrawsRaiseLegendaryOdds() {
        func legendaryRate(draws: Int, seed: UInt64) -> Double {
            var gen = SeededGenerator(seed: seed)
            let n = 200_000
            var legend = 0
            for _ in 0..<n where CreatureSpecies.roll(draws: draws, using: &gen).rarity == .legendary {
                legend += 1
            }
            return Double(legend) / Double(n) * 100
        }
        let r1 = legendaryRate(draws: 1, seed: 0xA1)
        let r2 = legendaryRate(draws: 2, seed: 0xB2)
        let r3 = legendaryRate(draws: 3, seed: 0xC3)
        #expect(abs(r1 - 2.00) <= 0.5)   // 1 - 0.98
        #expect(abs(r2 - 3.96) <= 0.5)   // 1 - 0.98^2
        #expect(abs(r3 - 5.88) <= 0.6)   // 1 - 0.98^3
        #expect(r1 < r2 && r2 < r3)      // 단조 증가
    }

    // MARK: - "닭이 잘 안 나온다" 체감 검증 (2026-08-15)

    /// 닭 6표정이 균등하게 나오는지. **여기가 치우쳐 있으면 특정 표정만 안 나와서
    /// "닭이 잘 안 나온다"로 느껴진다** — rollDistributionMatchesWeights는 종 단위라 이걸 못 잡는다.
    @Test func chickenVariantsAreUniform() {
        var gen = SeededGenerator(seed: 0xFEED)
        let n = 200_000
        var counts: [String: Int] = [:]
        for _ in 0..<n {
            counts[CreatureSpecies.chicken.randomVariant(using: &gen), default: 0] += 1
        }
        let variants = CreatureSpecies.chicken.imageVariants
        // 6표정이 전부 등장해야 한다(하나라도 빠지면 도감을 못 채운다).
        #expect(counts.count == variants.count)

        let expected = 100.0 / Double(variants.count)   // 16.67%
        for variant in variants {
            let observed = Double(counts[variant] ?? 0) / Double(n) * 100
            #expect(abs(observed - expected) <= 1.0,
                    "\(variant): 기대 \(expected)% / 관측 \(observed)%")
        }
    }

    /// 유저가 실제로 세는 단위는 **종이 아니라 폼**이다(닭은 6이름으로 따로 수집).
    /// 닭 종 합계는 55%지만 표정 하나당 9.17%라 슬라임(25%) 하나에 밀린다 — 이게 체감의 정체.
    /// 밸런스를 바꾸면 이 테스트가 깨지므로, 바꿨다는 사실이 자동으로 드러난다.
    @Test func perFormRatesExplainThePerception() {
        let chickenTotal = effectiveProbability(.chicken)
        let perFace = chickenTotal / Double(CreatureSpecies.chicken.imageVariants.count)
        let slime = effectiveProbability(.slime)

        #expect(abs(chickenTotal - 55.0) < 0.01)
        #expect(abs(perFace - 9.1667) < 0.01)
        #expect(abs(slime - 25.0) < 0.01)
        // 종 합계로는 닭이 1등인데, 폼 단위로는 슬라임 하나가 닭 표정 하나를 이긴다.
        #expect(chickenTotal > slime)
        #expect(slime > perFace)
    }

    /// draws 2·3·4의 **종별** 분포. 기존 moreDrawsRaiseLegendaryOdds는 전설 비율만 봐서
    /// "긴 집중에서 공룡이 1등이 된다" 같은 종 단위 쏠림을 못 잡는다.
    @Test func speciesDistributionHoldsAcrossDraws() {
        /// best-of-N 등급 확률: P(최고=X) = P(≤X)^N − P(<X)^N.
        func tierProbability(_ rarity: Rarity, draws: Int) -> Double {
            var below = 0.0, upTo = 0.0
            for r in Rarity.allCases {
                if r < rarity { below += Double(r.tierWeight) }
                if !(rarity < r) { upTo += Double(r.tierWeight) }
            }
            let n = Double(draws)
            return (pow(upTo / 100, n) - pow(below / 100, n)) * 100
        }
        /// 등급 확률 × 등급 내 상대가중.
        func expectedRate(_ species: CreatureSpecies, draws: Int) -> Double {
            let tierSum = CreatureSpecies.allCases
                .filter { $0.rarity == species.rarity }
                .reduce(0) { $0 + $1.weight }
            return tierProbability(species.rarity, draws: draws)
                * Double(species.weight) / Double(tierSum)
        }

        for draws in 2...4 {
            var gen = SeededGenerator(seed: 0xD0E0 &+ UInt64(draws))
            let n = 200_000
            var counts: [CreatureSpecies: Int] = [:]
            for _ in 0..<n {
                counts[CreatureSpecies.roll(draws: draws, using: &gen), default: 0] += 1
            }
            for species in CreatureSpecies.allCases {
                let observed = Double(counts[species] ?? 0) / Double(n) * 100
                let expected = expectedRate(species, draws: draws)
                let tolerance = expected >= 5 ? 2.0 : 0.5
                #expect(abs(observed - expected) <= tolerance,
                        "draws=\(draws) \(species.name): 기대 \(expected)% / 관측 \(observed)%")
            }
        }
    }

    /// draws가 0/음수여도 최소 1회는 굴려 유효한 종을 낸다(방어).
    @Test func drawsClampedToAtLeastOne() {
        var gen = SeededGenerator(seed: 99)
        let s = CreatureSpecies.roll(draws: 0, using: &gen)
        #expect(CreatureSpecies.allCases.contains(s))
    }
}
