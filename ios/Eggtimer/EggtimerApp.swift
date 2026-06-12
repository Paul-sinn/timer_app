//
//  EggtimerApp.swift
//  Eggtimer
//
//  Created by 신경하 on 6/9/26.
//

import SwiftUI
import SwiftData

@main
struct EggtimerApp: App {
    /// 영속 컨테이너(SwiftData): 부화 이력 + 집중 세션 이력.
    private let container: ModelContainer
    /// 영속 컨텍스트 기반 도감 스토어.
    @State private var store: CollectionStore
    /// 영속 컨텍스트 기반 집중 세션 이력 스토어.
    @State private var history: FocusHistoryStore
    /// Supabase 로그인 세션 상태.
    @State private var auth: AuthService
    /// 로그인↔로컬 동기화 오케스트레이터.
    @State private var sync: SyncCoordinator

    init() {
        let container = try! ModelContainer(for: HatchedCreatureRecord.self, FocusSessionRecord.self)
        self.container = container
        let store = CollectionStore(context: container.mainContext)
        let history = FocusHistoryStore(context: container.mainContext)
        let auth = AuthService()
        _store = State(initialValue: store)
        _history = State(initialValue: history)
        _auth = State(initialValue: auth)
        _sync = State(initialValue: SyncCoordinator(auth: auth, store: store, history: history))

        #if canImport(GoogleSignIn)
        GoogleAuth.configure()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store, history: history, auth: auth, sync: sync)
                .preferredColorScheme(.dark) // 다크모드 고정 (ADR/UI_GUIDE)
                .modelContainer(container)
                #if canImport(GoogleSignIn)
                .onOpenURL { GoogleAuth.handle($0) }
                #endif
                .task {
                    // 이미 로그인된 채 앱을 켜면(세션 복원) 즉시 동기화.
                    if auth.isAuthenticated { await sync.syncOnLogin() }
                }
        }
    }
}
