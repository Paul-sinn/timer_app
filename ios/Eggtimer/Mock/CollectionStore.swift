//
//  CollectionStore.swift
//  Eggtimer
//
//  탭 간 공유되는 도감 상태. 부화한 생명체가 여기에 쌓이고, 홈/컬렉션이 함께 본다.
//  Phase 0: 영속화 없이 메모리 상태만 유지(앱 재시작 시 초기화). 시드는 MockData.
//

import SwiftUI

@Observable
final class CollectionStore {
    /// 발견(부화)한 생명체 목록. 최신순.
    var creatures: [Creature]

    init(creatures: [Creature] = MockData.populated.creatures) {
        self.creatures = creatures
    }

    /// 확률표에 따라 새 생명체를 부화시켜 컬렉션 맨 앞에 추가하고 반환한다.
    @discardableResult
    func hatch() -> Creature {
        let creature = Creature.hatch()
        creatures.insert(creature, at: 0)
        return creature
    }

    /// 이미 발견한 종 집합(컬렉션의 발견/미발견 판정용).
    var discoveredSpecies: Set<CreatureSpecies> {
        Set(creatures.map(\.species))
    }

    /// 종별 대표(가장 최근 부화) 생명체. 컬렉션 카드 표시에 사용.
    func latest(of species: CreatureSpecies) -> Creature? {
        creatures.first { $0.species == species }
    }
}
