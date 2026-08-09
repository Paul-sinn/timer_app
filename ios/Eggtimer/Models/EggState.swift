//
//  EggState.swift
//  Eggtimer
//
//  알의 부화 진행 상태. 순수 Swift 값 타입(struct).
//  누적 집중 시간 기준으로 crack 단계/진행도/남은 시간을 계산한다.
//  핵심 규칙(ARCHITECTURE.md): 기본 15분마다 crack 단계 +1, 목표 누적 시간 도달 시 부화.
//

import Foundation

struct EggState: Hashable {
    /// 부화까지 누적되어야 하는 목표 집중 시간(분).
    let targetMinutes: Int
    /// 현재까지 누적된 유효 집중 시간(분).
    let focusedMinutes: Int

    /// crack 단계가 한 칸 오르는 데 필요한 시간(분).
    static let minutesPerCrack = 15

    init(targetMinutes: Int, focusedMinutes: Int) {
        self.targetMinutes = targetMinutes
        self.focusedMinutes = focusedMinutes
    }

    /// 15분마다 1씩 증가하는 crack 단계. 목표 도달 시의 최대 단계로 캡.
    var crackStage: Int {
        let maxStage = targetMinutes / EggState.minutesPerCrack
        return min(focusedMinutes / EggState.minutesPerCrack, maxStage)
    }

    /// Hatch progress 0...1.
    var progress: Double {
        guard targetMinutes > 0 else { return 0 }
        return min(Double(focusedMinutes) / Double(targetMinutes), 1)
    }

    /// 목표까지 남은 시간(분). 도달 시 0.
    var remainingMinutes: Int {
        max(targetMinutes - focusedMinutes, 0)
    }

    /// 목표 누적 시간에 도달해 부화한 상태인지.
    var isHatched: Bool {
        focusedMinutes >= targetMinutes
    }

    // MARK: - 시각 단계 (알 이미지 6종 매핑)

    /// 알 이미지 단계 수. 에셋 Egg0(온전) ~ Egg5(부화 직전) 6종.
    static let visualStages = 6

    /// 진행도(0...1)를 0...5 알 이미지 인덱스로 매핑.
    var stageIndex: Int {
        let i = Int(progress * Double(EggState.visualStages))
        return min(max(i, 0), EggState.visualStages - 1)
    }

    /// 현재 단계 에셋 이름 (Egg0 ~ Egg5).
    var eggAssetName: String { "Egg\(stageIndex)" }
}
