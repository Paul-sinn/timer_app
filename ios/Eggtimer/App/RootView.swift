//
//  RootView.swift
//  Eggtimer
//
//  앱 루트. 로그인 게이트 없이 곧장 4탭 TabView로 진입한다
//  (요구사항: 로그인 없이 모든 화면 접근). 각 탭 화면은 step4~7에서 채운다.
//

import SwiftUI

struct RootView: View {
    init() {
        Self.configureTabBarAppearance()
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label(RootTab.home.title, systemImage: RootTab.home.systemImage) }
            CollectionView()
                .tabItem { Label(RootTab.collection.title, systemImage: RootTab.collection.systemImage) }
            ProgressScreen()
                .tabItem { Label(RootTab.progress.title, systemImage: RootTab.progress.systemImage) }
            MyPageView()
                .tabItem { Label(RootTab.myPage.title, systemImage: RootTab.myPage.systemImage) }
        }
        .tint(AppColor.eggAccent)
    }

    /// 탭바를 다크 톤(AppColor.tabBarBackground)으로 고정한다.
    private static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppColor.tabBarBackground)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}
