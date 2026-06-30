//
//  CreatureSpecies.swift
//  Eggtimer
//
//  도감에 등장하는 7종 생명체의 단일 진실 소스(Single Source of Truth).
//  각 종의 등급·출현 가중치·이미지 에셋·진화 여부를 한곳에 정의한다.
//
//  부화는 2단계 추첨: ① 등급(Rarity.tierWeight, 합 100·불변) → ② 그 등급 안의 종(weight 상대가중).
//  → 새 종을 추가해도 다른 등급 확률이 안 바뀐다(해당 등급 내부만 재분배). 100% 안에서 자동 정규화.
//
//  확률표 (등급% × 등급 내 비중 = 실제 출현%)
//  ┌───────────┬──────┬──────────────┬──────────┬────────┐
//  │ 등급      │ 등급%│ 생명체       │ 등급내가중│ 실제%  │
//  ├───────────┼──────┼──────────────┼──────────┼────────┤
//  │ Common    │ 80%  │ 빨간 토종닭  │ 55       │ 55%    │  ← 여러 표정 중 랜덤
//  │           │      │ 슬라임       │ 25       │ 25%    │
//  │ Uncommon  │ 10%  │ 아기 공룡    │ 10       │ 10%    │
//  │ Rare      │  8%  │ 검은 고양이  │  5       │  5%    │
//  │           │      │ 황금 병아리  │  3       │  3%    │
//  │ Legendary │  2%  │ 백호         │  1       │  1%    │  ← 최종 단계서 진화
//  │           │      │ 피닉스       │  1       │  1%    │  ← 최종 단계서 진화
//  └───────────┴──────┴──────────────┴──────────┴────────┘
//

import Foundation

enum CreatureSpecies: String, CaseIterable, Identifiable {
    case chicken      // 빨간 토종닭
    case slime        // 슬라임
    case dino         // 아기 공룡
    case blackCat     // 검은 고양이
    case goldChick    // 황금 병아리
    case whiteTiger   // 백호
    case phoenix      // 피닉스

    var id: String { rawValue }

    /// 한글 표시 이름.
    var name: String {
        switch self {
        case .chicken:    return "빨간 토종닭"
        case .slime:      return "슬라임"
        case .dino:       return "아기 공룡"
        case .blackCat:   return "검은 고양이"
        case .goldChick:  return "황금 병아리"
        case .whiteTiger: return "백호"
        case .phoenix:    return "피닉스"
        }
    }

    var rarity: Rarity {
        switch self {
        case .chicken, .slime:        return .common
        case .dino:                   return .uncommon
        case .blackCat, .goldChick:   return .rare
        case .whiteTiger, .phoenix:   return .legendary
        }
    }

    /// 같은 등급 안에서의 상대 출현 가중치. (전역 합 100일 필요 없음 — 등급별 합으로만 정규화)
    /// 실제 출현 확률 = `rarity.tierWeight%` × (이 weight / 같은 등급 weight 합).
    /// 예) Common 등급(80%) 안에서 닭55:슬라임25 → 닭 55%, 슬라임 25%.
    var weight: Int {
        switch self {
        case .chicken:    return 55
        case .slime:      return 25
        case .dino:       return 10
        case .blackCat:   return 5
        case .goldChick:  return 3
        case .whiteTiger: return 1
        case .phoenix:    return 1
        }
    }

    /// 기본(미진화) 이미지 변형 풀. 빨간 토종닭은 여러 표정 중 하나가 랜덤으로 출현한다.
    var imageVariants: [String] {
        switch self {
        case .chicken:
            return ["Chicken1", "ChickenAngry", "ChickenAnnoyed",
                    "ChickenBro", "ChickenSleepy", "ChickenSmart"]
        case .slime:      return ["Slime"]
        case .dino:       return ["Dino"]
        case .blackCat:   return ["BlackCat"]
        case .goldChick:  return ["GoldChick"]
        case .whiteTiger: return ["WhiteTiger"]
        case .phoenix:    return ["Phoenix"]
        }
    }

    /// 진화 후 이미지. 진화하지 않는 종은 nil.
    var evolvedImageName: String? {
        switch self {
        case .whiteTiger: return "WhiteTigerEvolved"
        case .phoenix:    return "PhoenixEvolved"
        default:          return nil
        }
    }

