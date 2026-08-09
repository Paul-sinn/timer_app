//
//  HatchedCreatureRecord.swift
//  Eggtimer
//
//  부화 이력의 영속 모델(SwiftData, Phase 2-2). 생명체 1마리 = 1행.
//  값 타입 Creature ↔ @Model 레코드를 상호 변환해 컬렉션이 앱 재Start 후에도 유지된다.
//  (종 단위 중복 집계는 creatures 배열을 species로 그룹핑해 파생 — FEATURE_DESIGN F3)
//

import Foundation
import SwiftData

@Model
final class HatchedCreatureRecord {
    @Attribute(.unique) var id: UUID
    /// CreatureSpecies.rawValue
    var speciesRaw: String
    /// 부화 시점에 확정된 이미지 변형(닭 표정 등).
    var imageName: String
    var hatchedAt: Date

    init(id: UUID, speciesRaw: String, imageName: String, hatchedAt: Date) {
        self.id = id
        self.speciesRaw = speciesRaw
        self.imageName = imageName
        self.hatchedAt = hatchedAt
    }

    convenience init(from creature: Creature) {
        self.init(
            id: creature.id,
            speciesRaw: creature.species.rawValue,
            imageName: creature.imageName,
            hatchedAt: creature.hatchedAt
        )
    }

    /// 도메인 값 타입으로 복원(알 수 없는 종이면 nil).
    func toCreature() -> Creature? {
        guard let species = CreatureSpecies(rawValue: speciesRaw) else { return nil }
        return Creature(id: id, species: species, imageName: imageName, hatchedAt: hatchedAt)
    }
}
