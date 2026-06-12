//
//  SyncCoordinator.swift
//  Eggtimer
//
//  로그인 상태(AuthService)와 로컬 스토어(CollectionStore/FocusHistoryStore)를 잇는
//  동기화 오케스트레이터(Phase 3). 뷰는 이 한 곳만 호출하면 된다:
//   - 로그인 직후: syncOnLogin() → 원격↔로컬 양방향 합집합 머지(SyncMerge).
//   - 부화/세션 종료: pushNewCreature/pushNewSession → 로그인 상태일 때만 단건 push.
//   - 계정 삭제: deleteAccount() → 서버 Edge Function 위임.
//  네트워크 실패는 조용히 무시한다 — 다음 로그인 시 syncOnLogin()이 합집합으로 자연 복구하기 때문(append-only).
//

import Foundation

@Observable
@MainActor
final class SyncCoordinator {
    private let auth: AuthService
    private let store: CollectionStore
    private let history: FocusHistoryStore
    private let sync: SyncService

    /// 동기화 진행 중 표시(로그인 직후 머지 등 UI 스피너용).
    private(set) var isSyncing = false

    init(auth: AuthService,
         store: CollectionStore,
         history: FocusHistoryStore,
         sync: SyncService = SyncService()) {
        self.auth = auth
        self.store = store
        self.history = history
        self.sync = sync
    }

    var isAuthenticated: Bool { auth.isAuthenticated }

    // MARK: - 로그인 시 양방향 머지

    /// 로그인 직후 1회: 원격을 풀해 로컬과 합집합 머지하고, 로컬에만 있던 항목을 원격에 올린다.
    func syncOnLogin() async {
        guard let userId = auth.currentUserID else { return }
        isSyncing = true
        defer { isSyncing = false }

        await mergeCreatures(userId: userId)
        await mergeSessions(userId: userId)
    }

    private func mergeCreatures(userId: UUID) async {
        guard let remote = try? await sync.fetchCreatures(userId: userId) else { return }
        let (toInsertLocal, toPush) = SyncMerge.diff(local: store.creatures, remote: remote)
        store.insertFromRemote(toInsertLocal)
        try? await sync.pushCreatures(toPush, userId: userId)
    }

    private func mergeSessions(userId: UUID) async {
        guard let remote = try? await sync.fetchSessions(userId: userId) else { return }
        let (toInsertLocal, toPush) = SyncMerge.diff(local: history.sessions, remote: remote)
        history.insertFromRemote(toInsertLocal)
        try? await sync.pushSessions(toPush, userId: userId)
    }

    // MARK: - 신규 발생분 단건 push (로그인 상태에서만)

    /// 새로 부화한 생명체를 원격에 올린다(비로그인 시 무시 — 다음 로그인 머지가 처리).
    func pushNewCreature(_ creature: Creature) {
        guard let userId = auth.currentUserID else { return }
        Task { try? await sync.pushCreatures([creature], userId: userId) }
    }

    /// 끝난 세션을 원격에 올린다(비로그인 시 무시).
    func pushNewSession(_ result: FocusSessionResult) {
        guard let userId = auth.currentUserID else { return }
        Task { try? await sync.pushSessions([result], userId: userId) }
    }

    // MARK: - 계정

    func signOut() async {
        await auth.signOut()
    }

    func deleteAccount() async throws {
        try await auth.deleteAccount()
    }
}
