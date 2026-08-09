//
//  FocusSessionState.swift
//  Eggtimer
//
//  진행 중인 집중 세션의 값 타입(Codable). 진실은 항상 "타임스탬프에서 재계산"한다.
//  - accumulatedActiveSeconds: 이전 running 구간들의 누적(Pause 보정).
//  - lastResumedAt: 현재 running 구간의 Start 시각(running일 때만 non-nil).
//  유효 집중초 = accumulated + (running이면 now - lastResumedAt), 목표치로 캡.
//  (FEATURE_DESIGN.md Feature 1)
//

import Foundation

enum SessionPhase: String, Codable {
    case running    // 집중 중
    case paused     // Pause
    case completed  // 목표 도달(부화 대기)
}

/// 타이머 모드. free=자유 타이머(선택 시간에 부화), pomodoro=25/5 사이클(누적 1시간에 부화).
enum TimerMode: String, Codable, CaseIterable {
    case free
    case pomodoro
}

struct ActiveSession: Codable, Equatable {
    let id: UUID
    /// 부화까지 누적되어야 하는 유효 집중초(= 알 목표). free=선택 시간, pomodoro=1시간.
    let plannedSeconds: Int
    let startedAt: Date
    var accumulatedActiveSeconds: Int
    var lastResumedAt: Date?
    var phase: SessionPhase
    /// 타이머 모드.
    var mode: TimerMode
    /// 포모도로 휴식 종료 시각(non-nil = On a break, 집중 누적 정지). 절대 시각이라 백그라운드/복원에 안전.
    var breakEndsAt: Date?
    /// 포모도로: Done한 집중 블록 수. 롱브레이크 4주기·현재 블록번호 판정.
    var completedBlocks: Int
    /// 현재 휴식이 롱브레이크(4번째 블록 뒤)인지. 표시·복원용.
    var currentBreakIsLong: Bool
    /// 이번 블록(사이클)의 부화/진화 보상이 이미 지급됐는지. 크래시·백그라운드 휴식종료 재진입 시 중복 지급 차단.
    var cycleRewardGranted: Bool

    init(id: UUID = UUID(), plannedSeconds: Int, startedAt: Date, phase: SessionPhase = .running,
         mode: TimerMode = .free) {
        self.id = id
        self.plannedSeconds = plannedSeconds
        self.startedAt = startedAt
        self.accumulatedActiveSeconds = 0
        self.lastResumedAt = phase == .running ? startedAt : nil
        self.phase = phase
        self.mode = mode
        self.breakEndsAt = nil
        self.completedBlocks = 0
        self.currentBreakIsLong = false
        self.cycleRewardGranted = false
    }

    /// On a break인지(포모도로).
    var isOnBreak: Bool { breakEndsAt != nil }

    /// 유효 집중초(목표치로 캡). 시계 역행은 0으로 무시(안티치트). On a break엔 누적만(running 보정 없음).
    func activeSeconds(now: Date) -> Int {
        var total = accumulatedActiveSeconds
        if phase == .running, !isOnBreak, let resumed = lastResumedAt {
            total += max(0, Int(now.timeIntervalSince(resumed)))
        }
        return min(total, plannedSeconds)
    }

    func remainingSeconds(now: Date) -> Int {
        max(plannedSeconds - activeSeconds(now: now), 0)
    }

    func isComplete(now: Date) -> Bool {
        activeSeconds(now: now) >= plannedSeconds
    }

    /// 0...1 진행도.
    func progress(now: Date) -> Double {
        guard plannedSeconds > 0 else { return 0 }
        return min(Double(activeSeconds(now: now)) / Double(plannedSeconds), 1)
    }
}
