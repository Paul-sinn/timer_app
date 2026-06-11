//
//  CollectionStore.swift
//  Eggtimer
//
//  탭 간 공유되는 도감 상태. 부화한 생명체가 여기에 쌓이고, 홈/컬렉션이 함께 본다.
//  Phase 2-2: SwiftData(ModelContext) 백킹 — 앱 재시작 후에도 유지된다.
//  ModelContext 없이 생성하면(프리뷰/검수) 메모리 전용으로 동작한다.
//

import SwiftUI
import SwiftData

@Observable
final class CollectionStore {
    /// 발견(부화)한 생명체 목록. 최신순.
    private(set) var creatures: [Creature]

    /// 영속 컨텍스트(nil = 메모리 전용 프리뷰 모드).
    @ObservationIgnored private let context: ModelContext?

    /// 영속 모드: 저장된 부화 이력을 불러온다.
    init(context: ModelContext) {
        self.context = context
        var descriptor = FetchDescriptor<HatchedCreatureRecord>()
        descriptor.sortBy = [SortDescriptor(\.hatchedAt, order: .reverse)]
        let records = (try? context.fetch(descriptor)) ?? []
        self.creatures = records.compactMap { $0.toCreature() }
    }

    /// 메모리 전용 모드(프리뷰/검수). 기본값 = populated.
    init(creatures: [Creature] = MockData.populated.creatures) {
        self.context = nil
        self.creatures = creatures
    }

    /// 확률표에 따라 새 생명체를 부화시켜 컬렉션 맨 앞에 추가하고 반환한다(영속 저장).
    @discardableResult
    func hatch() -> Creature {
        let creature = Creature.hatch()
        creatures.insert(creature, at: 0)
        if let context {
            context.insert(HatchedCreatureRecord(from: creature))
            try? context.save()
        }
        return creature
    }

    /// 이미 발견한 종 집합(컬렉션의 발견/미발견 판정용).
    var discoveredSpecies: Set<CreatureSpecies> {
        Set(creatures.map(\.species))
    }

    /// 종별 대표(가장 최근 부화) 생명체.
    func latest(of species: CreatureSpecies) -> Creature? {
        creatures.first { $0.species == species }
    }
}
