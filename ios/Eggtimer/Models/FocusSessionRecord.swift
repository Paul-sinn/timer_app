//
//  FocusSessionRecord.swift
//  Eggtimer
//
//  끝난 집중 세션의 영속 모델(SwiftData, Phase 2-3). 통계 집계의 원자료.
//  값 타입 FocusSessionResult ↔ @Model 상호 변환.
//

import Foundation
import SwiftData

@Model
final class FocusSessionRecord {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var plannedSeconds: Int
    var activeSeconds: Int
    var interruptionCount: Int
    var distracted: Bool
    var completed: Bool

    init(id: UUID, startedAt: Date, plannedSeconds: Int, activeSeconds: Int,
         interruptionCount: Int, distracted: Bool, completed: Bool) {
        self.id = id
        self.startedAt = startedAt
        self.plannedSeconds = plannedSeconds
        self.activeSeconds = activeSeconds
        self.interruptionCount = interruptionCount
        self.distracted = distracted
        self.completed = completed
    }

    convenience init(from r: FocusSessionResult) {
        self.init(id: r.id, startedAt: r.startedAt, plannedSeconds: r.plannedSeconds,
                  activeSeconds: r.activeSeconds, interruptionCount: r.interruptionCount,
                  distracted: r.distracted, completed: r.completed)
    }

    func toResult() -> FocusSessionResult {
        FocusSessionResult(id: id, startedAt: startedAt, plannedSeconds: plannedSeconds,
                           activeSeconds: activeSeconds, interruptionCount: interruptionCount,
                           distracted: distracted, completed: completed)
    }
}
