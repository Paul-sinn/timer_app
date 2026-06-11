//
//  FocusHistoryStore.swift
//  Eggtimer
//
//  끝난 집중 세션 이력의 공유 상태(Feature 5). SwiftData 백킹 — 앱 재시작 후 유지.
//  ModelContext 없이 생성하면(프리뷰/검수) 메모리 전용.
//  통계는 StatsEngine으로 파생한다.
//

import SwiftUI
import SwiftData

@Observable
final class FocusHistoryStore {
    /// 끝난 세션 목록(최신순).
    private(set) var sessions: [FocusSessionResult]

    @ObservationIgnored private let context: ModelContext?

    /// 영속 모드: 저장된 이력 로드.
    init(context: ModelContext) {
        self.context = context
        let records = (try? context.fetch(FetchDescriptor<FocusSessionRecord>())) ?? []
        self.sessions = records.map { $0.toResult() }.sorted { $0.startedAt > $1.startedAt }
    }

    /// 메모리 전용(프리뷰/검수/테스트 보조).
    init(sessions: [FocusSessionResult] = []) {
        self.context = nil
        self.sessions = sessions.sorted { $0.startedAt > $1.startedAt }
    }

    /// 끝난 세션을 기록(영속 저장).
    func record(_ result: FocusSessionResult) {
        sessions.insert(result, at: 0)
        if let context {
            context.insert(FocusSessionRecord(from: result))
            try? context.save()
        }
    }
}
