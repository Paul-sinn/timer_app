//
//  DialogueCatalog.swift
//  Eggtimer
//
//  대사 정적 카탈로그(dialoguesystem.md). 알 풀(시작/경과분/복귀/스트릭) + 생명체 성격별 풀.
//  라인 본문은 스펙의 영어·풍자 톤을 그대로 사용. 추후 리모트 컨피그/현지화/AI 확장으로 교체 가능.
//

import Foundation

enum DialogueCatalog {

    // MARK: - 조립 헬퍼

    /// 한 (화자, 트리거) 풀의 텍스트 배열 → DialogueLine 배열.
    private static func pool(_ idPrefix: String, _ speaker: DialogueSpeaker,
                             _ trigger: DialogueTrigger, _ texts: [String],
                             cooldown: TimeInterval = 90) -> [DialogueLine] {
        texts.enumerated().map { i, t in
            DialogueLine(id: "\(idPrefix)_\(i)", text: t, speaker: speaker,
                         trigger: trigger, cooldown: cooldown)
        }
    }

    private static func creaturePool(_ p: CreaturePersonality, _ texts: [String]) -> [DialogueLine] {
        pool("creature_\(p.rawValue)", .creature(p), .greeting, texts, cooldown: 60)
    }

    // MARK: - 전체

    static let all: [DialogueLine] = egg + creatures

    /// 특정 성격의 등장 대사 풀(컬렉션 상세 등에서 한 줄 뽑아 쓰기).
    static func greetingLines(for personality: CreaturePersonality) -> [DialogueLine] {
        all.filter { $0.speaker == .creature(personality) && $0.trigger == .greeting }
    }

    // MARK: - 알 (의심 → 존중 → 자부심)

