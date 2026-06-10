//
//  CreatureSpecies.swift
//  Eggtimer
//
//  도감에 등장하는 7종 생명체의 단일 진실 소스(Single Source of Truth).
//  각 종의 등급·출현 확률(가중치)·이미지 에셋·진화 여부를 한곳에 정의한다.
//  알 부화 시 이 가중치표에 따라 랜덤으로 한 종이 뽑힌다.
//
//  확률표
//  ┌───────────┬──────────────┬──────┐
//  │ 등급      │ 생명체       │ 확률 │
//  ├───────────┼──────────────┼──────┤
//  │ Common    │ 빨간 토종닭  │ 55%  │  ← 여러 표정 중 랜덤
//  │ Common    │ 슬라임       │ 25%  │
//  │ Uncommon  │ 아기 공룡    │ 10%  │
//  │ Rare      │ 검은 고양이  │  5%  │
//  │ Rare      │ 황금 병아리  │  3%  │
//  │ Legendary │ 백호         │  1%  │  ← 20분 뒤 진화
//  │ Legendary │ 피닉스       │  1%  │  ← 20분 뒤 진화
//  └───────────┴──────────────┴──────┘
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

    /// 출현 가중치(%) — 전체 합 100.
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

    /// 실루엣(미발견 표시)에 사용할 대표 이미지.
    var silhouetteImageName: String { imageVariants.first ?? rawValue }

    /// 변형 풀에서 무작위로 한 이미지를 고른다.
    func randomVariant<G: RandomNumberGenerator>(using generator: inout G) -> String {
        imageVariants.randomElement(using: &generator) ?? silhouetteImageName
    }

    // MARK: - 가중 랜덤 추첨

    /// 확률표(weight)에 따라 한 종을 뽑는다. 주입형 RNG로 테스트 가능.
    static func roll<G: RandomNumberGenerator>(using generator: inout G) -> CreatureSpecies {
        let total = allCases.reduce(0) { $0 + $1.weight }
        var ticket = Int.random(in: 0..<total, using: &generator)
        for species in allCases {
            if ticket < species.weight { return species }
            ticket -= species.weight
        }
        return allCases[0] // 도달 불가(가중치 합 보장)
    }

    /// 시스템 RNG로 한 종을 뽑는 편의 메서드.
    static func roll() -> CreatureSpecies {
        var generator = SystemRandomNumberGenerator()
        return roll(using: &generator)
    }
}
