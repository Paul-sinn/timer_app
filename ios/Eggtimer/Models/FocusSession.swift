//
//  FocusSession.swift
//  Eggtimer
//
//  집중 세션 1건. 순수 Swift 값 타입(struct). SwiftData 미사용(Phase 0).
//  keptScreenOn = 집중 유효성(화면을 끄지 않고 유지했는지).
//

import Foundation

struct FocusSession: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let durationMinutes: Int
    let keptScreenOn: Bool

    init(
        id: UUID = UUID(),
        date: Date,
        durationMinutes: Int,
        keptScreenOn: Bool
    ) {
        self.id = id
        self.date = date
        self.durationMinutes = durationMinutes
        self.keptScreenOn = keptScreenOn
    }
}
