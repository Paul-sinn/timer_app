//
//  SyncCoordinator.swift
//  Eggtimer
//
//  로그인 상태(AuthService)와 로컬 스토어(CollectionStore/FocusHistoryStore)를 잇는
//  동기화 오케스트레이터(Phase 3). 뷰는 이 한 곳만 호출하면 된다:
//   - 로그인 직후: syncOnLogin() → 원격↔로컬 양방향 합집합 머지(SyncMerge).
//   - 부화/세션 종료: pushNewCreature/pushNewSession → 로그인 상태일 때만 단건 push.
//   - Delete account: deleteAccount() → 서버 Edge Function 위임.
//
//  오류 처리(Phase 3-4) — 예전엔 모든 실패를 `try?`로 삼켰다. 지금은:
//   1) 전송성 실패(네트워크·5xx·429)만 지수 백오프 + 지터로 재시도한다(SyncRetryPolicy).
//      인증 실패·쓰기 쿼터 초과·클라이언트 오류·정체불명 에러는 재시도하지 않는다.
//   2) 결과를 lastSyncStatus로 노출하고 os_log에 남긴다 — 조용히 사라지지 않는다.
//   3) 백그라운드 단건 push는 연속 실패가 쌓이면 차단기(SyncCircuitBreaker)로 아예 멈춘다.
//
//  포기해도 데이터는 잃지 않는다: 로컬은 이미 SwiftData에 저장돼 있고, 세션·부화 이력은 append-only라
//  SyncMerge가 id 기준 합집합만 한다. 못 올린 항목은 다음 syncOnLogin()이 그대로 다시 올린다.
//

import Foundation
import OSLog

@Observable
@MainActor
final class SyncCoordinator {
    private let auth: AuthService
    private let store: CollectionStore
    private let history: FocusHistoryStore
    private let sync: SyncService

    private let pullPolicy: SyncRetryPolicy
    private let pushPolicy: SyncRetryPolicy
    private let backgroundPolicy: SyncRetryPolicy

    private static let log = Logger(subsystem: "com.paulsin.hatchly", category: "sync")

    /// 동기화 진행 중 표시(로그인 직후 머지 등 UI 스피너용).
    /// 백그라운드 단건 push는 화면을 막지 않으므로 여기 반영하지 않는다.
    private(set) var isSyncing = false

    /// 마지막으로 확정된 동기화 결과(nil = 이번 실행에서 아직 시도한 적 없음).
    /// 성공/실패·실패 사유 분류·시각을 담는다. 취소는 결과로 기록하지 않는다.
    private(set) var lastSyncStatus: SyncStatus?

    /// 백그라운드 push 차단기. 연속 실패가 쌓이면 잠시 멈춘다.
    private var breaker: SyncCircuitBreaker

    init(auth: AuthService,
         store: CollectionStore,
         history: FocusHistoryStore,
         sync: SyncService = SyncService(),
         pullPolicy: SyncRetryPolicy = .loginPull,
         pushPolicy: SyncRetryPolicy = .loginPush,
         backgroundPolicy: SyncRetryPolicy = .backgroundPush,
         breaker: SyncCircuitBreaker = SyncCircuitBreaker()) {
        self.auth = auth
        self.store = store
        self.history = history
        self.sync = sync
        self.pullPolicy = pullPolicy
        self.pushPolicy = pushPolicy
        self.backgroundPolicy = backgroundPolicy
        self.breaker = breaker
    }

    var isAuthenticated: Bool { auth.isAuthenticated }

    /// 마지막 실패 사유(nil = 성공했거나 아직 시도 없음).
    var lastSyncFailure: SyncFailureKind? { lastSyncStatus?.failureKind }

    /// 사용자에게 그대로 보여줄 수 있는 실패 문구(String Catalog 경유).
    var lastSyncFailureMessage: String? { lastSyncStatus?.userMessage }

