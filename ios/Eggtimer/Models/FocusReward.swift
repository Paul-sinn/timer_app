//
//  FocusReward.swift
//  Eggtimer
//
//  집중 길이 → 부화 뽑기 횟수(best-of-N)의 단일 출처.
//  오래 집중할수록 draw가 늘고, CreatureSpecies.roll(draws:)가 등급을 draw번 굴려 **최고 등급**을
//  채택한다. 등급/종 weight 자체는 불변 — 길이 보상은 오직 draw 횟수로만 준다.
//  free 25/50분·포모도로 누적 집중을 하나의 규칙으로 통합한다.
//

import Foundation

enum FocusReward {
    /// draw 1회당 필요한 유효 집중 시간(초). 25분.
    static let secondsPerDraw = 25 * 60
    /// draw 상한(전설 확률 폭주 방지). 4 = 100분 이상.
    static let maxDraws = 4

    /// Done한 유효 집중초 → draw 횟수. 항상 1 이상, maxDraws 이하.
    /// 25분=1 · 50분=2 · 75분=3 · 100분+=4.
    static func draws(focusSeconds: Int) -> Int {
        guard focusSeconds > 0 else { return 1 }
        return max(1, min(maxDraws, focusSeconds / secondsPerDraw))
    }
}
