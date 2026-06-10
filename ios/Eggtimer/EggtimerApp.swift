//
//  EggtimerApp.swift
//  Eggtimer
//
//  Created by 신경하 on 6/9/26.
//

import SwiftUI

@main
struct EggtimerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark) // 다크모드 고정 (ADR/UI_GUIDE)
        }
    }
}
