//
//  DialogueLine.swift
//  Eggtimer
//
//  캐릭터가 가끔 띄우는 한마디(Feature 4). 트리거별로 가중 랜덤 + 비반복 + 쿨다운으로 고른다.
//

import Foundation

enum DialogueTrigger {
    case idle           // 홈에서 대기 중
    case focusing       // 집중 세션 진행 중(시작/주기)
    case appReturn      // 앱으로 돌아옴
    case sessionComplete // 부화/완료
}

struct DialogueLine: Identifiable, Equatable {
    let id: String
    let text: String
    let trigger: DialogueTrigger
    /// 가중치(높을수록 자주).
    let weight: Int
    /// 이 줄을 띄우기 위한 최소 연속일(없으면 0).
    let minStreak: Int
    /// 같은 줄 재등장 최소 간격(초).
    let cooldown: TimeInterval

    init(id: String, text: String, trigger: DialogueTrigger,
         weight: Int = 10, minStreak: Int = 0, cooldown: TimeInterval = 30) {
        self.id = id
        self.text = text
        self.trigger = trigger
        self.weight = weight
        self.minStreak = minStreak
        self.cooldown = cooldown
    }
}