    /// 차단기가 열려 백그라운드 push를 쉬는 중인지.
    var isBackgroundSyncPaused: Bool { !breaker.allowsRequest(at: Date()) }

    // MARK: - 로그인 시 양방향 머지

    /// 로그인 직후 1회: 원격을 풀해 로컬과 합집합 머지하고, 로컬에만 있던 항목을 원격에 올린다.
    /// 실패해도 throw하지 않고 lastSyncStatus로만 알린다(로그인 흐름 자체는 계속돼야 한다).
    func syncOnLogin() async {
        guard let userId = auth.currentUserID else { return }
        isSyncing = true
        defer { isSyncing = false }

        // 명시적 사용자 액션 → 이전 장애로 열린 차단기를 푼다.
        breaker.reset()

        do {
            // 생명체가 실패해도 세션은 시도한다(부분 성공이 다음 복구를 가볍게 만든다).
            let creaturesFailure = try await mergeCreatures(userId: userId)
            let sessionsFailure = try await mergeSessions(userId: userId)
            let failure = creaturesFailure ?? sessionsFailure
            if let failure {
                breaker.recordFailure(failure, at: Date())
            } else {
                breaker.recordSuccess()
            }
            record(failure)
        } catch {
            // perform()은 취소만 throw한다. 취소는 실패가 아니라 중단 — 결과를 덮어쓰지 않는다.
            Self.log.debug("sync cancelled during login merge")
        }
    }

    /// - Returns: 실패 종류(nil = 성공). 취소만 throw한다.
    private func mergeCreatures(userId: UUID) async throws -> SyncFailureKind? {
        let pulled = try await perform("pull creatures", policy: pullPolicy) {
            try await self.sync.fetchCreatures(userId: userId)
        }
        switch pulled {
        case .failure(let kind):
            // 원격을 못 읽었으면 push도 하지 않는다 — 이미 원격에 있는 걸 다시 올릴 수 있고,
            // 어차피 다음 로그인 머지가 합집합으로 복구한다.
            return kind
        case .success(let remote):
            let (toInsertLocal, toPush) = SyncMerge.diff(local: store.creatures, remote: remote)
            store.insertFromRemote(toInsertLocal)
            guard !toPush.isEmpty else { return nil }
            let pushed = try await perform("push creatures", policy: pushPolicy) {
                try await self.sync.pushCreatures(toPush, userId: userId)
            }
            if case .failure(let kind) = pushed { return kind }
            return nil
        }
    }

    /// - Returns: 실패 종류(nil = 성공). 취소만 throw한다.
    private func mergeSessions(userId: UUID) async throws -> SyncFailureKind? {
        let pulled = try await perform("pull sessions", policy: pullPolicy) {
            try await self.sync.fetchSessions(userId: userId)
        }
        switch pulled {
        case .failure(let kind):
            return kind
        case .success(let remote):
            let (toInsertLocal, toPush) = SyncMerge.diff(local: history.sessions, remote: remote)
            history.insertFromRemote(toInsertLocal)
            guard !toPush.isEmpty else { return nil }
            let pushed = try await perform("push sessions", policy: pushPolicy) {
                try await self.sync.pushSessions(toPush, userId: userId)
            }
            if case .failure(let kind) = pushed { return kind }
            return nil
        }
    }

    // MARK: - 신규 발생분 단건 push (로그인 상태에서만)

    /// 새로 부화한 생명체를 원격에 올린다(비로그인 시 무시 — 다음 로그인 머지가 처리).
    func pushNewCreature(_ creature: Creature) {
        guard let userId = auth.currentUserID else { return }
        guard allowsBackgroundPush("push creature") else { return }
        Task {
            await self.runBackgroundPush("push creature") {
                try await self.sync.pushCreatures([creature], userId: userId)
            }
        }
    }

