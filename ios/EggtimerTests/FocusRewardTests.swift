//
//  FocusRewardTests.swift
//  EggtimerTests
//
//  집중 길이 → 부화 뽑기 횟수(best-of-N) 매핑 검증.
//

import Testing
import Foundation
@testable import Eggtimer

struct FocusRewardTests {

    @Test func drawsScaleWithFocusLength() {
        #expect(FocusReward.draws(focusSeconds: 0) == 1)        // 빈 세션도 최소 1
        #expect(FocusReward.draws(focusSeconds: 24 * 60) == 1)  // 24분 → 1
        #expect(FocusReward.draws(focusSeconds: 25 * 60) == 1)  // 25분 → 1
        #expect(FocusReward.draws(focusSeconds: 49 * 60) == 1)  // 49분 → 1
        #expect(FocusReward.draws(focusSeconds: 50 * 60) == 2)  // 50분 → 2
        #expect(FocusReward.draws(focusSeconds: 74 * 60) == 2)  // 74분 → 2
        #expect(FocusReward.draws(focusSeconds: 75 * 60) == 3)  // 75분 → 3
        #expect(FocusReward.draws(focusSeconds: 100 * 60) == 4) // 100분 → 4
    }

    @Test func drawsClampToMax() {
        // 아무리 길어도 상한을 넘지 않고, 항상 1 이상.
        for minutes in stride(from: 0, through: 600, by: 7) {
            let d = FocusReward.draws(focusSeconds: minutes * 60)
            #expect(d >= 1 && d <= FocusReward.maxDraws)
        }
        #expect(FocusReward.draws(focusSeconds: 600 * 60) == FocusReward.maxDraws)
    }
}
