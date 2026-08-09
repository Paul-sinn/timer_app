//
//  SyncModels.swift
//  Eggtimer
//
//  Supabase 테이블 행 ↔ 도메인 값 타입 변환 DTO(Phase 3-4). 순수 매핑(테스트 대상).
//  CodingKeys로 snake_case 컬럼에 매핑. id는 로컬 SwiftData id와 동일 → upsert idempotent.
//

import Foundation

/// 행 DTO의 `CodingKeys`(컬럼 이름 단일 출처)에서 PostgREST `select` 목록 문자열을 만든다.
/// `select()`의 기본값 `*`는 앱이 디코딩하지 않는 컬럼(created_at/updated_at)까지 실어 오므로 쓰지 않는다.
/// 컬럼 문자열을 두 군데 하드코딩하면 필드 추가 시 한쪽만 고쳐 디코딩이 깨지므로 CodingKeys에서 파생한다.
nonisolated enum SyncColumns {
    static func list<K: CodingKey & CaseIterable>(_ keys: K.Type) -> String {
        K.allCases.map(\.stringValue).joined(separator: ",")
    }
}

/// public.focus_sessions 한 행. FocusSessionResult ↔ 변환.
nonisolated struct FocusSessionRow: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let userId: UUID
    let startedAt: Date
    let plannedSeconds: Int
    let activeSeconds: Int
    let interruptionCount: Int
    let distracted: Bool
    let completed: Bool
    let companionId: UUID?
    let mode: String?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case userId = "user_id"
        case startedAt = "started_at"
        case plannedSeconds = "planned_seconds"
        case activeSeconds = "active_seconds"
        case interruptionCount = "interruption_count"
        case distracted
        case completed
        case companionId = "companion_id"
        case mode
    }

    /// PostgREST `select`에 넘길 컬럼 목록. 필드가 늘면 CodingKeys를 따라 자동 반영된다.
    static var selectColumns: String { SyncColumns.list(CodingKeys.self) }

    init(id: UUID, userId: UUID, startedAt: Date, plannedSeconds: Int, activeSeconds: Int,
         interruptionCount: Int, distracted: Bool, completed: Bool,
         companionId: UUID? = nil, mode: String? = nil) {
        self.id = id
        self.userId = userId
        self.startedAt = startedAt
        self.plannedSeconds = plannedSeconds
        self.activeSeconds = activeSeconds
        self.interruptionCount = interruptionCount
        self.distracted = distracted
        self.completed = completed
        self.companionId = companionId
        self.mode = mode
    }

    init(_ r: FocusSessionResult, userId: UUID) {
        self.init(id: r.id, userId: userId, startedAt: r.startedAt, plannedSeconds: r.plannedSeconds,
                  activeSeconds: r.activeSeconds, interruptionCount: r.interruptionCount,
                  distracted: r.distracted, completed: r.completed,
                  companionId: r.companionID, mode: r.mode?.rawValue)
    }

    func toResult() -> FocusSessionResult {
        FocusSessionResult(id: id, startedAt: startedAt, plannedSeconds: plannedSeconds,
                           activeSeconds: activeSeconds, interruptionCount: interruptionCount,
                           distracted: distracted, completed: completed,
                           companionID: companionId, mode: mode.flatMap { TimerMode(rawValue: $0) })
    }
}

/// public.hatched_creatures 한 행. Creature ↔ 변환.
nonisolated struct HatchedCreatureRow: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let userId: UUID
    let species: String
    let imageName: String
    let hatchedAt: Date

    enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case userId = "user_id"
        case species
        case imageName = "image_name"
        case hatchedAt = "hatched_at"
    }

    /// PostgREST `select`에 넘길 컬럼 목록. 필드가 늘면 CodingKeys를 따라 자동 반영된다.
    static var selectColumns: String { SyncColumns.list(CodingKeys.self) }

    init(id: UUID, userId: UUID, species: String, imageName: String, hatchedAt: Date) {
        self.id = id
        self.userId = userId
        self.species = species
        self.imageName = imageName
        self.hatchedAt = hatchedAt
    }

    init(_ c: Creature, userId: UUID) {
        self.init(id: c.id, userId: userId, species: c.species.rawValue,
                  imageName: c.imageName, hatchedAt: c.hatchedAt)
    }

    /// 알 수 없는 종이면 nil(클라 enum이 단일 소스라 미지원 종은 무시).
    func toCreature() -> Creature? {
        guard let s = CreatureSpecies(rawValue: species) else { return nil }
        return Creature(id: id, species: s, imageName: imageName, hatchedAt: hatchedAt)
    }
}

/// public.profiles 한 행.
nonisolated struct ProfileRow: Codable, Equatable, Sendable {
    let id: UUID
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}
