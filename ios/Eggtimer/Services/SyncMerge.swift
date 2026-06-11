//
//  SyncMerge.swift
//  Eggtimer
//
//  로컬(SwiftData) ↔ 원격(Supabase) 동기화 머지 정책(Phase 3). 순수 로직 → 단위 테스트 대상.
//  세션·부화 이력은 생성 후 불변(append-only)이라 id 기준 합집합(union)이 곧 정답 — 충돌 병합 불필요.
//

import Foundation

nonisolated enum SyncMerge {
    /// 로컬·원격 항목을 id로 비교해 양방향 동기화 작업을 산출한다.
    /// - Returns:
    ///   - toInsertLocal: 원격에만 있어 로컬에 추가할 항목.
    ///   - toPush: 로컬에만 있어 원격에 올릴 항목.
    static func diff<T: Identifiable>(local: [T], remote: [T])
        -> (toInsertLocal: [T], toPush: [T]) where T.ID: Hashable {
        let localIDs = Set(local.map(\.id))
        let remoteIDs = Set(remote.map(\.id))
        let toInsertLocal = remote.filter { !localIDs.contains($0.id) }
        let toPush = local.filter { !remoteIDs.contains($0.id) }
        return (toInsertLocal, toPush)
    }
}