    /// 변형(표정)별 도감 이름. 단일 변형 종은 종 이름 그대로.
    /// 빨간 토종닭은 표정마다 다른 이름으로 따로 수집된다(질림 방지 + 컬렉션 재미).
    func variantName(imageName: String) -> String {
        switch imageName {
        case "Chicken1":       return "빨간 토종닭"
        case "ChickenAnnoyed": return "심통난 토종닭"
        case "ChickenSleepy":  return "잠꾸러기 토종닭"
        case "ChickenSmart":   return "공부벌레 토종닭"
        case "ChickenBro":     return "헬스 토종닭"
        case "ChickenAngry":   return "버럭 토종닭"
        default:               return name
        }
    }

    /// 실루엣(미발견 표시)에 사용할 대표 이미지.
    var silhouetteImageName: String { imageVariants.first ?? rawValue }

    /// 변형 풀에서 무작위로 한 이미지를 고른다.
    func randomVariant<G: RandomNumberGenerator>(using generator: inout G) -> String {
        imageVariants.randomElement(using: &generator) ?? silhouetteImageName
    }

    /// 성격별 대사 풀 식별자(dialoguesystem.md). 닭은 표정 변형(imageName)이 성격에 대응한다.
    func personality(imageName: String) -> CreaturePersonality {
        switch self {
        case .chicken:
            switch imageName {
            case "ChickenSleepy": return .sleepyChicken
            case "ChickenSmart":  return .nerdChicken
            case "ChickenBro":    return .gymChicken
            case "ChickenAngry":  return .angryChicken
            default:              return .redChicken   // Chicken1, ChickenAnnoyed
            }
        case .whiteTiger: return .whiteTiger
        case .phoenix:    return .phoenix
        case .slime, .dino, .blackCat, .goldChick: return .generic
        }
    }

    // MARK: - 2단계 가중 추첨 (등급 → 종)

    /// 한 종을 뽑는다: ① 등급(`Rarity.tierWeight`, 합 100) ② 그 등급 안의 종(`weight` 상대가중).
    /// 주입형 RNG로 테스트 가능. **새 종을 추가해도 다른 등급의 확률은 불변**(해당 등급 내부만 재분배).
    static func roll<G: RandomNumberGenerator>(using generator: inout G) -> CreatureSpecies {
        let rarity = rollRarity(using: &generator)
        let pool = allCases.filter { $0.rarity == rarity }
        return weightedPick(pool, using: &generator) ?? allCases[0]
    }

    /// 1단계: 등급 추첨(tierWeight 가중, 전 등급 합 100).
    private static func rollRarity<G: RandomNumberGenerator>(using generator: inout G) -> Rarity {
        let total = Rarity.allCases.reduce(0) { $0 + $1.tierWeight }
        var ticket = Int.random(in: 0..<total, using: &generator)
        for r in Rarity.allCases {
            if ticket < r.tierWeight { return r }
            ticket -= r.tierWeight
        }
        return .common // 도달 불가(합 보장)
    }

    /// 2단계: 같은 등급 종 풀에서 weight 가중으로 하나 선택.
    private static func weightedPick<G: RandomNumberGenerator>(_ pool: [CreatureSpecies], using generator: inout G) -> CreatureSpecies? {
        guard !pool.isEmpty else { return nil }
        let total = pool.reduce(0) { $0 + max(1, $1.weight) }
        var ticket = Int.random(in: 0..<total, using: &generator)
        for s in pool {
            let w = max(1, s.weight)
            if ticket < w { return s }
            ticket -= w
        }
        return pool.last
    }

    /// 시스템 RNG로 한 종을 뽑는 편의 메서드.
    static func roll() -> CreatureSpecies {
        var generator = SystemRandomNumberGenerator()
        return roll(using: &generator)
    }
}

/// 도감 수집 단위(폼). 같은 종이라도 이미지 변형마다 별도 칸으로 모은다.
/// 닭은 6표정 → 6폼, 나머지 종은 변형 1개 → 1폼. (총 12폼)
struct CreatureForm: Identifiable, Hashable {
    let species: CreatureSpecies
    /// 변형 이미지명(폼 고유 식별자 역할).
    let imageName: String

    var id: String { imageName }
    var name: String { species.variantName(imageName: imageName) }
    var rarity: Rarity { species.rarity }

    /// 도감에 등장하는 전체 폼. allCases 선언 순서가 이미 등급 오름차순(common→legendary)이라
    /// 별도 정렬 없이 그대로 등급순 + 변형 선언순이 유지된다.
    static var all: [CreatureForm] {
        CreatureSpecies.allCases.flatMap { sp in
            sp.imageVariants.map { CreatureForm(species: sp, imageName: $0) }
        }
    }
}
