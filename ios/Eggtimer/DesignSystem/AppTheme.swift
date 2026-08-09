//
//  AppTheme.swift
//  Eggtimer
//
//  배경 테마. 화면 루트 배경색만 스왑한다(카드·탭바·시맨틱색은 고정) — 앱은 다크모드 고정이라
//  모든 테마가 다크 팔레트다. 색 재정의는 여기(단일 출처)에서만; 화면에서 하드코딩 금지.
//
//  무료 테마는 즉시 선택 가능. Pro(잠금) 테마는 1.0에선 "출시 예정" 티저로만 노출(선택 불가) —
//  cyber/zen/cosmos는 추후 이미지 월드팩(사이버시티·동양·우주)의 색 예고편이다(제품전략.md).
//  기본(.nest)은 기존 배경색을 그대로 재사용 → 테마 미변경 시 픽셀 회귀 0.
//

import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case nest        // 웜 브라운(기본·현재). 무료.
    case midnight    // 쿨 다크 슬레이트. 무료.
    // Pro(잠금) 테마는 실제 콘텐츠(이미지 월드팩 — 제품전략.md H-1)가 준비되면 추가한다.
    // 지금은 placeholder 미끼 카드를 만들지 않는다(App Store 2.1 placeholder 리스크 회피).
    // 추가 시: 새 case + isPro=true → 피커가 자동으로 "출시 예정" 잠금 처리(ProAccess 게이트).

    /// 선택 저장 키(@AppStorage / UserDefaults 공용).
    static let storageKey = "selectedTheme"

    var id: String { rawValue }

    /// 화면 루트 배경색(다크 고정).
    var pageBackground: Color {
        switch self {
        case .nest:     return AppColor.pageBackground   // 기존 기본색 재사용(단일 출처, 회귀 0)
        case .midnight: return Color(hex: 0x121620)
        }
    }

    /// Pro 전용 여부. 1.0에선 true인 테마가 "출시 예정" 잠금으로 표시된다.
    var isPro: Bool {
        switch self {
        case .nest, .midnight: return false
        }
    }

    /// 피커 표시 이름.
    var displayName: LocalizedStringKey {
        switch self {
        case .nest:     return "Nest"
        case .midnight: return "Midnight"
        }
    }

    /// 무료 테마(즉시 선택 가능).
    static var free: [AppTheme] { allCases.filter { !$0.isPro } }
    /// 잠금(Pro) 테마 — 1.0은 "출시 예정".
    static var locked: [AppTheme] { allCases.filter(\.isPro) }

    /// 저장된 선택 테마(없거나 무효면 기본 .nest). 테스트 위해 defaults 주입 가능.
    static func current(_ defaults: UserDefaults = .standard) -> AppTheme {
        AppTheme(rawValue: defaults.string(forKey: storageKey) ?? "") ?? .nest
    }
}

/// 화면 루트 배경. 선택된 테마의 pageBackground를 그리고, @AppStorage라 테마 변경 시 자동 갱신한다.
/// 기존 `AppColor.pageBackground.ignoresSafeArea()` 자리만 이걸로 교체한다
/// (전경색·프리뷰용 `AppColor.pageBackground` 사용처는 그대로 둔다).
struct ThemedBackground: View {
    @AppStorage(AppTheme.storageKey) private var raw = AppTheme.nest.rawValue

    var body: some View {
        (AppTheme(rawValue: raw) ?? .nest).pageBackground.ignoresSafeArea()
    }
}
