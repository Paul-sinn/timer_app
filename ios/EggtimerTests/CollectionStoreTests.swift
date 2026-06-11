//
//  CollectionStoreTests.swift
//  EggtimerTests
//
//  도감 영속화의 순수 로직(값 ↔ @Model 매핑) 검증.
//  주의: ModelContainer 생성 + context.fetch 통합 경로는 iOS 26 시뮬레이터의
//  Swift Testing 실행 컨텍스트에서 SIGTRAP가 나므로(코드 버그 아님, 실제 앱 런치는 정상)
//  여기서는 컨테이너 없이 매핑만 테스트한다. 컨테이너 경로는 앱 실행으로 검증.
//

import Testing
import Foundation
@testable import Eggtimer

@MainActor
struct CollectionStoreTests {

    @Test func recordRoundTripsToCreature() {
        let original = Creature(species: .whiteTiger, imageName: "WhiteTiger", hatchedAt: .now)
        let record = HatchedCreatureRecord(from: original)
        let restored = record.toCreature()
        #expect(restored?.id == original.id)
        #expect(restored?.species == .whiteTiger)
        #expect(restored?.imageName == "WhiteTiger")
    }

    @Test func unknownSpeciesMapsToNil() {
        let bad = HatchedCreatureRecord(id: UUID(), speciesRaw: "dragon_xyz",
                                        imageName: "X", hatchedAt: .now)
        #expect(bad.toCreature() == nil)
    }

    @Test func recordPreservesHatchDate() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let c = Creature(species: .slime, imageName: "Slime", hatchedAt: date)
        let restored = HatchedCreatureRecord(from: c).toCreature()
        #expect(restored?.hatchedAt == date)
    }
}
