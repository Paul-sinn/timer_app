//
//  AppSettings.swift
//  Eggtimer
//
//  앱 환경Settings(@AppStorage) 키·기본값의 단일 소스. 뷰마다 키 문자열을 직접 쓰면
//  오타로 값이 갈라지므로(다른 UserDefaults 슬롯) 여기 상수로 통일한다.
//  화면 꺼짐 방지는 기존 `ScreenAwake.settingKey`를 그대로 재사용.
//

import Foundation

enum AppSettings {
    /// 로컬 알림(집중 종료/휴식 알림) 사용 여부. 기본 켜짐.
    static let notificationsKey = "notificationsEnabled"
    /// 효과음(부화·진화 시스템 사운드) 사용 여부. 기본 켜짐.
    static let soundKey = "soundEnabled"
    /// 진동(부화·진화·휴식 진입 햅틱) 사용 여부. 기본 켜짐.
    static let hapticsKey = "hapticsEnabled"

    /// 유저가 직접 정한 프로필 닉네임. 빈 문자열 = 미설정(ProfileName.fallback 표시).
    /// 값 다듬기·기본값 규칙은 `ProfileName`이 단일 출처다.
    static let displayNameKey = "profileDisplayName"

    /// 위 3개의 기본값(모두 true). @AppStorage 선언 시 기본값을 이 상수로 통일.
    static let defaultOn = true
}
