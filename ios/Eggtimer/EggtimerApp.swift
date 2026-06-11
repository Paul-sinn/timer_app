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
    /// 부화 이력 영속 컨테이너(SwiftData, Phase 2-2).
    private let container: ModelContainer
    /// 영속 컨텍스트 기반 도감 스토어.
    @State private var store: CollectionStore

    init() {
        let container = try! ModelContainer(for: HatchedCreatureRecord.self)
        self.container = container
        _store = State(initialValue: CollectionStore(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .preferredColorScheme(.dark) // 다크모드 고정 (ADR/UI_GUIDE)
                .modelContainer(container)
        }
    }
}
