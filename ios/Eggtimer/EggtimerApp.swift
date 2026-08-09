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
    /// "Hatcho Pro" 접근 게이트(테마 등 유료 콘텐츠 gate). 명시적 @MainActor라 init에서 생성.
    @State private var pro: ProAccess

    init() {
        // 영속 스토어 로드가 실패해도(향후 마이그레이션 실패·손상 등) 전 유저 런치 크래시를 막는다.
        // 실패 시 in-memory로 폴백 → 앱은 뜨고(이번 세션은 로컬 이력 비어 보임), **온디스크 파일은 건드리지 않아**
        // 데이터가 보존된다(다음 정상 버전에서 복구 / 로그인 유저는 Supabase 재동기화).
        let container: ModelContainer
        do {
            container = try ModelContainer(for: HatchedCreatureRecord.self, FocusSessionRecord.self)
        } catch {
            assertionFailure("Persistent ModelContainer load failed, falling back to in-memory: \(error)")
            container = try! ModelContainer(for: HatchedCreatureRecord.self, FocusSessionRecord.self,
                                            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }
        self.container = container
        let store = CollectionStore(context: container.mainContext)
        let history = FocusHistoryStore(context: container.mainContext)
        let auth = AuthService()
        _store = State(initialValue: store)
        _history = State(initialValue: history)
        _auth = State(initialValue: auth)
        _sync = State(initialValue: SyncCoordinator(auth: auth, store: store, history: history))
        _pro = State(initialValue: ProAccess())

        #if canImport(GoogleSignIn)
        GoogleAuth.configure()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store, history: history, auth: auth, sync: sync)
                .environment(pro)            // Pro 게이트 주입(테마 피커 등 하위·시트가 상속)
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
