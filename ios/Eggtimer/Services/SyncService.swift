//
//  SyncService.swift
//  Eggtimer
//
//  SwiftData(로컬) ↔ Supabase(원격) 동기화(Phase 3-4). 본인 user_id 행만 다룬다(RLS가 강제).
//  upsert는 PK(id) 충돌 시 병합 → 재실행/중복 호출에 안전(idempotent).
//  네트워크 경로는 인증 세션이 있어야 실제 동작 → 라이브 검증은 공급자 설정 이후. 매핑은 단위 테스트로 검증.
//

import Foundation
import Supabase

nonisolated struct SyncService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    // MARK: - Push (로컬 → 원격)

    func pushSessions(_ results: [FocusSessionResult], userId: UUID) async throws {
        guard !results.isEmpty else { return }
        let rows = results.map { FocusSessionRow($0, userId: userId) }
        try await client.from("focus_sessions").upsert(rows, onConflict: "id").execute()
    }

    func pushCreatures(_ creatures: [Creature], userId: UUID) async throws {
        guard !creatures.isEmpty else { return }
        let rows = creatures.map { HatchedCreatureRow($0, userId: userId) }
        try await client.from("hatched_creatures").upsert(rows, onConflict: "id").execute()
    }

    // MARK: - Pull (원격 → 로컬)

    func fetchSessions(userId: UUID) async throws -> [FocusSessionResult] {
        let rows: [FocusSessionRow] = try await client.from("focus_sessions")
            .select()
            .eq("user_id", value: userId)
            .order("started_at", ascending: false)
            .execute()
            .value
        return rows.map { $0.toResult() }
    }

    func fetchCreatures(userId: UUID) async throws -> [Creature] {
        let rows: [HatchedCreatureRow] = try await client.from("hatched_creatures")
            .select()
            .eq("user_id", value: userId)
            .order("hatched_at", ascending: false)
            .execute()
            .value
        return rows.compactMap { $0.toCreature() }
    }
}
