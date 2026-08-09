//
//  SyncService.swift
//  Eggtimer
//
//  SwiftData(로컬) ↔ Supabase(원격) 동기화(Phase 3-4). 본인 user_id 행만 다룬다(RLS가 강제).
//  upsert는 PK(id) 충돌 시 병합 → 재실행/중복 호출에 안전(idempotent).
//  네트워크 경로는 인증 세션이 있어야 실제 동작 → 라이브 검증은 공급자 Settings 이후.
//  매핑(SyncModelsTests)과 페이지 경계 계산(SyncPagingTests)은 단위 테스트로 검증한다.
//
//  Pull은 반드시 페이지네이션한다: PostgREST는 `db-max-rows`(Supabase 기본 1000)를 넘는 응답을
//  **에러 없이 잘라서** 준다. 잘린 행은 SyncMerge.diff에서 "원격에 없음"으로 판정돼 toPush에 들어가고,
//  매 로그인마다 같은 행을 재업로드한다(합집합 머지라 데이터 손실은 없지만 트래픽이 영구히 부풀고
//  1000행 넘는 유저는 영원히 완전 동기화가 안 된다).
//

import Foundation
import Supabase

// MARK: - 페이지네이션 정책 (순수 로직 — 네트워크 없이 단위 테스트한다)

/// PostgREST `.range(from:to:)`에 넘길 페이지 경계. 0-based, **양끝 포함**.
nonisolated struct SyncPageRange: Equatable, Sendable {
    let from: Int
    let to: Int
}

nonisolated enum SyncPagingError: Error, LocalizedError, Equatable {
    /// 페이지 상한까지 받았는데도 마지막 페이지에 도달하지 못했다(무한 루프 가드).
    /// 조용히 자르면 잘린 결과로 머지가 돌아 영구 재업로드가 되므로, 반드시 실패시킨다.
    case pageLimitExceeded(pageSize: Int, maxPages: Int)

    var errorDescription: String? {
        switch self {
        case let .pageLimitExceeded(pageSize, maxPages):
            return "동기화 페이지 상한 초과: \(maxPages)페이지 × \(pageSize)행을 받고도 끝에 도달하지 못했습니다."
        }
    }
}

/// pull 페이지네이션 / push 청크 분할의 순수 계산.
/// 뷰·네트워크와 분리해 두어 유닛 테스트가 가능하다(ARCHITECTURE: 순수 로직 분리 규칙).
nonisolated enum SyncPaging {
    /// pull 한 요청에 받아올 행 수.
    /// 근거: PostgREST는 `db-max-rows`(Supabase 기본 1000)를 넘는 응답을 에러 없이 자른다.
    /// 여기서는 "받은 행 수 < 페이지 크기"로 마지막 페이지를 판정하므로, 서버 상한 때문에 잘린 응답을
    /// 마지막 페이지로 **오판하지 않으려면** 페이지 크기가 상한보다 확실히 작아야 한다.
    /// 500 = 기본 상한의 절반 → 상한을 절반(500)까지 낮춰도 안전 마진이 있고,
    /// 왕복 수도 감당 가능하다(1만 행 = 21왕복).
    static let pageSize = 500

    /// pull 최대 요청 횟수(무한 루프 가드). 500 × 200 = 10만 행 = 하루 10세션 × 27년치.
    static let maxPages = 200

    /// push upsert 1건에 담을 최대 행 수. pull 페이지와 같은 상수 체계로 맞춘다.
    static let chunkSize = 500

    /// 0-based 페이지 인덱스 → PostgREST 범위(양끝 포함).
    static func range(page: Int, pageSize: Int = SyncPaging.pageSize) -> SyncPageRange {
        precondition(page >= 0, "page는 0 이상이어야 한다")
        precondition(pageSize > 0, "pageSize는 1 이상이어야 한다")
        let from = page * pageSize
        return SyncPageRange(from: from, to: from + pageSize - 1)
    }

    /// 받은 행 수가 페이지 크기에 못 미치면 마지막 페이지다.
    /// (정확히 페이지 크기면 더 있는지 알 수 없으므로 빈 페이지 1번을 더 확인한다.)
    static func isLastPage(received: Int, pageSize: Int = SyncPaging.pageSize) -> Bool {
        received < pageSize
    }

    /// id 기준 중복 제거(첫 등장 순서 유지).
    /// 페이지네이션 중 새 행이 추가되면(이력은 append-only이고 최신순 정렬이라 앞쪽에 끼어든다)
    /// offset이 밀려 같은 행을 두 번 받을 수 있다. 호출부 `insertFromRemote`는 "호출 전" 기존 id만
    /// 걸러내므로 배열 내부 중복은 그대로 두 번 저장된다 → 여기서 제거한다.
    static func deduplicatedByID<Row: Identifiable>(_ rows: [Row]) -> [Row] {
        var seen = Set<Row.ID>()
        return rows.filter { seen.insert($0.id).inserted }
    }

    /// 배열을 upsert 청크로 자른다(순서 유지, 빈 배열은 요청 0건).
    static func chunks<T>(_ items: [T], size: Int = SyncPaging.chunkSize) -> [[T]] {
        precondition(size > 0, "chunk size는 1 이상이어야 한다")
        guard !items.isEmpty else { return [] }
        return stride(from: 0, to: items.count, by: size).map {
            Array(items[$0..<min($0 + size, items.count)])
        }
    }

    /// 페이지 fetch를 마지막 페이지까지 반복 호출해 전부 모은다(id 중복 제거 포함).
    /// 네트워크는 `fetchPage` 클로저 뒤에 숨어 있어 이 루프 자체는 단위 테스트 대상이다.
    static func fetchAll<Row: Identifiable>(
        pageSize: Int = SyncPaging.pageSize,
        maxPages: Int = SyncPaging.maxPages,
        fetchPage: (SyncPageRange) async throws -> [Row]
    ) async throws -> [Row] {
        var all: [Row] = []
        var page = 0
        while true {
            guard page < maxPages else {
                throw SyncPagingError.pageLimitExceeded(pageSize: pageSize, maxPages: maxPages)
            }
            let rows = try await fetchPage(range(page: page, pageSize: pageSize))
            all.append(contentsOf: rows)
            if isLastPage(received: rows.count, pageSize: pageSize) {
                return deduplicatedByID(all)
            }
            page += 1
        }
    }
}

