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

    // MARK: - 포모도로 (블록 체인: 집중 → 휴식 → 휴식 끝에 보상 1회 → 다음 블록)

    private func makePomodoro(_ clock: ClockBox) -> SessionManager {
        let m = SessionManager(plannedSeconds: 100, clock: { clock.now }, persists: false)
        m.mode = .pomodoro
        return m
    }

    /// 한 블록을 끝까지 진행(집중 완료 → 휴식 → 휴식 종료 보상 → 다음 블록 시작). 반환: 이번이 롱브레이크였는지.
    @discardableResult
    private func runOneBlock(_ m: SessionManager, _ clock: ClockBox) -> Bool {
        clock.advance(PomodoroConfig.focusBlock); m.recompute()          // 집중 완료 → 휴식
        let wasLong = m.isLongBreak
        let breakLen = wasLong ? PomodoroConfig.longBreakLength : PomodoroConfig.breakLength
        clock.advance(breakLen + 1); m.recompute()                       // 휴식 종료 → 보상(.completed)
        m.startNextBlock()                                               // 다음 블록
        return wasLong
    }

    @Test func pomodoroEntersShortBreakAfterFirstBlock() {
        let clock = ClockBox()
        let m = makePomodoro(clock)
        m.start()
        #expect(m.isRunning)
        clock.advance(PomodoroConfig.focusBlock); m.recompute()
        #expect(m.isOnBreak)
        #expect(!m.isRunning)          // 휴식 중엔 집중 아님
        #expect(!m.isLongBreak)        // 1블록째 → 짧은 휴식
        #expect(!m.isCompleted)        // 보상은 휴식 끝에 → 아직 미지급
    }

    @Test func pomodoroGrantsRewardExactlyOnceWhenBreakEnds() {
        let clock = ClockBox()
        let m = makePomodoro(clock)
        var rewards = 0
        m.onSessionEnd = { r in if r.completed { rewards += 1 } }
        m.start()
        clock.advance(PomodoroConfig.focusBlock); m.recompute()          // → 휴식
        #expect(rewards == 0)                                            // 휴식 자체는 보상 X
        clock.advance(PomodoroConfig.breakLength + 1); m.recompute()     // 휴식 종료 → 보상
        #expect(m.isCompleted)
        #expect(rewards == 1)
        // 재진입(추가 recompute)해도 재지급 없음(cycleRewardGranted 가드).
        clock.advance(5); m.recompute()
        clock.advance(5); m.recompute()
        #expect(rewards == 1)
    }

    @Test func pomodoroSkipBreakGrantsRewardImmediately() {
        let clock = ClockBox()
        let m = makePomodoro(clock)
        var rewards = 0
        m.onSessionEnd = { r in if r.completed { rewards += 1 } }
        m.start()
        clock.advance(PomodoroConfig.focusBlock); m.recompute()          // → 휴식
        #expect(m.isOnBreak)
        m.skipBreak()
        #expect(m.isCompleted)
        #expect(rewards == 1)
    }

    @Test func pomodoroStartNextBlockResetsFocus() {
        let clock = ClockBox()
        let m = makePomodoro(clock)
        m.start()
        clock.advance(PomodoroConfig.focusBlock); m.recompute()
        clock.advance(PomodoroConfig.breakLength + 1); m.recompute()     // 보상
        #expect(m.isCompleted)
        m.startNextBlock()
        #expect(m.isRunning)
        #expect(m.activeSecondsLive == 0)                                // 새 블록은 0부터
        #expect(m.pomodoroBlock == 2)                                    // 완료 1블록 + 1
        clock.advance(3); m.recompute()
        #expect(m.activeSecondsLive == 3)
    }

    @Test func pomodoroLongBreakEveryFourthBlock() {
        let clock = ClockBox()
        let m = makePomodoro(clock)
        m.start()
        #expect(runOneBlock(m, clock) == false)   // 1블록 → 짧은
        #expect(runOneBlock(m, clock) == false)   // 2블록 → 짧은
        #expect(runOneBlock(m, clock) == false)   // 3블록 → 짧은
        #expect(runOneBlock(m, clock) == true)    // 4블록 → 롱브레이크
        #expect(runOneBlock(m, clock) == false)   // 5블록 → 다시 짧은
    }

    @Test func pomodoroRewardFiresPerBlock() {
        let clock = ClockBox()
        let m = makePomodoro(clock)
        var rewards = 0
        m.onSessionEnd = { r in if r.completed { rewards += 1 } }
        m.start()
        for _ in 0..<4 { runOneBlock(m, clock) }
        #expect(rewards == 4)   // 블록마다 보상 정확히 1회 (누적 아님)
    }
}
