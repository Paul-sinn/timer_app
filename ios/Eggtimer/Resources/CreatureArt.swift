//
//  CreatureArt.swift
//  Eggtimer
//
//  "변형 에셋명 × 진화 단계 × 모션 프레임" → 실제 에셋명을 푸는 단일 진실 소스.
//  화면(홈/컬렉션/부화 시트)마다 문자열을 흩뿌리지 않고 전부 여기를 거친다.
//
//  닭 5종만 3단계 진화 아트 + 2프레임 모션을 가진다(angry/annoyed/sleepy/smart/bro).
//  Chicken1(귀여운 토종닭)·슬라임·공룡 등 나머지는 애니메이션 세트가 없어 기존 단일
//  이미지를 그대로 쓴다 → `animatedAssetName`이 nil을 돌려주고 호출부가 폴백한다.
//
//  에셋 이름 규칙: `{변형명}Stage{1…3}{Idle|Action}`  예) ChickenBroStage3Action
//  원본 PNG는 images/final-character/{character}/ 에 보관하고, 런타임 에셋은
//  배경 제거 + 캐릭터별 공통 캔버스(bottom-center 정렬)로 가공해 Assets.xcassets에 넣는다.
//  → 한 캐릭터의 6프레임은 캔버스 크기·종횡비가 완전히 같아서 aspect fit만으로
//    idle/action 전환은 물론 단계 전환에서도 크기·위치가 튀지 않는다.
//

import CoreGraphics

