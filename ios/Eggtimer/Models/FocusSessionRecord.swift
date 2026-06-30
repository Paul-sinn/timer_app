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
    /// 동료 캐릭터 id(알 단계 세션은 nil). 진화 단계 귀속용. 옵셔널 → lightweight 마이그레이션 안전.
    var companionID: UUID?
    /// 타이머 모드 rawValue(free/pomodoro). 옵셔널.
    var mode: String?

    init(id: UUID, startedAt: Date, plannedSeconds: Int, activeSeconds: Int,
         interruptionCount: Int, distracted: Bool, completed: Bool,
         companionID: UUID? = nil, mode: String? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.plannedSeconds = plannedSeconds
        self.activeSeconds = activeSeconds
        self.interruptionCount = interruptionCount
        self.distracted = distracted
        self.completed = completed
        self.companionID = companionID
        self.mode = mode
    }

    convenience init(from r: FocusSessionResult) {
        self.init(id: r.id, startedAt: r.startedAt, plannedSeconds: r.plannedSeconds,
                  activeSeconds: r.activeSeconds, interruptionCount: r.interruptionCount,
                  distracted: r.distracted, completed: r.completed,
                  companionID: r.companionID, mode: r.mode?.rawValue)
    }

    func toResult() -> FocusSessionResult {
        FocusSessionResult(id: id, startedAt: startedAt, plannedSeconds: plannedSeconds,
                           activeSeconds: activeSeconds, interruptionCount: interruptionCount,
                           distracted: distracted, completed: completed,
                           companionID: companionID, mode: mode.flatMap { TimerMode(rawValue: $0) })
    }
}
