//
//  CreatureSpecies.swift
//  Eggtimer
//
//  도감에 등장하는 생명체의 단일 진실 소스(Single Source of Truth).
//  각 종의 소속 월드·등급·출현 가중치·이미지 에셋·진화 여부를 한곳에 정의한다.
//  월드별 등급 확률·추첨 규칙은 `World`(docs/CREATURES.md). 아래 표는 기본 월드.
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
    // 크리스마스 월드. rawValue는 DB에 저장되므로 출시 후 바꾸지 말 것(WorldTests가 고정).
    case redNosePenguin   // 빨간코 펭귄
    case santaPenguin     // 산타 펭귄
    case elfPenguin       // 엘프 펭귄
    case giftBoxPenguin   // 선물상자 펭귄
    case snowmanSlime     // 눈사람 슬라임
    case littleEmber      // 꼬마 불씨
    case arcticFox        // 북극여우
    case gingerbreadChick // 진저브레드 병아리
    case snowyOwl         // 눈올빼미
    case polarBear        // 북극곰(간판)

    var id: String { rawValue }

    /// 소속 월드(어느 알에서 나오는지).
    var world: World {
        switch self {
        case .chicken, .slime, .dino, .blackCat, .goldChick, .whiteTiger, .phoenix:
            return .classic
        case .redNosePenguin, .santaPenguin, .elfPenguin, .giftBoxPenguin,
             .snowmanSlime, .littleEmber, .arcticFox, .gingerbreadChick, .snowyOwl, .polarBear:
            return .christmas
        }
    }

    /// 표시 이름.
    var name: String {
        switch self {
        case .chicken:    return String(localized: "Red Hen")
        case .slime:      return String(localized: "Slime")
        case .dino:       return String(localized: "Baby Dino")
        case .blackCat:   return String(localized: "Black Cat")
        case .goldChick:  return String(localized: "Golden Chick")
        case .whiteTiger: return String(localized: "White Tiger")
        case .phoenix:    return String(localized: "Phoenix")
        case .redNosePenguin:   return String(localized: "Red-Nose Penguin")
        case .santaPenguin:     return String(localized: "Santa Penguin")
        case .elfPenguin:       return String(localized: "Elf Penguin")
        case .giftBoxPenguin:   return String(localized: "Gift Box Penguin")
        case .snowmanSlime:     return String(localized: "Snowman Slime")
        case .littleEmber:      return String(localized: "Little Ember")
        case .arcticFox:        return String(localized: "Arctic Fox")
        case .gingerbreadChick: return String(localized: "Gingerbread Chick")
        case .snowyOwl:         return String(localized: "Snowy Owl")
        case .polarBear:        return String(localized: "Polar Bear")
        }
    }

    var rarity: Rarity {
        switch self {
        case .chicken, .slime:        return .common
        case .dino:                   return .uncommon
        case .blackCat, .goldChick:   return .rare
        case .whiteTiger, .phoenix:   return .legendary
        case .redNosePenguin, .santaPenguin, .elfPenguin, .giftBoxPenguin: return .common
        case .snowmanSlime, .littleEmber, .arcticFox:                      return .uncommon
        case .gingerbreadChick, .snowyOwl:                                 return .rare
        case .polarBear:                                                   return .legendary
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
        // 크리스마스: 등급 안 균등(1마리당 12·10·8·6%).
        case .redNosePenguin, .santaPenguin, .elfPenguin, .giftBoxPenguin,
             .snowmanSlime, .littleEmber, .arcticFox, .gingerbreadChick, .snowyOwl, .polarBear:
            return 1
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
        case .redNosePenguin:   return ["RedNosePenguin"]
        case .santaPenguin:     return ["SantaPenguin"]
        case .elfPenguin:       return ["ElfPenguin"]
        case .giftBoxPenguin:   return ["GiftBoxPenguin"]
        case .snowmanSlime:     return ["SnowmanSlime"]
        case .littleEmber:      return ["LittleEmber"]
        case .arcticFox:        return ["ArcticFox"]
        case .gingerbreadChick: return ["GingerbreadChick"]
        case .snowyOwl:         return ["SnowyOwl"]
        case .polarBear:        return ["PolarBear"]
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
        case "Chicken1":       return String(localized: "Red Hen")
        case "ChickenAnnoyed": return String(localized: "Grumpy Hen")
        case "ChickenSleepy":  return String(localized: "Sleepy Hen")
        case "ChickenSmart":   return String(localized: "Bookworm Hen")
        case "ChickenBro":     return String(localized: "Buff Hen")
        case "ChickenAngry":   return String(localized: "Angry Hen")
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
        case .slime:      return .slime
        case .dino:       return .dino
        case .blackCat:   return .blackCat
        case .goldChick:  return .goldChick
        case .redNosePenguin:   return .redNosePenguin
        case .santaPenguin:     return .santaPenguin
        case .elfPenguin:       return .elfPenguin
        case .giftBoxPenguin:   return .giftBoxPenguin
        case .snowmanSlime:     return .snowmanSlime
        case .littleEmber:      return .littleEmber
        case .arcticFox:        return .arcticFox
        case .gingerbreadChick: return .gingerbreadChick
        case .snowyOwl:         return .snowyOwl
        case .polarBear:        return .polarBear
        }
    }

    // MARK: - 2단계 가중 추첨 (등급 → 종)

    /// 한 종을 뽑는다: ① 등급(`Rarity.tierWeight`, 합 100) ② 그 등급 안의 종(`weight` 상대가중).
    /// 주입형 RNG로 테스트 가능. **새 종을 추가해도 다른 등급의 확률은 불변**(해당 등급 내부만 재분배).
    /// 기본 월드 전용(하위호환). 월드를 고르려면 `rollForm(in:draws:counts:using:)`.
    static func roll<G: RandomNumberGenerator>(using generator: inout G) -> CreatureSpecies {
        roll(draws: 1, using: &generator)
    }

    /// best-of-N 추첨: 등급을 `draws`번 굴려 **최고 등급**을 채택한 뒤, 그 등급 안에서 종을 뽑는다.
    /// 집중 길이 보상(FocusReward)이 이 draw 횟수로만 작동한다 — 등급/종 weight는 그대로.
    /// draws=1이면 기존 단일 추첨과 완전히 동일(하위호환). 기본 월드 전용.
    static func roll<G: RandomNumberGenerator>(draws: Int, using generator: inout G) -> CreatureSpecies {
        let allowed = World.classic.forms
        return pickSpecies(tier: bestTier(.classic, allowed, draws: draws, using: &generator),
                           .classic, allowed, using: &generator)
    }

    /// 월드 규칙대로 도감 한 칸을 뽑는다. `counts` = 이미 가진 칸별 개수(imageName → 개수).
    /// - 기본 규칙: 등급 best-of-N → 등급 안 종 → 변형. 기본 월드는 기존 부화와 난수 소비까지 같다.
    /// - `prefersUndiscovered`: 칸 단위로 `draws`번 굴려 **아직 없는 칸**을(그중 등급 높은 것) 먼저 준다.
    /// - `repeatCap`: 도감 미완성 동안 천장에 닿은 칸은 후보에서 빠진다(남은 칸끼리 비중대로).
    static func rollForm<G: RandomNumberGenerator>(in world: World, draws: Int,
                                                   counts: [String: Int] = [:],
                                                   using generator: inout G) -> CreatureForm {
        let allowed = world.drawableForms(counts: counts)
        guard world.prefersUndiscovered else {
            let tier = bestTier(world, allowed, draws: draws, using: &generator)
            return pickForm(tier: tier, world, allowed, using: &generator)
        }
        let results = (0..<max(1, draws)).map { _ in
            pickForm(tier: rollTier(world, allowed, using: &generator), world, allowed, using: &generator)
        }
        let fresh = results.filter { counts[$0.imageName, default: 0] == 0 }
        let pool = fresh.isEmpty ? results : fresh
        // max(by:)는 동률이면 앞의 것을 유지한다(기존 best-of-N과 같은 규칙).
        return pool.max { $0.rarity < $1.rarity } ?? results[0]
    }

    /// 등급을 draws번 굴려 가장 높은 등급(최소 1번).
    private static func bestTier<G: RandomNumberGenerator>(_ world: World, _ allowed: [CreatureForm],
                                                          draws: Int, using generator: inout G) -> Rarity {
        var best = rollTier(world, allowed, using: &generator)
        for _ in 1..<max(1, draws) {
            let r = rollTier(world, allowed, using: &generator)
            if r > best { best = r }
        }
        return best
    }

    /// 1단계: 후보 칸이 남은 등급만으로 월드 등급 확률 가중 추첨.
    private static func rollTier<G: RandomNumberGenerator>(_ world: World, _ allowed: [CreatureForm],
                                                          using generator: inout G) -> Rarity {
        let tiers = Rarity.allCases.filter { r in allowed.contains { $0.rarity == r } }
        let total = tiers.reduce(0) { $0 + world.tierWeight($1) }
        guard total > 0 else { return tiers.first ?? .common }
        var ticket = Int.random(in: 0..<total, using: &generator)
        for r in tiers {
            if ticket < world.tierWeight(r) { return r }
            ticket -= world.tierWeight(r)
        }
        return tiers.last ?? .common // 도달 불가(합 보장)
    }

    /// 2단계: 그 등급의 후보 종 중 weight 가중으로 하나.
    private static func pickSpecies<G: RandomNumberGenerator>(tier: Rarity, _ world: World,
                                                             _ allowed: [CreatureForm],
                                                             using generator: inout G) -> CreatureSpecies {
        let pool = world.species.filter { sp in sp.rarity == tier && allowed.contains { $0.species == sp } }
        guard !pool.isEmpty else { return allowed.first?.species ?? world.species[0] }
        let total = pool.reduce(0) { $0 + max(1, $1.weight) }
        var ticket = Int.random(in: 0..<total, using: &generator)
        for s in pool {
            let w = max(1, s.weight)
            if ticket < w { return s }
            ticket -= w
        }
        return pool[pool.count - 1]
    }

    /// 2+3단계: 종을 뽑고 그 종의 후보 변형 중 균등으로 하나.
    private static func pickForm<G: RandomNumberGenerator>(tier: Rarity, _ world: World,
                                                          _ allowed: [CreatureForm],
                                                          using generator: inout G) -> CreatureForm {
        let species = pickSpecies(tier: tier, world, allowed, using: &generator)
        let variants = allowed.filter { $0.species == species }
        return variants.randomElement(using: &generator) ?? CreatureForm(species: species, imageName: species.silhouetteImageName)
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
}
