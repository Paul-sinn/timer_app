//
//  DialogueCatalog.swift
//  Eggtimer
//
//  대사 정적 카탈로그(Feature 4 MVP). 추후 리모트 컨피그/현지화로 교체 가능.
//

import Foundation

enum DialogueCatalog {
    static let all: [DialogueLine] = [
        // idle — 홈 대기
        .init(id: "idle_start",   text: "오늘도 집중해볼까요?", trigger: .idle),
        .init(id: "idle_egg",     text: "알이 부화를 기다리고 있어요 🥚", trigger: .idle),
        .init(id: "idle_ready",   text: "준비되면 시작을 눌러요!", trigger: .idle),
        .init(id: "idle_cozy",    text: "잠깐, 숨 한번 고르고 시작해요.", trigger: .idle, weight: 6),

        // focusing — 집중 중
        .init(id: "focus_good",   text: "잘하고 있어요!", trigger: .focusing),
        .init(id: "focus_more",   text: "조금만 더 집중!", trigger: .focusing),
        .init(id: "focus_warm",   text: "알이 따뜻해지고 있어요...", trigger: .focusing),
        .init(id: "focus_feel",   text: "당신의 집중이 느껴져요 ✨", trigger: .focusing),
        .init(id: "focus_keep",   text: "이 페이스 그대로!", trigger: .focusing, weight: 6),

        // appReturn — 복귀
        .init(id: "back_welcome", text: "돌아왔네요! 다시 시작해요", trigger: .appReturn),
        .init(id: "back_hi",      text: "어서 와요 👋", trigger: .appReturn),
        .init(id: "back_wait",    text: "기다리고 있었어요!", trigger: .appReturn),

        // sessionComplete — 완료/부화
        .init(id: "done_yay",     text: "해냈어요! 🎉", trigger: .sessionComplete),
        .init(id: "done_proud",   text: "집중 완료! 자랑스러워요", trigger: .sessionComplete),
        .init(id: "done_friend",  text: "새 친구가 태어났어요!", trigger: .sessionComplete),
        .init(id: "done_streak3", text: "3일 연속이라니, 멋져요! 🔥", trigger: .sessionComplete,
              weight: 20, minStreak: 3),
        .init(id: "done_streak7", text: "일주일 연속 집중! 대단해요 🏆", trigger: .sessionComplete,
              weight: 30, minStreak: 7)
    ]
}
