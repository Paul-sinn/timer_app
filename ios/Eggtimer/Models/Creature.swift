//
//  Creature.swift
//  Eggtimer
//
//  부화한 생명체. 순수 Swift 값 타입(struct). SwiftData 미사용(Phase 0).
//

import Foundation

struct Creature: Identifiable, Hashable {
    let id: UUID
    let name: String
    let rarity: Rarity
    /// 이미지 placeholder 키. 추후 실제 에셋명으로 교체된다.
    let imageName: String
    let hatchedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        rarity: Rarity,
        imageName: String,
        hatchedAt: Date
    ) {
        self.id = id
        self.name = name
        self.rarity = rarity
        self.imageName = imageName
        self.hatchedAt = hatchedAt
    }
}
