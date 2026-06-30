//
//  Rarity.swift
//  Eggtimer
//
//  생명체 레어도. 순수 값 타입(enum). 표시색은 AppColor 토큰에만 매핑한다.
//  (UI_GUIDE.md: 보라/인디고 금지 → 기존 시맨틱 토큰만 재사용)
//  등급 체계(확률표 기준): Common / Uncommon / Rare / Legendary.
//

import SwiftUI

enum Rarity: String, CaseIterable, Identifiable, Comparable {
    case common
    case uncommon
    case rare
    case legendary

    var id: String { rawValue }

    /// 정렬용 순위(낮을수록 흔함).
    private var order: Int {
        switch self {
        case .common:    return 0
        case .uncommon:  return 1
        case .rare:      return 2
        case .legendary: return 3
        }
    }

    static func < (lhs: Rarity, rhs: Rarity) -> Bool { lhs.order < rhs.order }

    /// 등급 출현 확률(%). **전 등급 합 = 100(불변)**. 부화는 먼저 이 표로 등급을 뽑고,
    /// 그 등급 안에서 종을 뽑는다(2단계). 새 종을 추가해도 이 값은 고정 → 다른 등급 확률이 안 바뀐다.
    var tierWeight: Int {
        switch self {
        case .common:    return 80
        case .uncommon:  return 10
        case .rare:      return 8
        case .legendary: return 2
        }
    }

    /// 한글 표시 라벨.
    var label: String {
        switch self {
        case .common:    return "일반"
        case .uncommon:  return "고급"
        case .rare:      return "레어"
        case .legendary: return "전설"
        }
    }

    /// 레어도 강조색. AppColor 토큰만 사용(신규 색상 도입 금지).
    var color: Color {
        switch self {
        case .common:    return AppColor.textSecondary // 무채색 (#A3A3A3)
        case .uncommon:  return AppColor.success        // 초록 (#22C55E)
        case .rare:      return AppColor.rare           // 파랑 (#60A5FA)
        case .legendary: return AppColor.eggAccent      // 골드 (#F5C451)
        }
    }

    /// 카드 하단 점 개수(등급이 높을수록 많이 채워짐).
    var dots: Int { order + 1 }
}
