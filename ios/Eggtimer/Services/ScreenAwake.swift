//
//  ScreenAwake.swift
//  Eggtimer
//
//  화면 꺼짐 방지(Feature 7). 세션 running 동안에만 idleTimer를 끈다.
//  사용자 설정(@AppStorage "keepScreenAwake")이 꺼져 있으면 강제하지 않는다.
//  배터리 보호를 위해 일시정지/완료/중단/백그라운드에서 반드시 해제한다.
//

import UIKit

enum ScreenAwake {
    static let settingKey = "keepScreenAwake"

    /// 사용자 설정값(기본 true).
    static var isEnabledBySetting: Bool {
        UserDefaults.standard.object(forKey: settingKey) as? Bool ?? true
    }

    /// 화면 유지 on/off. on이라도 설정이 꺼져 있으면 유지하지 않는다.
    @MainActor
    static func set(_ on: Bool) {
        UIApplication.shared.isIdleTimerDisabled = on && isEnabledBySetting
    }
}
