//
//  AppColor.swift
//  Eggtimer
//
//  UI_GUIDE.md 색상표의 단일 출처. 모든 화면/컴포넌트는 이 토큰만 사용한다.
//  다크모드 고정이므로 색상은 모드 분기 없이 고정값.
//
//  테마: "Nest" — 따뜻한 둥지. 웜 브라운 그라운드 + 앰버 주강조 + 세이지 + 웜 크림 텍스트.
//  강조(eggAccent)=앰버는 알/버튼/활성 등 앱 전반. 레전더리는 별도 골드(legendary)로 분리.
//

import SwiftUI

enum AppColor {
    // 배경 (웜 브라운 그라운드)
    static let pageBackground = Color(hex: 0x171310)   // 페이지 (잉크 브라운)
    static let cardBackground = Color(hex: 0x221B16)   // 카드/시트 (레이즈드)
    static let tabBarBackground = Color(hex: 0x1B1510) // 탭바

    // 텍스트 (웜 크림 계열)
    static let textPrimary = Color(hex: 0xF5EDE0)   // 주 텍스트 (웜 크림)
    static let textBody = Color(hex: 0xE1D6C4)      // 본문
    static let textSecondary = Color(hex: 0xA89884) // 보조 (뮤트 토프)
    static let textDisabled = Color(hex: 0x6B5F51)  // 비활성

    // 시맨틱
    static let eggAccent = Color(hex: 0xE8A03C) // 알/부화 + 주강조 (앰버)
    static let legendary = Color(hex: 0xF4B860) // 전설 등급 전용 골드
    static let success = Color(hex: 0x9CB380)   // 성공/Done/성장 (세이지)
    static let danger = Color(hex: 0xE5675C)    // 경고/Stop (웜 코럴레드)
    static let rare = Color(hex: 0x7FA9E8)      // 레어 강조 (소프트 블루)

    // 보더 (카드/입력 필드 공통 1px 보더)
    static let border = Color(hex: 0x332A22)

    // 부화 리빌 섬광. 화면을 가득 채우는 순간의 빛 — 가운데 흰 코어에서 앰버로 번진다.
    // 순백(0xFFFFFF)이 아니라 살짝 따뜻한 흰색이라 앰버와 이어질 때 경계가 안 진다.
    static let hatchFlashCore = Color(hex: 0xFFFBF0)
    static let hatchFlashEdge = Color(hex: 0xF2B44E)
}
