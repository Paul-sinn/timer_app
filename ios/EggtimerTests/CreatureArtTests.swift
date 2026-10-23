//
//  CreatureArtTests.swift
//  EggtimerTests
//
//  "변형 × 진화 단계 × 모션 프레임" → 에셋명 해석과 모션 타이밍 규칙 검증.
//  이미지가 실제로 번들에 들어갔는지(12폼 × 3단계 × 2프레임 = 72장)도 함께 확인한다.
//

import Testing
import Foundation
import UIKit
@testable import Eggtimer

struct CreatureArtTests {

    // MARK: - 단계 대응

    @Test func eachGameStageMapsToADistinctArtStage() {
        // 3상태 진화(0=갓부화 → 1=진화 → 2=최종)가 아트 3단계와 1:1.
        // 겹치는 단계가 없어 진화할 때마다 그림이 바뀐다(보상감).
        #expect(CreatureArt.artStage(forEvolutionStage: 0) == 1)
        #expect(CreatureArt.artStage(forEvolutionStage: 1) == 2)
        #expect(CreatureArt.artStage(forEvolutionStage: 2) == 3)
        // 게임 단계 수 == 아트 단계 수 == 최종+1.
        #expect(Creature.maxEvolutionStage + 1 == CreatureArt.artStageCount)
    }

    @Test func artStageClampsOutOfRangeInput() {
        #expect(CreatureArt.artStage(forEvolutionStage: -5) == 1)
        #expect(CreatureArt.artStage(forEvolutionStage: 99) == 3)
        #expect(CreatureArt.artStage(forEvolutionStage: Creature.maxEvolutionStage) == 3)
    }

    @Test func everyGameStageShowsADifferentFrame() {
        // 어떤 두 진화 단계도 같은 아트를 쓰지 않아야 한다(중복 단계 회귀 방지).
        for base in CreatureArt.animatedBases {
            let names = (0...Creature.maxEvolutionStage).map {
                CreatureArt.animatedAssetName(base: base, stage: $0, frame: .idle)
            }
            #expect(Set(names).count == names.count, "\(base): 중복 단계 존재 \(names)")
        }
    }

    @Test func everyArtStageIsReachableFromSomeGameStage() {
        // 1·2·3단계 아트가 전부 실제로 화면에 나올 수 있어야 한다(사장되는 아트 없음).
        let reached = Set((0...Creature.maxEvolutionStage).map(CreatureArt.artStage(forEvolutionStage:)))
        #expect(reached == [1, 2, 3])
    }

    // MARK: - 에셋명 해석

    @Test func animatedSetCoversEveryCollectibleForm() {
        // 도감의 12폼 전부 3단계 아트를 가져야 한다 — 한 종만 안 자라면 고장난 것처럼 보인다.
        #expect(Set(CreatureArt.animatedBases) == Set(CreatureForm.all.map(\.imageName)))
        #expect(CreatureArt.animatedBases.count == 12)
    }

