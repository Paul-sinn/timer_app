//
//  FocusSessionResult.swift
//  Eggtimer
//
//  끝난(Done/Stop) 집중 세션 1건의 요약 값 타입. 통계·점수의 단위.
//  focusScore는 활동시간 달성도 + 이탈 페널티로 계산(keptScreenOn 대체, Feature 5·6).
//

import Foundation

struct FocusSessionResult: Identifiable, Equatable {
    let id: UUID
    let startedAt: Date
    let plannedSeconds: Int
    let activeSeconds: Int
    /// minor 이상 이탈 횟수.
    let interruptionCount: Int
    /// 10분+ 이탈이 한 번이라도 있었는지.
    let distracted: Bool
    /// 목표 도달로 끝났는지(부화), Stop(abandon)인지.
    let completed: Bool
    /// 이 세션을 함께한 동료 캐릭터 id(알 단계 세션은 nil). 진화 단계 귀속용.
    let companionID: UUID?
    /// 타이머 모드(free/pomodoro). 모드별 통계용.
    let mode: TimerMode?

    init(id: UUID = UUID(), startedAt: Date, plannedSeconds: Int, activeSeconds: Int,
         interruptionCount: Int, distracted: Bool, completed: Bool,
         companionID: UUID? = nil, mode: TimerMode? = nil) {
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

    var activeMinutes: Int { activeSeconds / 60 }

    /// 집중 점수 0...100.
    var focusScore: Int {
        FocusScore.compute(plannedSeconds: plannedSeconds, activeSeconds: activeSeconds,
                           interruptionCount: interruptionCount, distracted: distracted)
    }
}

enum FocusScore {
    /// 100점에서 목표 미달(최대 -30) + 이탈(회당 -8) + distracted(-20) 페널티.
    static func compute(plannedSeconds: Int, activeSeconds: Int,
                        interruptionCount: Int, distracted: Bool) -> Int {
        var score = 100.0
        if plannedSeconds > 0 {
            let shortfall = max(0, Double(plannedSeconds - activeSeconds)) / Double(plannedSeconds)
            score -= shortfall * 30
        }
        score -= Double(interruptionCount) * 8
        if distracted { score -= 20 }
        return max(0, min(100, Int(score.rounded())))
    }
}
