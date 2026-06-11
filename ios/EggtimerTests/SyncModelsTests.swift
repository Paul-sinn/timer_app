//
//  SyncModelsTests.swift
//  EggtimerTests
//
//  Supabase 행 DTO ↔ 도메인 값 타입 매핑 + snake_case CodingKeys 검증(Phase 3-4).
//  순수 로직만 테스트(SwiftData 컨테이너·네트워크 제외 — lessons 참고).
//

import Testing
import Foundation
@testable import Eggtimer

struct SyncModelsTests {

    private let userId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    // MARK: - FocusSessionRow

    @Test func focusSessionRoundTripPreservesFields() {
        let result = FocusSessionResult(
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            plannedSeconds: 1500, activeSeconds: 1490,
            interruptionCount: 2, distracted: true, completed: false
        )
        let row = FocusSessionRow(result, userId: userId)
        #expect(row.userId == userId)
        #expect(row.id == result.id)
        #expect(row.toResult() == result)
    }

    @Test func focusSessionRowUsesSnakeCaseKeys() throws {
        let row = FocusSessionRow(
            id: UUID(), userId: userId, startedAt: Date(), plannedSeconds: 1500,
            activeSeconds: 1490, interruptionCount: 1, distracted: false, completed: true
        )
        let data = try JSONEncoder().encode(row)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json.keys.contains("user_id"))
        #expect(json.keys.contains("started_at"))
        #expect(json.keys.contains("planned_seconds"))
        #expect(json.keys.contains("active_seconds"))
        #expect(json.keys.contains("interruption_count"))
        #expect(!json.keys.contains("userId"))
        #expect(!json.keys.contains("plannedSeconds"))
    }

    // MARK: - HatchedCreatureRow

    @Test func creatureRoundTripPreservesIdentity() throws {
        let creature = Creature(species: .blackCat, imageName: "black_cat_1",
                                hatchedAt: Date(timeIntervalSince1970: 1_700_000_500))
        let row = HatchedCreatureRow(creature, userId: userId)
        #expect(row.userId == userId)
        #expect(row.species == "blackCat")

        let back = try #require(row.toCreature())
        #expect(back.id == creature.id)
        #expect(back.species == creature.species)
        #expect(back.imageName == creature.imageName)
        #expect(back.hatchedAt == creature.hatchedAt)
    }

    @Test func creatureRowUsesSnakeCaseKeys() throws {
        let row = HatchedCreatureRow(id: UUID(), userId: userId, species: "slime",
                                     imageName: "slime_1", hatchedAt: Date())
        let data = try JSONEncoder().encode(row)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json.keys.contains("user_id"))
        #expect(json.keys.contains("image_name"))
        #expect(json.keys.contains("hatched_at"))
        #expect(!json.keys.contains("imageName"))
    }

    @Test func unknownSpeciesMapsToNil() {
        let row = HatchedCreatureRow(id: UUID(), userId: userId, species: "dragon_unknown",
                                     imageName: "x", hatchedAt: Date())
        #expect(row.toCreature() == nil)
    }

    // MARK: - ProfileRow

    @Test func profileRowUsesSnakeCaseKeys() throws {
        let row = ProfileRow(id: userId, displayName: "폴")
        let data = try JSONEncoder().encode(row)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json.keys.contains("display_name"))
        #expect(!json.keys.contains("displayName"))
    }
}
