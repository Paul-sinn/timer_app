//
//  AppColor.swift
//  Eggtimer
//
//  UI_GUIDE.md 색상표의 단일 출처. 모든 화면/컴포넌트는 이 토큰만 사용한다.
//  다크모드 고정이므로 색상은 모드 분기 없이 고정값.
//

import SwiftUI

enum AppColor {
    // 배경
    static let pageBackground = Color(hex: 0x0A0A0A)   // 페이지
    static let cardBackground = Color(hex: 0x161616)   // 카드/시트
    static let tabBarBackground = Color(hex: 0x111111) // 탭바

    // 텍스트
    static let textPrimary = Color(hex: 0xFFFFFF)   // 주 텍스트
    static let textBody = Color(hex: 0xD4D4D4)      // 본문 (neutral-300)
    static let textSecondary = Color(hex: 0xA3A3A3) // 보조 (neutral-400)
    static let textDisabled = Color(hex: 0x525252)  // 비활성 (neutral-600)

    // 시맨틱
    static let eggAccent = Color(hex: 0xF5C451) // 알/부화 포인트 (따뜻한 옐로우)
    static let success = Color(hex: 0x22C55E)   // 성공/완료
    static let danger = Color(hex: 0xEF4444)    // 경고/중단
    static let rare = Color(hex: 0x60A5FA)      // 레어 강조

    // 보더 (카드/입력 필드 공통 1px 보더)
    static let border = Color(hex: 0x262626)
}
