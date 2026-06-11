//
//  SyncMergeTests.swift
//  EggtimerTests
//
//  동기화 머지(id 기준 양방향 합집합) 순수 로직 검증.
//

import Testing
import Foundation
@testable import Eggtimer

struct SyncMergeTests {

    private func session(_ id: UUID) -> FocusSessionResult {
        FocusSessionResult(id: id, startedAt: Date(timeIntervalSince1970: 1_700_000_000),
                           plannedSeconds: 1500, activeSeconds: 1500,
                           interruptionCount: 0, distracted: false, completed: true)
    }

    @Test func bothEmpty() {
        let r = SyncMerge.diff(local: [FocusSessionResult](), remote: [])
        #expect(r.toInsertLocal.isEmpty && r.toPush.isEmpty)
    }

    @Test func localOnlyGoesToPush() {
        let a = session(UUID()), b = session(UUID())
        let r = SyncMerge.diff(local: [a, b], remote: [])
        #expect(Set(r.toPush.map(\.id)) == Set([a.id, b.id]))
        #expect(r.toInsertLocal.isEmpty)
    }

    @Test func remoteOnlyGoesToLocal() {
        let a = session(UUID()), b = session(UUID())
        let r = SyncMerge.diff(local: [], remote: [a, b])
        #expect(Set(r.toInsertLocal.map(\.id)) == Set([a.id, b.id]))
        #expect(r.toPush.isEmpty)
    }

    @Test func overlapResolvesEachDirection() {
        let shared = UUID()
        let localOnly = UUID(), remoteOnly = UUID()
        let local = [session(shared), session(localOnly)]
        let remote = [session(shared), session(remoteOnly)]
        let r = SyncMerge.diff(local: local, remote: remote)
        #expect(r.toPush.map(\.id) == [localOnly])
        #expect(r.toInsertLocal.map(\.id) == [remoteOnly])
    }

    @Test func identicalSetsProduceNoWork() {
        let ids = [UUID(), UUID(), UUID()]
        let local = ids.map(session)
        let remote = ids.map(session)
        let r = SyncMerge.diff(local: local, remote: remote)
        #expect(r.toInsertLocal.isEmpty && r.toPush.isEmpty)
    }

    @Test func worksForCreatures() {
        let shared = UUID()
        let local = [Creature(id: shared, species: .slime, imageName: "Slime", hatchedAt: Date()),
                     Creature(id: UUID(), species: .chicken, imageName: "Chicken1", hatchedAt: Date())]
        let remoteOnly = UUID()
        let remote = [Creature(id: shared, species: .slime, imageName: "Slime", hatchedAt: Date()),
                      Creature(id: remoteOnly, species: .phoenix, imageName: "Phoenix", hatchedAt: Date())]
        let r = SyncMerge.diff(local: local, remote: remote)
        #expect(r.toInsertLocal.map(\.id) == [remoteOnly])
        #expect(r.toPush.count == 1)
    }
}
