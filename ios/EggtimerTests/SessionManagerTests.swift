//
//  SessionManagerTests.swift
//  EggtimerTests
//
//  집중 세션 상태머신·타임스탬프 재계산 검증(주입형 시계로 결정적 테스트).
//

import Testing
import Foundation
@testable import Eggtimer

@MainActor
private final class ClockBox {
    var now = Date(timeIntervalSince1970: 1_000_000)
    func advance(_ seconds: Int) { now = now.addingTimeInterval(TimeInterval(seconds)) }
}

@MainActor
struct SessionManagerTests {

    private func make(planned: Int, _ clock: ClockBox) -> SessionManager {
        SessionManager(plannedSeconds: planned, clock: { clock.now }, persists: false)
    }

    @Test func startsIdle() {
        let m = make(planned: 100, ClockBox())
        #expect(m.isIdle)
        #expect(m.phase == nil)
        #expect(m.remainingSeconds == 100)
    }

    @Test func countsDownAndCompletes() {
        let clock = ClockBox()
        let m = make(planned: 100, clock)
        m.start()
        #expect(m.isRunning)

        clock.advance(60); m.recompute()
        #expect(m.activeSecondsLive == 60)
        #expect(m.remainingSeconds == 40)
        #expect(!m.isCompleted)

        clock.advance(40); m.recompute()
        #expect(m.isCompleted)
        #expect(m.activeSecondsLive == 100)
        #expect(m.remainingSeconds == 0)
        #expect(m.progress == 1.0)
    }

    @Test func pauseStopsAccumulation() {
        let clock = ClockBox()
        let m = make(planned: 100, clock)
        m.start()
        clock.advance(30); m.recompute()
        m.pause()
        #expect(m.isPaused)

        clock.advance(500); m.recompute()   // 일시정지 동안 시간이 흘러도 누적 안 됨
        #expect(m.activeSecondsLive == 30)
        #expect(m.remainingSeconds == 70)
    }

    @Test func resumeContinuesFromAccumulated() {
        let clock = ClockBox()
        let m = make(planned: 100, clock)
        m.start()
        clock.advance(30); m.recompute()
        m.pause()
        clock.advance(1000)                  // 멈춰 있던 시간
        m.resume()
        clock.advance(20); m.recompute()
        #expect(m.activeSecondsLive == 50)   // 30 + 20
        #expect(!m.isCompleted)
    }

    @Test func stopResetsToIdle() {
        let clock = ClockBox()
        let m = make(planned: 100, clock)
        m.start()
        clock.advance(40); m.recompute()
        m.stop()
        #expect(m.isIdle)
        #expect(m.session == nil)
        #expect(m.activeSecondsLive == 0)
    }

    @Test func completesIfBackgroundedPastTarget() {
        let clock = ClockBox()
        let m = make(planned: 100, clock)
        m.start()
        clock.advance(250)                    // 백그라운드 장기 체류 시뮬레이션
        m.handleForeground()                  // 복귀 시 재계산
        #expect(m.isCompleted)
        #expect(m.activeSecondsLive == 100)   // 목표치로 캡
    }

    @Test func stageIndexTracksProgress() {
        let clock = ClockBox()
        let m = make(planned: 600, clock)     // 10분
        m.start()
        clock.advance(300); m.recompute()     // 50%
        #expect(m.stageIndex == 3)            // Int(0.5 * 6)
        #expect(m.stageCaption == "4/6")
    }

    @Test func plannedSecondsLockedWhileActive() {
        let clock = ClockBox()
        let m = make(planned: 100, clock)
        m.plannedSeconds = 200                // idle이라 변경 가능
        #expect(m.plannedSeconds == 200)
        m.start()
        m.plannedSeconds = 999                // 진행 중엔 무시
        #expect(m.plannedSeconds == 200)
    }
}