    /// 끝난 세션을 원격에 올린다(비로그인 시 무시).
    func pushNewSession(_ result: FocusSessionResult) {
        guard let userId = auth.currentUserID else { return }
        guard allowsBackgroundPush("push session") else { return }
        Task {
            await self.runBackgroundPush("push session") {
                try await self.sync.pushSessions([result], userId: userId)
            }
        }
    }

    /// 차단기가 열려 있으면 네트워크를 아예 두드리지 않는다.
    /// 건너뛴 항목은 로컬에 남아 있고 다음 syncOnLogin()의 합집합 머지가 올린다.
    private func allowsBackgroundPush(_ label: String) -> Bool {
        guard breaker.allowsRequest(at: Date()) else {
            Self.log.notice("\(label, privacy: .public) skipped: background sync paused (circuit open)")
            return false
        }
        return true
    }

    private func runBackgroundPush(_ label: String, _ operation: () async throws -> Void) async {
        do {
            let outcome = try await perform(label, policy: backgroundPolicy, operation: operation)
            switch outcome {
            case .success:
                breaker.recordSuccess()
                record(nil)
            case .failure(let kind):
                breaker.recordFailure(kind, at: Date())
                record(kind)
            }
        } catch {
            // 취소만 여기로 온다 — 실패로 기록하지 않는다.
            Self.log.debug("\(label, privacy: .public) cancelled")
        }
    }

    // MARK: - 재시도 실행

    private enum AttemptOutcome<T> {
        case success(T)
        case failure(SyncFailureKind)
    }

    /// 정책이 허락하는 동안 `operation`을 다시 시도한다.
    /// - 재시도 여부·대기 시간은 전부 SyncRetryPolicy가 정한다(여기서 규칙을 재구현하지 않는다).
    /// - 취소만 throw로 밖에 전파한다(Task.sleep의 CancellationError 포함). 나머지 실패는 값으로 돌려준다.
    private func perform<T>(_ label: String,
                            policy: SyncRetryPolicy,
                            operation: () async throws -> T) async throws -> AttemptOutcome<T> {
        var attempt = 0
        var elapsedDelay: TimeInterval = 0

        while true {
            try Task.checkCancellation()
            attempt += 1
            do {
                let value = try await operation()
                return .success(value)
            } catch {
                let kind = SyncErrorMapper.kind(for: error)
                if kind == .cancelled { throw CancellationError() }

                guard let delay = policy.nextDelay(afterAttempt: attempt,
                                                   kind: kind,
                                                   elapsedDelay: elapsedDelay,
                                                   randomUnit: Double.random(in: 0..<1)) else {
                    // 실패 요약은 공개(진단용), 원본 에러 문자열은 응답 바디가 섞일 수 있어 비공개.
                    let summary = "\(label) gave up after \(attempt) attempt(s) — \(kind.rawValue). "
                        + "Local data kept; the next sign-in merge will re-push it."
                    Self.log.error("\(summary, privacy: .public) \(String(describing: error), privacy: .private)")
                    return .failure(kind)
                }

                let retryNote = "\(label) attempt \(attempt) failed (\(kind.rawValue)); "
                    + "retrying in \(String(format: "%.2f", delay))s"
                Self.log.warning("\(retryNote, privacy: .public)")

                // 취소되면 CancellationError를 그대로 위로 던진다(재시도 루프를 즉시 끝낸다).
                try await Task.sleep(for: .seconds(delay))
                elapsedDelay += delay
            }
        }
    }

    private func record(_ failure: SyncFailureKind?) {
        let outcome: SyncStatus.Outcome
        if let failure {
            outcome = .failure(failure)
        } else {
            outcome = .success
        }
        lastSyncStatus = SyncStatus(outcome: outcome, at: Date())
    }

    // MARK: - Account

    func signOut() async {
        await auth.signOut()
        breaker.reset()
        lastSyncStatus = nil
    }

    func deleteAccount() async throws {
        try await auth.deleteAccount()
        breaker.reset()
        lastSyncStatus = nil
    }
}
