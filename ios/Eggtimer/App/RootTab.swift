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

    /// 검수용 환경변수(START_TAB) 키 → 탭 매핑.
    init?(envKey: String?) {
        switch envKey?.lowercased() {
        case "home":       self = .home
        case "collection": self = .collection
        case "progress":   self = .progress
        case "mypage":     self = .myPage
        default:           return nil
        }
    }

    /// 탭바 라벨(레퍼런스 디자인에 맞춘 영문).
    var title: String {
        switch self {
        case .home:       return "Home"
        case .collection: return "Collection"
        case .progress:   return "Progress"
        case .myPage:     return "MyPage"
        }
    }

    /// Lucide → SF Symbol 매핑.
    var systemImage: String {
        switch self {
        case .home:       return "house.fill"           // Lucide home
        case .collection: return "square.grid.2x2.fill" // Lucide library/grid
        case .progress:   return "chart.bar.fill"       // Lucide bar-chart
        case .myPage:     return "person.fill"          // Lucide user
        }
    }
}