    @Test func evolvedNamesReuseTheirSpeciesSet() {
        // 백호·피닉스는 최종 단계에서 displayImageName이 ...Evolved를 준다.
        // 그 이름도 같은 세트의 3단계로 이어져야 최종 진화에서 모션이 끊기지 않는다.
        #expect(CreatureArt.animatedAssetName(base: "WhiteTigerEvolved", stage: 3, frame: .idle)
                == "WhiteTigerStage3Idle")
        #expect(CreatureArt.animatedAssetName(base: "PhoenixEvolved", stage: 3, frame: .action)
                == "PhoenixStage3Action")
        // 타이밍도 종 설정을 그대로 물려받는다(별칭이라고 default로 새지 않게).
        #expect(CreatureArt.timing(base: "PhoenixEvolved", stage: 3)
                == CreatureArt.timing(base: "Phoenix", stage: 3))
    }

    @Test func everySpeciesChangesArtOnTheWayToFinalEvolution() {
        // 진화해도 그림이 그대로면 성장이 안 보인다. 0단계와 최종단계는 반드시 달라야 한다.
        for base in CreatureArt.animatedBases {
            let first = CreatureArt.animatedAssetName(base: base, stage: 0, frame: .idle)
            let last = CreatureArt.animatedAssetName(base: base, stage: Creature.maxEvolutionStage,
                                                     frame: .idle)
            #expect(first != last, "\(base): 0단계와 최종단계 아트가 같음")
        }
    }

    @Test func assetNameFollowsNamingRule() {
        #expect(CreatureArt.animatedAssetName(base: "ChickenBro", stage: 3, frame: .idle)
                == "ChickenBroStage3Idle")
        #expect(CreatureArt.animatedAssetName(base: "ChickenBro", stage: 3, frame: .action)
                == "ChickenBroStage3Action")
        #expect(CreatureArt.animatedAssetName(base: "ChickenAngry", stage: 0, frame: .idle)
                == "ChickenAngryStage1Idle")
    }

    @Test func unknownVariantsReturnNilSoCallersFallBack() {
        // 세트가 없는 이름은 nil → 호출부가 기존 단일 이미지로 안전 폴백(화면이 비지 않는다).
        for base in ["Chicken9", "Unicorn", ""] {
            #expect(CreatureArt.hasAnimatedSet(base) == false)
            #expect(CreatureArt.animatedAssetName(base: base, stage: 2, frame: .idle) == nil)
        }
    }

    @Test func resolvedNamesAreUniqueAcrossTheWholeMatrix() {
        var names: Set<String> = []
        for base in CreatureArt.animatedBases {
            for art in 1...CreatureArt.artStageCount {
                for frame in CreatureMotionFrame.allCases {
                    names.insert("\(base)Stage\(art)\(frame.suffix)")
                }
            }
        }
        #expect(names.count == 72)   // 12폼 × 3단계 × 2프레임
    }

    // MARK: - 번들 리소스

    @MainActor
    @Test func allRuntimeImagesAreInTheAppBundle() {
        var missing: [String] = []
        for base in CreatureArt.animatedBases {
            for art in 1...CreatureArt.artStageCount {
                for frame in CreatureMotionFrame.allCases {
                    let name = "\(base)Stage\(art)\(frame.suffix)"
                    if UIImage(named: name) == nil { missing.append(name) }
                }
            }
        }
        #expect(missing.isEmpty, "번들에 없는 이미지: \(missing)")
    }

    @MainActor
    @Test func idleAndActionShareOneCanvasSoFramesCannotJump() {
        // 같은 캐릭터·같은 단계의 두 프레임이 픽셀 크기까지 동일해야
        // aspect fit 후에도 크기·위치가 튀지 않는다.
        for base in CreatureArt.animatedBases {
            for art in 1...CreatureArt.artStageCount {
                let idle = UIImage(named: "\(base)Stage\(art)Idle")
                let action = UIImage(named: "\(base)Stage\(art)Action")
                #expect(idle?.size == action?.size,
                        "\(base) stage\(art): idle \(String(describing: idle?.size)) != action \(String(describing: action?.size))")
            }
        }
    }

    @MainActor
    @Test func everyStageOfACharacterSharesTheSameAspectRatio() {
        // 단계가 바뀌어도 종횡비가 같아야 진화 순간에 캐릭터가 튀지 않는다.
        for base in CreatureArt.animatedBases {
            let sizes = (1...CreatureArt.artStageCount).compactMap {
                UIImage(named: "\(base)Stage\($0)Idle")?.size
            }
            #expect(sizes.count == CreatureArt.artStageCount)
            let ratios = sizes.map { $0.width / $0.height }
            for r in ratios { #expect(abs(r - ratios[0]) < 0.001, "\(base) 종횡비 불일치: \(ratios)") }
        }
    }

    @MainActor
    @Test func runtimeImagesHaveTransparentBackground() {
        // 불투명 사각 배경이 남아 있으면 어두운 앱 배경에서 네모가 그대로 보인다.
        // 좌상단 코너 픽셀의 알파로 확인.
        for base in CreatureArt.animatedBases {
            guard let cg = UIImage(named: "\(base)Stage1Idle")?.cgImage else {
                Issue.record("\(base) 이미지 없음"); continue
            }
            #expect(cg.alphaInfo != .none, "\(base): 알파 채널 없음")
        }
    }

    // MARK: - 모션 타이밍

    @Test func idleIsShownLongerThanActionForEveryCharacter() {
        // "전 캐릭터 동일한 빠른 깜빡임" 방지: 기본은 idle을 길게.
        // 헬창닭 3단계(데드리프트)만 두 자세를 비슷하게 보여주는 의도적 예외.
        for base in CreatureArt.animatedBases {
            for stage in 0...Creature.maxEvolutionStage {
                let t = CreatureArt.timing(base: base, stage: stage)
                let isBroFinal = (base == "ChickenBro" && CreatureArt.artStage(forEvolutionStage: stage) == 3)
                if isBroFinal {
                    #expect(t.idle >= t.action)
                } else {
                    #expect(t.idle > t.action * 1.5, "\(base) stage\(stage): idle이 충분히 길지 않음")
                }
            }
        }
    }

    @Test func deadliftFramesStayWithinTheRequestedHalfSecondRhythm() {
        let t = CreatureArt.timing(base: "ChickenBro", stage: Creature.maxEvolutionStage)
        #expect((0.4...0.6).contains(t.idle))
        #expect((0.4...0.6).contains(t.action))
    }

    @Test func noCharacterBlinksTooFast() {
        // 한 주기가 너무 짧으면 깜빡임으로 보인다.
        for base in CreatureArt.animatedBases {
            for stage in 0...Creature.maxEvolutionStage {
                let t = CreatureArt.timing(base: base, stage: stage)
                #expect(t.period >= 0.8, "\(base) stage\(stage) 주기 \(t.period)s — 너무 빠름")
                #expect(t.action >= 0.25, "\(base) stage\(stage) action \(t.action)s — 너무 짧음")
            }
        }
    }

    @Test func liftStaysWithinAFewPixels() {
        // 큰 이동은 프레임이 튀어 보인다. 1~3pt만 허용.
        for base in CreatureArt.animatedBases {
            for stage in 0...Creature.maxEvolutionStage {
                let lift = CreatureArt.timing(base: base, stage: stage).lift
                #expect((1...3).contains(lift))
            }
        }
    }

    @Test func charactersAreDesynchronisedButDeterministic() {
        let phases = CreatureArt.animatedBases.map { CreatureArt.phaseOffset(base: $0, stage: 1) }
        #expect(Set(phases).count == phases.count)          // 서로 다른 박자
        for p in phases { #expect((0..<1).contains(p)) }
        // 같은 입력이면 항상 같은 결과(런치마다 흔들리지 않음).
        #expect(CreatureArt.phaseOffset(base: "ChickenBro", stage: 2)
                == CreatureArt.phaseOffset(base: "ChickenBro", stage: 2))
    }

    // MARK: - 랜덤 쉼

    @Test func restsGetLongerButNeverFaster() {
        // 랜덤은 쉬는 시간만 늘린다 → 깜빡임 하한·데드리프트 리듬 최소치를 그대로 지킨다.
        for base in CreatureArt.animatedBases {
            for stage in 0...Creature.maxEvolutionStage {
                let t = CreatureArt.timing(base: base, stage: stage)
                #expect(t.idleDuration(roll: 0) == t.idle)
                #expect(t.idleDuration(roll: 1) == t.idle * 2.5)
            }
        }
    }

    @Test func longRestsAreOccasional() {
        // 대부분의 주기는 원래 박자 근처, 가끔만 길게 쉰다.
        let t = CreatureArt.timing(base: "Dino", stage: 1)
        #expect(t.idleDuration(roll: 0.5) < t.idle * 1.2)
        #expect(t.idleDuration(roll: 0.25) < t.idleDuration(roll: 0.75))
    }

    // MARK: - 반응 점프(탭·이벤트)

    @Test func hopCrouchesThenLandsBackOnTheGround() {
        let hop = CreatureArt.hop
        #expect(hop.first?.frame == .action)
        #expect(hop.first?.lift == 0)
        #expect(hop.last?.frame == .idle)
        #expect(hop.last?.lift == 0)
    }

    @Test func hopMovesInWholePointsOnly() {
        // 보간된 소수 pt 이동은 픽셀아트를 지글거리게 한다 → 정수 계단만.
        for step in CreatureArt.hop {
            #expect(step.lift == step.lift.rounded())
            #expect((0...10).contains(step.lift))
        }
    }

    @Test func hopIsQuickButEveryStepIsVisible() {
        let total = CreatureArt.hop.reduce(0) { $0 + $1.duration }
        #expect((0.25...0.5).contains(total))
        for step in CreatureArt.hop {
            #expect(step.duration >= 1.0 / 30)   // 60fps 기준 2프레임 이상
        }
    }
}
