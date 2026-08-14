//
//  RootView.swift
//  Eggtimer
//
//  앱 루트. 로그인 게이트 없이 곧장 4탭 TabView로 진입한다
//  (요구사항: 로그인 없이 모든 화면 접근). 각 탭 화면은 step4~7에서 채운다.
//

import SwiftUI

struct RootView: View {
    /// 현재 선택된 탭. DEBUG 빌드에 한해 환경변수 START_TAB로 초기 탭을 지정할 수 있다.
    @State private var selection: RootTab
    /// 탭 간 공유되는 도감 스토어(홈에서 부화 → 컬렉션에 반영). App에서 영속 store 주입.
    @State private var store: CollectionStore
    /// 집중 세션 단일 소스(타이머·성장·부화 트리거).
    @State private var session = SessionManager()
    /// 끝난 세션 이력 스토어(통계 원자료). App에서 영속 주입.
    @State private var history: FocusHistoryStore
    /// 로그인 세션 상태(마이페이지 로그인 UI).
    @State private var auth: AuthService
    /// 로그인↔로컬 동기화(부화·세션종료 push, 로그인 머지).
    @State private var sync: SyncCoordinator
    /// 첫 실행 온보딩 노출 여부(Done 시 영구 저장).
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    init(store: CollectionStore = CollectionStore(),
         history: FocusHistoryStore = FocusHistoryStore(),
         auth: AuthService,
         sync: SyncCoordinator? = nil) {
        _store = State(initialValue: store)
        _history = State(initialValue: history)
        _auth = State(initialValue: auth)
        _sync = State(initialValue: sync ?? SyncCoordinator(auth: auth, store: store, history: history))
        Self.configureTabBarAppearance()
        #if DEBUG
        // 검수용 시작 탭 훅. CREATURE_GALLERY와 동일하게 DEBUG 전용 —
        // 릴리스 빌드엔 이 분기 코드 자체가 없다.
        let env = ProcessInfo.processInfo.environment["START_TAB"]
        _selection = State(initialValue: RootTab(envKey: env) ?? .home)
        #else
        _selection = State(initialValue: .home)
        #endif
    }

    var body: some View {
        #if DEBUG
        // 캐릭터 아트 검수 화면. START_TAB과 같은 방식의 환경변수 훅이라
        // 프로덕션 UI에는 어떤 진입 버튼도 생기지 않는다(릴리스 빌드엔 코드 자체가 없음).
        //   xcrun simctl launch <device> com.paulsin.hatchly 로 띄울 땐
        //   SIMCTL_CHILD_CREATURE_GALLERY=1 환경변수를 주면 된다.
        if ProcessInfo.processInfo.environment["CREATURE_GALLERY"] == "1" {
            CreatureGalleryView()
        } else if ProcessInfo.processInfo.environment["HATCH_BURST"] == "1" {
            // 부화 버스트 반복 재생(투명 배경 합성·타이밍 검수용).
            HatchBurstPreviewView()
        } else {
            tabs
        }
        #else
        tabs
        #endif
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            HomeView(session: session, store: store, history: history, sync: sync)
                .tabItem { Label(RootTab.home.title, systemImage: RootTab.home.systemImage) }
                .tag(RootTab.home)
            CollectionView(creatures: store.creatures,
                           completedSessionsSinceHatch: { history.completedSessions(forCompanion: $0.id) })
                .tabItem { Label(RootTab.collection.title, systemImage: RootTab.collection.systemImage) }
                .tag(RootTab.collection)
            ProgressScreen(sessions: history.sessions)
                .tabItem { Label(RootTab.progress.title, systemImage: RootTab.progress.systemImage) }
                .tag(RootTab.progress)
            MyPageView(hatchedCount: store.creatures.count, auth: auth, sync: sync, history: history)
                .tabItem { Label(RootTab.myPage.title, systemImage: RootTab.myPage.systemImage) }
                .tag(RootTab.myPage)
        }
        .tint(AppColor.eggAccent)
        .fullScreenCover(isPresented: .constant(!hasSeenOnboarding)) {
            OnboardingView { hasSeenOnboarding = true }
        }
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
    RootView(auth: AuthService())
        .preferredColorScheme(.dark)
}