// MARK: -

nonisolated struct SyncService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    // MARK: - Push (로컬 → 원격)

    func pushSessions(_ results: [FocusSessionResult], userId: UUID) async throws {
        guard !results.isEmpty else { return }
        let rows = results.map { FocusSessionRow($0, userId: userId) }
        try await upsertChunked(rows, into: "focus_sessions")
    }

    func pushCreatures(_ creatures: [Creature], userId: UUID) async throws {
        guard !creatures.isEmpty else { return }
        let rows = creatures.map { HatchedCreatureRow($0, userId: userId) }
        try await upsertChunked(rows, into: "hatched_creatures")
    }

    /// 청크 단위 upsert. 첫 로그인 머지처럼 수천 행이 단일 요청 본문이 되는 걸 막는다.
    /// PostgREST는 요청 1건 = 트랜잭션 1건이라 청크가 나뉘면 부분 성공이 생길 수 있지만,
    /// 이력은 append-only + id 기준 upsert(idempotent)라 다음 syncOnLogin 합집합 머지가
    /// 남은 행을 그대로 다시 올린다(자가 복구) — SyncMerge 주석의 정책과 동일.
    /// `returning: .minimal` — 방금 올린 행 전체를 응답으로 되돌려받을 이유가 없다(호출부가 안 쓴다).
    private func upsertChunked<Row: Encodable & Sendable>(_ rows: [Row], into table: String) async throws {
        for chunk in SyncPaging.chunks(rows) {
            try await client.from(table)
                .upsert(chunk, onConflict: "id", returning: .minimal)
                .execute()
        }
    }

    // MARK: - Pull (원격 → 로컬)

    func fetchSessions(userId: UUID) async throws -> [FocusSessionResult] {
        let rows: [FocusSessionRow] = try await fetchAllRows(
            from: "focus_sessions",
            columns: FocusSessionRow.selectColumns,
            orderedBy: "started_at",
            userId: userId
        )
        return rows.map { $0.toResult() }
    }

    func fetchCreatures(userId: UUID) async throws -> [Creature] {
        let rows: [HatchedCreatureRow] = try await fetchAllRows(
            from: "hatched_creatures",
            columns: HatchedCreatureRow.selectColumns,
            orderedBy: "hatched_at",
            userId: userId
        )
        return rows.compactMap { $0.toCreature() }
    }

    /// 본인(user_id) 행 전체를 페이지 단위로 받아온다. 페이지네이션은 이 안에 감춘다(호출부 시그니처 불변).
    ///
    /// 정렬에 `id` tiebreaker를 더한다: `started_at`/`hatched_at`이 같은 행이 둘 이상이면
    /// Postgres가 tie를 어떤 순서로 내보낼지는 정해져 있지 않고(스캔 방식·플랜에 따라 요청마다 달라질 수 있다),
    /// offset 기반 페이지는 요청마다 새로 정렬한 결과를 자르기 때문에 경계에 걸친 동률 행이
    /// 어떤 요청에선 앞 페이지에, 다른 요청에선 뒤 페이지에 놓여 **행이 통째로 누락**될 수 있다.
    /// `id`(PK, 유니크)를 마지막 정렬 키로 넣으면 전체 순서가 유일하게 결정돼 페이지 경계가 안정된다.
    private func fetchAllRows<Row: Decodable & Identifiable & Sendable>(
        from table: String,
        columns: String,
        orderedBy timestampColumn: String,
        userId: UUID
    ) async throws -> [Row] {
        try await SyncPaging.fetchAll { (page: SyncPageRange) async throws -> [Row] in
            let rows: [Row] = try await client.from(table)
                .select(columns)
                .eq("user_id", value: userId)
                .order(timestampColumn, ascending: false)
                .order("id", ascending: false)
                .range(from: page.from, to: page.to)
                .execute()
                .value
            return rows
        }
    }
}
