//
//  WorldTests.swift
//  EggtimerTests
//
//  월드(팩)별 캐릭터 구성·확률·추첨 규칙 검증. 기획: docs/CREATURES.md §2·§3.
//  - 기본 월드: 기존 결과와 **완전히 같아야** 한다(같은 시드 = 같은 결과).
//  - 크리스마스 월드: 48·30·16·6 + 새 캐릭터 우선 + 같은 캐릭터 최대 3번 → 28번 안에 완성 보장.
//

import Testing
import Foundation
@testable import Eggtimer

/// 결정적 테스트를 위한 시드 가능한 RNG(SplitMix64). CreatureSpeciesTests와 같은 구현.
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

struct WorldTests {

    /// 모든 칸을 n개씩 가진 상태.
    private func counts(_ world: World, each n: Int) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: world.forms.map { ($0.imageName, n) })
    }

    // MARK: - 구성

    @Test func everySpeciesBelongsToExactlyOneWorld() {
        let listed = World.allCases.flatMap(\.species)
        #expect(listed.count == CreatureSpecies.allCases.count)
        #expect(Set(listed) == Set(CreatureSpecies.allCases))
    }

    @Test func classicWorldIsTheOriginalSeven() {
        #expect(World.classic.species.map(\.rawValue)
                == ["chicken", "slime", "dino", "blackCat", "goldChick", "whiteTiger", "phoenix"])
        #expect(World.classic.forms.count == 12)   // 닭 6표정 + 6종
    }

    @Test func christmasLineupMatchesSpec() {
        let w = World.christmas
        #expect(w.species.count == 10)
        #expect(w.forms.count == 10)               // 1종 = 1칸
        let byTier = Dictionary(grouping: w.species, by: \.rarity).mapValues(\.count)
        #expect(byTier[.common] == 4)
        #expect(byTier[.uncommon] == 3)
        #expect(byTier[.rare] == 2)
        #expect(byTier[.legendary] == 1)
        #expect(w.species.filter { $0.rarity == .legendary } == [.polarBear])   // 간판
    }

    /// DB(`speciesRaw`)·Supabase에 저장되는 값. 한 번 출시되면 바꾸면 기존 유저 데이터가 사라진다.
    @Test func christmasRawValuesAreFrozen() {
        #expect(World.christmas.species.map(\.rawValue) == [
            "redNosePenguin", "santaPenguin", "elfPenguin", "giftBoxPenguin",
            "snowmanSlime", "littleEmber", "arcticFox",
            "gingerbreadChick", "snowyOwl",
            "polarBear",
        ])
    }

    @Test func everyChristmasSpeciesHasItsOwnPersonality() {
        // 전용 성격 없는 칸을 만들지 않는다(§2-2). generic 폴백 금지 + 서로 겹치지 않음.
        let ps = World.christmas.forms.map { $0.species.personality(imageName: $0.imageName) }
        #expect(!ps.contains(.generic))
        #expect(Set(ps).count == ps.count)
    }

    @Test func tierWeightsSumTo100InEveryWorld() {
        for w in World.allCases {
            #expect(Rarity.allCases.reduce(0) { $0 + w.tierWeight($1) } == 100, "\(w)")
        }
        for r in Rarity.allCases {
            #expect(World.classic.tierWeight(r) == r.tierWeight)   // 기본 월드는 기존 표 그대로
        }
        #expect(Rarity.allCases.map(World.christmas.tierWeight) == [48, 30, 16, 6])
    }

    @Test func christmasPerFormRateFallsAsRarityRises() {
        // 등급 안 균등 → 1마리당 12 · 10 · 8 · 6%
        let expected: [Rarity: Double] = [.common: 12, .uncommon: 10, .rare: 8, .legendary: 6]
        for r in Rarity.allCases {
            #expect(World.christmas.singleDrawRate(of: r) == expected[r], "\(r)")
        }
    }

    @Test func onlyPaidWorldsHaveProductIDs() {
        #expect(World.classic.productID == nil)
        #expect(World.christmas.productID == "com.paulsin.hatchly.world.christmas")
    }

    @Test func completionGuaranteeDerivesFromCap() {
        // 천장 3 × (10 − 1) + 1 = 28 — 구매 화면 문구가 이 값을 쓴다.
        #expect(World.christmas.guaranteedCompletionHatches == 28)
        #expect(World.classic.guaranteedCompletionHatches == nil)
    }

    // MARK: - 기본 월드는 그대로

    /// 새 추첨 경로가 기존 부화(`Creature.hatch`)와 난수까지 똑같이 소비하는지.
    /// 이게 통과하면 기본 월드 유저는 업데이트 전후 차이를 겪지 않는다.
    @Test func classicFormRollMatchesLegacyHatchExactly() {
        for draws in 1...4 {
            var a = SeededGenerator(seed: 0x5EED &+ UInt64(draws))
            var b = SeededGenerator(seed: 0x5EED &+ UInt64(draws))
            for _ in 0..<3000 {
                let legacy = Creature.hatch(draws: draws, using: &a)
                let form = CreatureSpecies.rollForm(in: .classic, draws: draws, using: &b)
                #expect(legacy.species == form.species && legacy.imageName == form.imageName)
            }
        }
    }

    @Test func worldsNeverLeakIntoEachOther() {
        var gen = SeededGenerator(seed: 0xB0B)
        for world in World.allCases {
            for draws in 1...4 {
                for _ in 0..<5000 {
                    let form = CreatureSpecies.rollForm(in: world, draws: draws, using: &gen)
                    #expect(form.species.world == world)
                }
            }
        }
    }

    // MARK: - 크리스마스 규칙

    @Test func christmasSingleDrawMatchesTierWeights() {
        // 도감 완성(천장 해제) + 1번 뽑기 → 순수 확률표대로 나와야 한다.
        let owned = counts(.christmas, each: 1)
        var gen = SeededGenerator(seed: 0xC4)
        let n = 200_000
        var hits: [String: Int] = [:]
        for _ in 0..<n {
            hits[CreatureSpecies.rollForm(in: .christmas, draws: 1, counts: owned, using: &gen).imageName, default: 0] += 1
        }
        for form in World.christmas.forms {
            let observed = Double(hits[form.imageName] ?? 0) / Double(n) * 100
            let expected = World.christmas.singleDrawRate(of: form.rarity)
            #expect(abs(observed - expected) <= 1.0, "\(form.imageName): 기대 \(expected)% / 관측 \(observed)%")
        }
    }

    /// 기본 규칙(가장 높은 등급 채택)을 그대로 쓰면 오래 집중할수록 흔함이 더 안 나오는 역전이 생긴다.
    /// 새 캐릭터 우선이면: 빨간코 펭귄만 없을 때 3번 중 하나라도 나오면 그걸 준다 → 1 − 0.88³ ≈ 31.9%.
    /// (역전된 규칙이었다면 0.48³ × ¼ ≈ 2.8%)
    @Test func undiscoveredFirstRemovesTheInversion() {
        var owned = counts(.christmas, each: 1)
        owned["RedNosePenguin"] = 0
        var gen = SeededGenerator(seed: 0x1A)
        let n = 200_000
        var hit = 0
        for _ in 0..<n where CreatureSpecies.rollForm(in: .christmas, draws: 3, counts: owned, using: &gen).imageName == "RedNosePenguin" {
            hit += 1
        }
        let rate = Double(hit) / Double(n) * 100
        #expect(abs(rate - 31.85) <= 1.0, "관측 \(rate)%")
    }

    @Test func capBlocksFourthCopyWhileIncomplete() {
        var owned = counts(.christmas, each: 0)
        owned["RedNosePenguin"] = 3
        var gen = SeededGenerator(seed: 0xCA9)
        for draws in 1...4 {
            for _ in 0..<20_000 {
                let form = CreatureSpecies.rollForm(in: .christmas, draws: draws, counts: owned, using: &gen)
                #expect(form.imageName != "RedNosePenguin")
            }
        }
    }

    @Test func capLiftsOnceComplete() {
        let owned = counts(.christmas, each: 3)
        var gen = SeededGenerator(seed: 0x11F7)
        let n = 100_000
        var hit = 0
        for _ in 0..<n where CreatureSpecies.rollForm(in: .christmas, draws: 1, counts: owned, using: &gen).imageName == "RedNosePenguin" {
            hit += 1
        }
        #expect(abs(Double(hit) / Double(n) * 100 - 12) <= 1.0)
    }

    /// 운이 가장 나쁜 유저도 28번 안에 완성해야 한다(§3-2). 평균은 시뮬레이션 표(§3-3)와 맞아야 한다.
    @Test func everyoneCompletesWithinGuarantee() {
        let limit = World.christmas.guaranteedCompletionHatches ?? 0
        // 같은 규칙을 파이썬으로 2만 회 돌린 값(2026-11-07). CREATURES.md §3-3의 25분 22.4는 23.0으로 정정.
        let expectedMean: [Int: Double] = [1: 23.0, 2: 17.4, 3: 14.3, 4: 12.7]
        for draws in 1...4 {
            var gen = SeededGenerator(seed: 0xD00D &+ UInt64(draws))
            let runs = 2000
            var total = 0
            for _ in 0..<runs {
                var owned: [String: Int] = [:]
                var hatches = 0
                while owned.count < World.christmas.forms.count && hatches <= limit {
                    let form = CreatureSpecies.rollForm(in: .christmas, draws: draws, counts: owned, using: &gen)
                    owned[form.imageName, default: 0] += 1
                    hatches += 1
                }
                #expect(hatches <= limit, "draws=\(draws): \(hatches)번")
                total += hatches
            }
            let mean = Double(total) / Double(runs)
            #expect(abs(mean - (expectedMean[draws] ?? 0)) <= 1.0, "draws=\(draws) 평균 \(mean)")
        }
    }

    @Test func drawsClampedToAtLeastOne() {
        var gen = SeededGenerator(seed: 5)
        let form = CreatureSpecies.rollForm(in: .christmas, draws: 0, using: &gen)
        #expect(form.species.world == .christmas)
    }

    @Test func savedSelectionFallsBackToClassic() {
        #expect(World.resolved("christmas", owns: { _ in true }) == .christmas)
        #expect(World.resolved("christmas", owns: { $0 == .classic }) == .classic)   // 미구매·환불
        #expect(World.resolved("not-a-world", owns: { _ in true }) == .classic)
    }

    @Test func artPlaceholdersOnlyForChristmas() {
        // 자리표시는 그림 대기 중인 크리스마스 종에만. 기본 월드는 그림이 이미 있다.
        for species in CreatureSpecies.allCases {
            #expect((species.artPlaceholder != nil) == (species.world == .christmas), "\(species)")
        }
        #expect(CreatureSpecies.species(forImageName: "PolarBear") == .polarBear)
        #expect(CreatureSpecies.species(forImageName: "ChickenBro") == .chicken)
    }

    // MARK: - 보유 칸 수 (부화 입력)

    @Test func storeCountsFormsForTheRoll() {
        let store = CollectionStore(creatures: [
            Creature(species: .chicken, imageName: "ChickenSleepy", hatchedAt: .now),
            Creature(species: .chicken, imageName: "ChickenSleepy", hatchedAt: .now),
            Creature(species: .polarBear, hatchedAt: .now),
        ])
        #expect(store.formCounts == ["ChickenSleepy": 2, "PolarBear": 1])
    }

    @Test func storeHatchUsesTheGivenWorld() {
        let store = CollectionStore(creatures: [])
        for _ in 0..<50 {
            #expect(store.hatch(in: .christmas).species.world == .christmas)
        }
        #expect(store.creatures.count == 50)
    }

    // MARK: - 부화 그릇(알 / 선물상자)

    @Test func classicVesselIsTheEggCrackSequenceUnchanged() {
        #expect(World.classic.vesselStageAssets == [
            "fullegg", "firstcrack_egg", "secondcrack_egg",
            "thirdcrack_egg", "fourthcrack_egg", "abouttocrack_egg",
        ])
    }

    @Test func christmasVesselIsSixGiftBoxStages() {
        let names = World.christmas.vesselStageAssets
        #expect(names == (1...6).map { "giftbox_stage\($0)" })
    }

    @Test func everyVesselHasOneImagePerProgressStage() {
        for world in World.allCases {
            #expect(world.vesselStageAssets.count == EggState.visualStages)
            #expect(Set(world.vesselStageAssets).count == EggState.visualStages)
        }
    }

    @Test func vesselFallsBackToEggWhenItsArtIsMissing() {
        // 그림이 아직 번들에 없으면 알을 보여준다(빈 화면 방지).
        #expect(World.christmas.vesselAsset(stage: 2, exists: { _ in false }) == "secondcrack_egg")
        #expect(World.christmas.vesselAsset(stage: 2, exists: { _ in true }) == "giftbox_stage3")
        // 범위 밖 단계는 양 끝으로 고정.
        #expect(World.christmas.vesselAsset(stage: -1, exists: { _ in true }) == "giftbox_stage1")
        #expect(World.christmas.vesselAsset(stage: 99, exists: { _ in true }) == "giftbox_stage6")
    }
}
