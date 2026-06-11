//
//  DialogueCatalogTests.swift
//  EggtimerTests
//
//  대사 카탈로그 커버리지 + 성격 매핑 검증(dialoguesystem.md 스펙 충족).
//

import Testing
import Foundation
@testable import Eggtimer

struct DialogueCatalogTests {

    private func eggLines(_ trigger: DialogueTrigger) -> [DialogueLine] {
        DialogueCatalog.all.filter { $0.speaker == .egg && $0.trigger == trigger }
    }

    @Test func everyEggMilestonePresent() {
        for m in [5, 10, 15, 30, 45, 60] {
            #expect(!eggLines(.focusMilestone(minutes: m)).isEmpty, "마일스톤 \(m)분 풀 비어있음")
        }
    }

    @Test func everyReturnBucketPresent() {
        for b in ReturnBucket.allCases {
            #expect(!eggLines(.appReturn(b)).isEmpty, "복귀 버킷 \(b) 풀 비어있음")
        }
    }

    @Test func everyStreakTierPresent() {
        for d in [3, 7, 30, 100] {
            #expect(!eggLines(.streak(days: d)).isEmpty, "스트릭 \(d)일 풀 비어있음")
        }
    }

    @Test func sessionStartAndIdlePresent() {
        #expect(!eggLines(.sessionStart).isEmpty)
        #expect(!eggLines(.idle).isEmpty)
    }

    @Test func everyPersonalityHasGreetingLines() {
        for p in CreaturePersonality.allCases {
            let lines = DialogueCatalog.all.filter { $0.speaker == .creature(p) && $0.trigger == .greeting }
            #expect(!lines.isEmpty, "성격 \(p.rawValue) 대사 풀 비어있음")
        }
    }

    @Test func containsExactSpecLines() {
        let texts = Set(DialogueCatalog.all.map(\.text))
        // 알 — 스펙 정확 라인 표본
        #expect(texts.contains("Let's see how long this lasts."))
        #expect(texts.contains("I'm mildly impressed."))
        #expect(texts.contains("Fine. That was legendary."))
        #expect(texts.contains("You're on thin ice."))
        #expect(texts.contains("Legends start like this."))
        // 생명체 — 성격별 표본
        #expect(texts.contains("Keep going, nerd."))            // red
        #expect(texts.contains("Wake me up when we hatch."))    // sleepy
        #expect(texts.contains("Statistically speaking, this is impressive.")) // nerd
        #expect(texts.contains("Mental gains."))                // gym
        #expect(texts.contains("Stop touching your phone."))    // angry
        #expect(texts.contains("Strength grows in silence."))   // tiger
        #expect(texts.contains("Even ashes remember greatness.")) // phoenix
    }

    @Test func uniqueLineIDs() {
        let ids = DialogueCatalog.all.map(\.id)
        #expect(ids.count == Set(ids).count, "중복 id 존재")
    }

    // MARK: - 성격 매핑

    @Test func chickenVariantsMapToPersonalities() {
        #expect(CreatureSpecies.chicken.personality(imageName: "Chicken1") == .redChicken)
        #expect(CreatureSpecies.chicken.personality(imageName: "ChickenAnnoyed") == .redChicken)
        #expect(CreatureSpecies.chicken.personality(imageName: "ChickenSleepy") == .sleepyChicken)
        #expect(CreatureSpecies.chicken.personality(imageName: "ChickenSmart") == .nerdChicken)
        #expect(CreatureSpecies.chicken.personality(imageName: "ChickenBro") == .gymChicken)
        #expect(CreatureSpecies.chicken.personality(imageName: "ChickenAngry") == .angryChicken)
    }

    @Test func legendaryAndGenericMapping() {
        #expect(CreatureSpecies.whiteTiger.personality(imageName: "WhiteTiger") == .whiteTiger)
        #expect(CreatureSpecies.phoenix.personality(imageName: "Phoenix") == .phoenix)
        for s in [CreatureSpecies.slime, .dino, .blackCat, .goldChick] {
            #expect(s.personality(imageName: s.silhouetteImageName) == .generic)
        }
    }

    @Test func returnBucketBoundaries() {
        #expect(ReturnBucket.from(awaySeconds: 0) == .within30s)
        #expect(ReturnBucket.from(awaySeconds: 29) == .within30s)
        #expect(ReturnBucket.from(awaySeconds: 30) == .upTo3min)
        #expect(ReturnBucket.from(awaySeconds: 179) == .upTo3min)
        #expect(ReturnBucket.from(awaySeconds: 180) == .upTo10min)
        #expect(ReturnBucket.from(awaySeconds: 599) == .upTo10min)
        #expect(ReturnBucket.from(awaySeconds: 600) == .over10min)
    }
}
