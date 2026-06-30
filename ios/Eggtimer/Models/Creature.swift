//
//  Creature.swift
//  Eggtimer
//
//  부화한 생명체 인스턴스. 순수 Swift 값 타입(struct). SwiftData 미사용(Phase 0).
//  종(CreatureSpecies)에서 이름·등급을 파생하고, 부화 시점에 확정된 이미지 변형을 보관한다.
//  모든 종은 부화(0단계) 후 "이어서 집중" 1세션 완료마다 한 단계씩 진화하고,
//  maxEvolutionStage에 도달하면 최종 진화한다. 전용 진화 아트(백호·피닉스)는 최종 단계에서
//  이미지가 바뀌고, 그 외 종은 같은 아트 + 글로우·배지 연출로 단계를 표현한다.
//

import Foundation

struct Creature: Identifiable, Hashable {
    let id: UUID
    /// 종(이름·등급·이미지 풀의 출처).
    let species: CreatureSpecies
    /// 부화 시점에 확정된 기본 이미지 변형(빨간 토종닭은 표정 랜덤 고정).
    let imageName: String
    let hatchedAt: Date

    /// 최종 진화까지의 진화 횟수. 부화(0단계) 후 이만큼 진화하면 최종 진화.
    static let maxEvolutionStage = 3

    init(
        id: UUID = UUID(),
        species: CreatureSpecies,
        imageName: String? = nil,
        hatchedAt: Date
    ) {
        self.id = id
        self.species = species
        if let imageName {
            self.imageName = imageName
        } else {
            var generator = SystemRandomNumberGenerator()
            self.imageName = species.randomVariant(using: &generator)
        }
        self.hatchedAt = hatchedAt
    }

    var name: String { species.name }
    var rarity: Rarity { species.rarity }
    /// 대사 성격(종 + 부화 시 확정 이미지 변형에서 파생).
    var personality: CreaturePersonality { species.personality(imageName: imageName) }

    /// 전용 최종 진화 아트를 가진 종인지(현재 백호·피닉스만). 그 외 종은 같은 아트 + 연출/배지로 단계 표현.
    var hasFinalArt: Bool { species.evolvedImageName != nil }

    /// 진화 단계(0=갓 부화 … maxEvolutionStage=최종). 부화 후 완료한 집중 세션 수로 파생.
    func evolutionStage(completedSessionsSinceHatch n: Int) -> Int {
        max(0, min(n, Creature.maxEvolutionStage))
    }

    /// 최종 진화 도달 여부.
    func isFinalEvolved(stage: Int) -> Bool { stage >= Creature.maxEvolutionStage }

    /// 화면에 그릴 이미지 에셋명. 최종 단계 + 전용 진화 아트 보유 종이면 진화 이미지,
    /// 그 외엔 기본 이미지(단계는 글로우·배지 연출로 표현).
    func displayImageName(stage: Int) -> String {
        if isFinalEvolved(stage: stage), let evolved = species.evolvedImageName { return evolved }
        return imageName
    }

    // MARK: - 부화

    /// 확률표에 따라 한 종을 뽑아 새 생명체를 부화시킨다.
    static func hatch(at date: Date = Date()) -> Creature {
        var generator = SystemRandomNumberGenerator()
        return hatch(at: date, using: &generator)
    }

    /// 테스트 가능한 주입형 RNG 부화.
    static func hatch<G: RandomNumberGenerator>(at date: Date = Date(), using generator: inout G) -> Creature {
        let species = CreatureSpecies.roll(using: &generator)
        let image = species.randomVariant(using: &generator)
        return Creature(species: species, imageName: image, hatchedAt: date)
    }
}
