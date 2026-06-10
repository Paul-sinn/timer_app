//
//  Rarity.swift
//  Eggtimer
//
//  생명체 레어도. 순수 값 타입(enum). 표시색은 AppColor 토큰에만 매핑한다.
//  (UI_GUIDE.md: 보라/인디고 금지 → 기존 시맨틱 토큰만 재사용)
//

import SwiftUI

enum Rarity: String, CaseIterable, Identifiable {
    case common
    case rare
    case epic
    case legendary

    var id: String { rawValue }

    /// 한글 표시 라벨.
    var label: String {
        switch self {
        case .common:    return "일반"
        case .rare:      return "레어"
        case .epic:      return "에픽"
        case .legendary: return "전설"
        }
    }

    /// 레어도 강조색. AppColor 토큰만 사용(신규 색상 도입 금지).
    var color: Color {
        switch self {
        case .common:    return AppColor.textSecondary // 무채색 (#A3A3A3)
        case .rare:      return AppColor.rare          // 파랑 (#60A5FA)
        case .epic:      return AppColor.eggAccent     // 따뜻한 옐로우 (#F5C451)
        case .legendary: return AppColor.success       // 초록 (#22C55E)
        }
    }
}
