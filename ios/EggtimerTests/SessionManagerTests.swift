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

    @Test func backgroundAutoPausesAndDoesNotCount() {
        let clock = ClockBox()
        let m = make(planned: 100, clock)
        m.start()
        clock.advance(40); m.recompute()      // 40초 집중
        m.handleBackground()                  // 앱 나감 → 자동 일시정지(누적 고정)
        clock.advance(600)                     // 백그라운드 장기 체류(전화/메신저)
        m.handleForeground()                  // 복귀
        #expect(!m.isCompleted)               // 백그라운드 시간은 카운트 안 됨 → 미완료
        #expect(m.activeSecondsLive == 40)    // 40초에서 정지
        #expect(m.isRunning)                  // 복귀 시 자동 재개
    }

    @Test func resumesFocusAfterForeground() {
        let clock = ClockBox()
        let m = make(planned: 100, clock)
        m.start()
        clock.advance(40); m.recompute()
        m.handleBackground()
        clock.advance(600)
        m.handleForeground()                  // 재개
        clock.advance(30); m.recompute()      // 이어서 30초 더
        #expect(m.activeSecondsLive == 70)    // 40 + 30 (백그라운드 600초 제외)
    }

    @Test func completesIfForegroundPastTarget() {
        let clock = ClockBox()
        let m = make(planned: 100, clock)
        m.start()
        clock.advance(250); m.recompute()     // 포그라운드 유지 시 목표 도달
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

    // MARK: - 포모도로

    private func makePomodoro(_ clock: ClockBox) -> SessionManager {
        let m = SessionManager(plannedSeconds: 100, clock: { clock.now }, persists: false)
        m.mode = .pomodoro
        return m
    }

    @Test func pomodoroEntersBreakAfterFocusBlock() {
        let clock = ClockBox()
        let m = makePomodoro(clock)
        m.start()
        #expect(m.isRunning)
        clock.advance(PomodoroConfig.focusBlock); m.recompute()
        #expect(m.isOnBreak)
        #expect(!m.isRunning)                 // 휴식 중엔 집중 아님
    }

    @Test func pomodoroSkipBreakResumesFocus() {
        let clock = ClockBox()
        let m = makePomodoro(clock)
        m.start()
        clock.advance(PomodoroConfig.focusBlock); m.recompute()
        #expect(m.isOnBreak)
        m.skipBreak()
        #expect(!m.isOnBreak)
        #expect(m.isRunning)
    }

    @Test func pomodoroBreakAutoEndsAndAccumulationFreezesDuringBreak() {
        let clock = ClockBox()
        let m = makePomodoro(clock)
        m.start()
        clock.advance(PomodoroConfig.focusBlock); m.recompute()   // → 휴식
        #expect(m.isOnBreak)
        clock.advance(PomodoroConfig.breakLength + 1); m.recompute()  // 휴식 자동 종료
        #expect(!m.isOnBreak)
        #expect(m.isRunning)
        #expect(m.activeSecondsLive == PomodoroConfig.focusBlock)  // 휴식 동안 누적 동결
        clock.advance(3); m.recompute()
        #expect(m.activeSecondsLive == PomodoroConfig.focusBlock + 3)  // 재개 후 다시 누적
    }

    @Test func pomodoroHatchesAtCumulativeThreshold() {
        let clock = ClockBox()
        let m = makePomodoro(clock)
        m.start()
        var steps = 0
        while !m.isCompleted && steps < PomodoroConfig.hatchThreshold * 4 {
            if m.isOnBreak { m.skipBreak() }   // 휴식은 건너뛰며 집중만 누적
            clock.advance(1); m.recompute()
            steps += 1
        }
        #expect(m.isCompleted)
        #expect(m.activeSecondsLive == PomodoroConfig.hatchThreshold)  // 누적 1시간(컨셉)에 부화
    }
}
