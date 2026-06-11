//
//  Creature.swift
//  Eggtimer
//
//  부화한 생명체 인스턴스. 순수 Swift 값 타입(struct). SwiftData 미사용(Phase 0).
//  종(CreatureSpecies)에서 이름·등급을 파생하고, 부화 시점에 확정된 이미지 변형을 보관한다.
//  진화 종(백호·피닉스)은 부화 후 evolveAfter 경과 시 진화 이미지로 바뀐다.
//

import Foundation

struct Creature: Identifiable, Hashable {
    let id: UUID
    /// 종(이름·등급·이미지 풀의 출처).
    let species: CreatureSpecies
    /// 부화 시점에 확정된 기본 이미지 변형(빨간 토종닭은 표정 랜덤 고정).
    let imageName: String
    let hatchedAt: Date

    /// 진화까지 필요한 시간(초). 20분.
    static let evolveAfter: TimeInterval = 20 * 60

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

    /// 진화 가능한 종인지(진화 이미지 보유 여부).
    var canEvolve: Bool { species.evolvedImageName != nil }

    /// 현재 진화 상태인지(부화 후 evolveAfter 경과).
    var isEvolved: Bool {
        canEvolve && Date().timeIntervalSince(hatchedAt) >= Creature.evolveAfter
    }

    /// 화면에 그릴 이미지 에셋명(진화 시 진화 이미지).
    var displayImageName: String {
        if isEvolved, let evolved = species.evolvedImageName { return evolved }
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
