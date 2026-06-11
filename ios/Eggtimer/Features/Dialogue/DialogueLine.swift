//
//  DialogueLine.swift
//  Eggtimer
//
//  캐릭터 한마디(Feature 4 · dialoguesystem.md). 화자(알/생명체 성격) × 트리거(맥락)별 풀에서
//  가중 랜덤 + 비반복 + 쿨다운으로 고른다.
//
//  설계 의도(dialoguesystem.md): 앱을 "살아있게" 만든다. 알은 장난스러운 의심꾼으로 시작해
//  집중 시간·연속일이 쌓일수록 의심 → 존중 → 자부심으로 톤이 진화한다. 생명체는 성격별로 말한다.
//  영어·풍자 톤의 라인 본문은 현지화/AI 확장을 대비해 콘텐츠로 분리(카탈로그)한다.
//

import Foundation

/// 말하는 주체.
enum DialogueSpeaker: Equatable, Hashable, Sendable {
    case egg
    case creature(CreaturePersonality)
}

/// 생명체 성격(성격별 대사 풀 구분). 닭은 이미지 변형(표정)이 성격에 대응한다.
enum CreaturePersonality: String, CaseIterable, Sendable {
    case redChicken     // 빨간 토종닭(기본): 건방지고 친구처럼 놀림
    case sleepyChicken  // 졸린 닭: 저에너지
    case nerdChicken    // 똑똑한 닭: 통계/생산성 덕후
    case gymChicken     // 헬창 닭: 동기부여/규율
    case angryChicken   // 화난 닭: 츤데레
    case whiteTiger     // 백호: 차분한 멘토
    case phoenix        // 피닉스: 서사적/신화적
    case generic        // 스펙 미정의 종(슬라임·공룡·검은고양이·황금병아리) 공용
}

/// 앱 이탈 후 복귀까지의 시간 버킷(Interruption 임계값과 동일: 0–30s / 30s–3m / 3–10m / 10m+).
enum ReturnBucket: String, CaseIterable, Equatable, Hashable, Sendable {
    case within30s   // 0–30초
    case upTo3min    // 30초–3분
    case upTo10min   // 3–10분 ("3+ Minutes")
    case over10min   // 10분+

    static func from(awaySeconds: Int) -> ReturnBucket {
        switch awaySeconds {
        case ..<30:  return .within30s
        case ..<180: return .upTo3min
        case ..<600: return .upTo10min
        default:     return .over10min
        }
    }
}

/// 대사를 띄우는 맥락.
enum DialogueTrigger: Equatable, Hashable, Sendable {
    case idle                          // 홈 대기
    case sessionStart                  // 세션 시작
    case focusMilestone(minutes: Int)  // 집중 경과 분(5·10·15·30·45·60)
    case appReturn(ReturnBucket)       // 복귀(이탈 시간 버킷)
    case streak(days: Int)             // 연속일 도달(3·7·30·100)
    case greeting                      // 생명체 등장 인사(부화/컬렉션)
}

struct DialogueLine: Identifiable, Equatable, Sendable {
    let id: String
    let text: String
    let speaker: DialogueSpeaker
    let trigger: DialogueTrigger
    /// 가중치(높을수록 자주).
    let weight: Int
    /// 같은 줄 재등장 최소 간격(초).
    let cooldown: TimeInterval

    init(id: String, text: String, speaker: DialogueSpeaker = .egg,
         trigger: DialogueTrigger, weight: Int = 10, cooldown: TimeInterval = 90) {
        self.id = id
        self.text = text
        self.speaker = speaker
        self.trigger = trigger
        self.weight = weight
        self.cooldown = cooldown
    }
}
