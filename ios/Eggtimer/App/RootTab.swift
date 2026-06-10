//
//  RootTab.swift
//  Eggtimer
//
//  하단 탭바 4개 정의. 디자인 의도는 Lucide 아이콘이지만 SwiftUI에서는
//  대응되는 SF Symbol로 매핑한다(UI_GUIDE.md 탭바 4개: Home/Collection/Progress/MyPage).
//

import Foundation

enum RootTab: CaseIterable, Identifiable {
    case home
    case collection
    case progress
    case myPage

    var id: Self { self }

    /// 탭바 라벨(한글).
    var title: String {
        switch self {
        case .home:       return "홈"
        case .collection: return "컬렉션"
        case .progress:   return "기록"
        case .myPage:     return "마이"
        }
    }

    /// Lucide → SF Symbol 매핑.
    var systemImage: String {
        switch self {
        case .home:       return "house"               // Lucide home
        case .collection: return "square.grid.2x2"     // Lucide library/grid
        case .progress:   return "chart.bar"           // Lucide bar-chart
        case .myPage:     return "person.crop.circle"  // Lucide user
        }
    }
}