    static let egg: [DialogueLine] =
        // idle — 홈 대기(스펙 외 보강, 알의 의심꾼 톤 유지)
        pool("egg_idle", .egg, .idle, [
            "Back already? Let's see if you mean it.",
            "I'll be here. Doubting you. Quietly.",
            "Tap start. Impress me. Or don't.",
        ])
        // Session Start
        + pool("egg_start", .egg, .sessionStart, [
            "Let's see how long this lasts.",
            "Try not to disappear this time.",
            "Don't embarrass us.",
            "I have low expectations.",
            "Prove me wrong.",
            "Let's pretend you're productive.",
        ])
        // 5 Minutes
        + pool("egg_m5", .egg, .focusMilestone(minutes: 5), [
            "Oh? Still here?",
            "Interesting.",
            "You haven't quit yet.",
            "That's longer than I expected.",
            "I'm mildly impressed.",
            "Don't celebrate yet.",
        ])
        // 10 Minutes
        + pool("egg_m10", .egg, .focusMilestone(minutes: 10), [
            "Okay. Maybe you're serious.",
            "You're doing better than yesterday. Probably.",
            "Still focused? Suspicious.",
            "I was expecting a distraction by now.",
        ])
        // 15 Minutes
        + pool("egg_m15", .egg, .focusMilestone(minutes: 15), [
            "You're actually working. Weird.",
            "I owe you a tiny bit of respect.",
            "Don't let it get to your head.",
            "You're making this look easy. I don't like it.",
        ])
        // 30 Minutes
        + pool("egg_m30", .egg, .focusMilestone(minutes: 30), [
            "Something is happening inside this egg.",
            "I felt that. Keep going.",
            "The shell cracked a little. Not bad.",
            "You might actually hatch me.",
            "We're getting somewhere.",
        ])
        // 45 Minutes
        + pool("egg_m45", .egg, .focusMilestone(minutes: 45), [
            "This is getting serious.",
            "You're making me believe in you. Dangerous.",
            "Okay. That was impressive.",
            "Most people would've left by now.",
        ])
        // 60 Minutes
        + pool("egg_m60", .egg, .focusMilestone(minutes: 60), [
            "I can't even make fun of you anymore.",
            "You earned this.",
            "Fine. That was legendary.",
            "I'm proud of you. Don't tell anyone.",
        ])
        // Return Within 30 Seconds
        + pool("egg_r30s", .egg, .appReturn(.within30s), [
            "Bathroom break? I'll allow it.",
            "That was quick.",
            "You came back. Good.",
        ], cooldown: 20)
        // 30 Seconds - 3 Minutes
        + pool("egg_r3m", .egg, .appReturn(.upTo3min), [
            "Where exactly did you go?",
            "Checking messages again?",
            "I noticed.",
            "You're on thin ice.",
        ], cooldown: 20)
        // 3+ Minutes
        + pool("egg_r3plus", .egg, .appReturn(.upTo10min), [
            "Focus session. Remember?",
            "You got distracted, didn't you?",
            "That wasn't part of the plan.",
            "Should I be worried?",
        ], cooldown: 20)
        // 10+ Minutes
        + pool("egg_r10plus", .egg, .appReturn(.over10min), [
            "Are we studying or sightseeing?",
            "I've been waiting.",
            "That was a long side quest.",
            "Welcome back, traveler.",
        ], cooldown: 20)
        // 포모도로 휴식 진입(알 톤 유지)
        + pool("egg_break", .egg, .breakStart, [
            "Fine. Take five. Don't get comfortable.",
            "A break already? Bold.",
            "Rest. You earned a sliver of it.",
            "Five minutes. I'm counting.",
            "Stretch. Breathe. Then back to it.",
        ], cooldown: 30)
        // Streaks
        + pool("egg_streak3", .egg, .streak(days: 3), [
            "Three days? Lucky streak.",
            "Could be a coincidence.",
        ], cooldown: 0)
        + pool("egg_streak7", .egg, .streak(days: 7), [
            "Okay. This is becoming a habit.",
            "You might be onto something.",
        ], cooldown: 0)
        + pool("egg_streak30", .egg, .streak(days: 30), [
            "That's discipline.",
            "You're not the same person anymore.",
        ], cooldown: 0)
        + pool("egg_streak100", .egg, .streak(days: 100), [
            "This is ridiculous.",
            "You're basically a boss fight now.",
            "Legends start like this.",
        ], cooldown: 0)

    // MARK: - 생명체 성격별 (등장 인사)

    static let creatures: [DialogueLine] =
        creaturePool(.redChicken, [
            "About time.",
            "Look who's being productive.",
            "I didn't think you'd make it.",
            "Not terrible.",
            "Keep going, nerd.",
        ])
        + creaturePool(.sleepyChicken, [
            "Can we nap after this?",
            "I'm tired. You're tired. Let's keep going.",
            "Wake me up when we hatch.",
        ])
        + creaturePool(.nerdChicken, [
            "Productivity increased by 12%.",
            "Your focus metrics look excellent.",
            "Data suggests you're doing great.",
            "Statistically speaking, this is impressive.",
        ])
        + creaturePool(.gymChicken, [
            "Focus is a muscle.",
            "One more set.",
            "Mental gains.",
            "No excuses.",
        ])
        + creaturePool(.angryChicken, [
            "Focus. Now.",
            "Stop touching your phone.",
            "I swear...",
            "You're lucky I like you.",
        ])
        + creaturePool(.whiteTiger, [
            "Stay calm.",
            "Strength grows in silence.",
            "Continue.",
            "You are closer than you think.",
        ])
        + creaturePool(.phoenix, [
            "Another ember joins the fire.",
            "Your effort becomes flame.",
            "Rise again.",
            "Even ashes remember greatness.",
            "The fire within grows stronger.",
        ])
        // generic — 스펙 미정의 종 공용(온톤 보강)
        + creaturePool(.generic, [
            "Oh. It's you again.",
            "Let's get this over with.",
            "I'm rooting for you. Quietly.",
        ])
}
