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

    init() {
        let container = try! ModelContainer(for: HatchedCreatureRecord.self, FocusSessionRecord.self)
        self.container = container
        _store = State(initialValue: CollectionStore(context: container.mainContext))
        _history = State(initialValue: FocusHistoryStore(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store, history: history)
                .preferredColorScheme(.dark) // 다크모드 고정 (ADR/UI_GUIDE)
                .modelContainer(container)
        }
    }
}