/// 2프레임 모션의 한 프레임.
nonisolated enum CreatureMotionFrame: String, CaseIterable, Sendable {
    case idle       // 기본 자세(조금 길게)
    case action     // 동작 자세(짧게)

    /// 에셋 이름에 들어가는 접미사("Idle"/"Action").
    var suffix: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

/// 한 캐릭터·단계의 모션 타이밍.
nonisolated struct CreatureMotionTiming: Equatable, Sendable {
    /// idle 프레임 노출 시간(초).
    let idle: Double
    /// action 프레임 노출 시간(초).
    let action: Double
    /// action 프레임에서 위로 띄우는 양(pt). 픽셀 리샘플이 생기는 스케일 대신 정수 오프셋만 쓴다.
    let lift: CGFloat

    var period: Double { idle + action }
}

nonisolated enum CreatureArt {

    /// 진화 아트가 가진 단계 수(1…3).
    static let artStageCount = 3

    /// 변형 에셋명 → 에셋 접두사.
    ///
    /// 도감 12폼 전부 3단계 아트를 가진다. 백호·피닉스는 최종 단계에서
    /// `Creature.displayImageName`이 `...Evolved` 이름을 돌려주므로, 그 이름도
    /// 같은 세트로 이어 붙인다(그래야 최종 진화도 모션이 살아있다).
    private static let assetPrefix: [String: String] = [
        "ChickenAngry":      "ChickenAngry",
        "ChickenAnnoyed":    "ChickenAnnoyed",
        "ChickenSleepy":     "ChickenSleepy",
        "ChickenSmart":      "ChickenSmart",
        "ChickenBro":        "ChickenBro",
        "Chicken1":          "Chicken1",
        "Slime":             "Slime",
        "Dino":              "Dino",
        "BlackCat":          "BlackCat",
        "GoldChick":         "GoldChick",
        "WhiteTiger":        "WhiteTiger",
        "WhiteTigerEvolved": "WhiteTiger",
        "Phoenix":           "Phoenix",
        "PhoenixEvolved":    "Phoenix",
    ]

    /// 3단계 진화 아트를 가진 폼(도감 12폼). 진화 전용 별칭은 제외 — 검수 갤러리·테스트용.
    static let animatedBases: [String] = [
        "ChickenAngry", "ChickenAnnoyed", "ChickenSleepy", "ChickenSmart", "ChickenBro",
        "Chicken1", "Slime", "Dino", "BlackCat", "GoldChick", "WhiteTiger", "Phoenix",
    ]

    /// 게임 진화 단계(0…`Creature.maxEvolutionStage`=2) → 아트 단계(1…3) 대응표.
    ///
    /// 게임 단계 3칸(갓 부화 0 · 진화 1 · 최종 2)이 아트 3단계와 1:1로 맞는다.
    /// → **진화할 때마다 그림이 실제로 바뀐다**(보상감). 겹치는 단계가 없다.
    private static let stageMap = [1, 2, 3]

    /// 게임 진화 단계를 아트 단계(1…3)로 변환.
    static func artStage(forEvolutionStage stage: Int) -> Int {
        stageMap[min(max(stage, 0), stageMap.count - 1)]
    }

    /// 이 변형이 3단계 진화 아트를 가지는지.
    static func hasAnimatedSet(_ base: String) -> Bool {
        assetPrefix[base] != nil
    }

    /// 애니메이션 에셋명. 세트가 없는 변형이면 nil(호출부가 기존 단일 이미지로 폴백).
    /// - Parameter stage: 게임 진화 단계(0…3).
    static func animatedAssetName(base: String, stage: Int, frame: CreatureMotionFrame) -> String? {
        guard let prefix = assetPrefix[base] else { return nil }
        return "\(prefix)Stage\(artStage(forEvolutionStage: stage))\(frame.suffix)"
    }

    // MARK: - 모션 타이밍

    /// 성격이 드러나도록 캐릭터·단계별로 속도를 다르게 준다.
    /// 공통 원칙: **idle을 길게, action을 짧게** — 전 캐릭터 동일한 빠른 깜빡임을 피한다.
    /// 헬창닭 3단계(데드리프트)만 예외로 idle/action을 비슷하게 둬서 "들었다 놓는" 리듬을 만든다.
    static func timing(base: String, stage: Int) -> CreatureMotionTiming {
        let art = artStage(forEvolutionStage: stage)
        switch assetPrefix[base] ?? base {
        case "ChickenAngry":                       // 파닥거리는 성깔 — 짧고 스냅 있게
            return CreatureMotionTiming(idle: 0.62, action: 0.30, lift: 3)

        case "ChickenAnnoyed":                     // 시큰둥 — 가끔 툭 반응
            return CreatureMotionTiming(idle: 0.88, action: 0.36, lift: 2)

        case "ChickenSleepy":                      // 졸음 — 느릿한 호흡
            return CreatureMotionTiming(idle: 1.20, action: 0.55, lift: 1)

        case "ChickenSmart":                       // 책장 넘기는 템포
            return CreatureMotionTiming(idle: 0.92, action: 0.48, lift: 2)

        case "ChickenBro":
            // 3단계는 데드리프트: 준비 자세(idle) ↔ 락아웃(action)이 각각 0.4~0.6초씩
            // 또렷하게 보여야 해서 두 프레임 시간을 비슷하게 맞춘다.
            return art == 3
                ? CreatureMotionTiming(idle: 0.55, action: 0.50, lift: 3)
                : CreatureMotionTiming(idle: 0.72, action: 0.34, lift: 2)

        // 등급이 높을수록 조금 더 자주 살아 움직이게(전설이 가장 생기 있음).
        case "Chicken1":                           // 순한 토종닭 — 무던한 박자
            return CreatureMotionTiming(idle: 0.85, action: 0.40, lift: 2)

        case "Slime":                              // 말랑 — 느리게 출렁
            return CreatureMotionTiming(idle: 0.95, action: 0.45, lift: 1)

        case "Dino":                               // 아기 공룡 — 통통
            return CreatureMotionTiming(idle: 0.75, action: 0.40, lift: 2)

        case "BlackCat":                           // 고양이 — 뜸들이다 훅
            return CreatureMotionTiming(idle: 0.90, action: 0.42, lift: 2)

        case "GoldChick":                          // 반짝임 — 가볍고 빠르게
            return CreatureMotionTiming(idle: 0.70, action: 0.35, lift: 3)

        case "WhiteTiger":
            return CreatureMotionTiming(idle: 0.68, action: 0.38, lift: 2)

        case "Phoenix":                            // 불꽃 — 쉼 없이 일렁
            return CreatureMotionTiming(idle: 0.60, action: 0.36, lift: 3)

        default:
            return CreatureMotionTiming(idle: 0.80, action: 0.35, lift: 2)
        }
    }

    /// 여러 캐릭터가 한 화면에 있을 때 완전히 같은 박자로 움직이면 기계적으로 보인다.
    /// 이름에서 결정적으로 뽑은 0…1 위상으로 살짝 어긋나게 한다(런치마다 동일).
    static func phaseOffset(base: String, stage: Int) -> Double {
        let seed = base.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF } &+ stage &* 7
        return Double(seed % 1000) / 1000.0
    }
}
