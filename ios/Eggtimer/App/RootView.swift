//
//  RootView.swift
//  Eggtimer
//
//  앱 루트. 로그인 게이트 없이 곧장 4탭 TabView로 진입한다
//  (요구사항: 로그인 없이 모든 화면 접근). 각 탭 화면은 step4~7에서 채운다.
//

import SwiftUI

struct RootView: View {
    /// 현재 선택된 탭. 검수 편의를 위해 환경변수 START_TAB로 초기 탭 지정 가능.
    @State private var selection: RootTab
    /// 탭 간 공유되는 도감 스토어(홈에서 부화 → 컬렉션에 반영).
    @State private var store = CollectionStore()
    /// 집중 세션 단일 소스(타이머·성장·부화 트리거).
    @State private var session = SessionManager()

    init() {
        Self.configureTabBarAppearance()
        let env = ProcessInfo.processInfo.environment["START_TAB"]
        _selection = State(initialValue: RootTab(envKey: env) ?? .home)
    }

    var body: some View {
        TabView(selection: $selection) {
            HomeView(session: session, store: store)
                .tabItem { Label(RootTab.home.title, systemImage: RootTab.home.systemImage) }
                .tag(RootTab.home)
            CollectionView(creatures: store.creatures)
                .tabItem { Label(RootTab.collection.title, systemImage: RootTab.collection.systemImage) }
                .tag(RootTab.collection)
            ProgressScreen()
                .tabItem { Label(RootTab.progress.title, systemImage: RootTab.progress.systemImage) }
                .tag(RootTab.progress)
            MyPageView()
                .tabItem { Label(RootTab.myPage.title, systemImage: RootTab.myPage.systemImage) }
                .tag(RootTab.myPage)
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
