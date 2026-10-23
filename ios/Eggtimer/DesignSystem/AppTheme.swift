//
//  AppTheme.swift
//  Eggtimer
//
//  배경 테마. 화면 루트 배경(단색 또는 픽셀 그림)과 그 위에 바로 놓이는 글자색, 앱 colorScheme을 정한다.
//  카드·탭바·카드 안 글자는 테마와 무관하게 다크 고정. 색 재정의는 여기(단일 출처)에서만; 화면에서 하드코딩 금지.
//
//  - 기본(.nest)은 기존 배경색·글자색을 그대로 재사용 → 테마 미변경 시 픽셀 회귀 0.
//  - 파스텔(.butter/.mint/.lavender)은 colorScheme = .light → 상태바·시스템 UI가 어둡게 바뀌고,
//    배경 위 글자는 onPage* 진갈색을 쓴다. 대비 4.5:1 이상은 AppThemeTests가 강제한다.
//  - 그림 원본: images/backgrounds/ (270×480 픽셀 원본을 Assets에 넣고 .interpolation(.none)로 키운다)
//
//  Pro(잠금) 테마는 실제 콘텐츠가 준비되면 isPro=true인 case로 추가한다(피커가 "출시 예정" 잠금 처리).
//

import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case nest        // 웜 브라운 단색(기본). 무료.
    case midnight    // Midnight Navy 그림. 옛 단색 Midnight의 저장값을 이어받는다. 무료.
    case cocoa       // Cocoa Night 그림(덜 어두운 브라운). 무료.
    case butter      // Butter Yellow 그림(파스텔·라이트). 무료.
    case mint        // Mint Cream 그림(파스텔·라이트). 무료.
    case lavender    // Lavender Milk 그림(파스텔·라이트). 무료.

    /// 선택 저장 키(@AppStorage / UserDefaults 공용).
    static let storageKey = "selectedTheme"

    var id: String { rawValue }

    /// 배경 그림 에셋 이름. 단색 테마는 nil.
    var backgroundImage: String? {
        switch self {
        case .nest:     return nil
        case .midnight: return "BackgroundMidnightNavy"
        case .cocoa:    return "BackgroundCocoaNight"
        case .butter:   return "BackgroundButterYellow"
        case .mint:     return "BackgroundMintCream"
        case .lavender: return "BackgroundLavenderMilk"
        }
    }

    /// 화면 루트 배경색. 그림 테마는 그림 상단(타이머 자리) 색 — 그림 뒤 바탕이자 글자 대비 기준.
    var pageBackground: Color {
        switch self {
        case .nest:     return AppColor.pageBackground   // 기존 기본색 재사용(단일 출처, 회귀 0)
        case .midnight: return Color(hex: 0x1B233D)
        case .cocoa:    return Color(hex: 0x594138)
        case .butter:   return Color(hex: 0xFDEEB7)
        case .mint:     return Color(hex: 0xE3F2DA)
        case .lavender: return Color(hex: 0xEEE0F9)
        }
    }

    /// 파스텔은 라이트 → 상태바 글자가 어두워진다.
    var colorScheme: ColorScheme {
        switch self {
        case .butter, .mint, .lavender: return .light
        case .nest, .midnight, .cocoa:  return .dark
        }
    }

    // MARK: 배경 위에 바로 놓이는 글자(카드 안 글자는 AppColor 그대로)

    var onPagePrimary: Color { colorScheme == .light ? Self.inkPrimary : AppColor.textPrimary }
    var onPageBody: Color { colorScheme == .light ? Self.inkBody : AppColor.textBody }
    var onPageDisabled: Color { colorScheme == .light ? Self.inkDisabled : AppColor.textDisabled }

    var onPageSecondary: Color {
        switch self {
        case .butter, .mint, .lavender: return Self.inkSecondary
        case .cocoa:                    return Color(hex: 0xD6C7B2)   // 기본 보조색은 Cocoa 위 대비 3.3 → 밝게
        case .nest, .midnight:          return AppColor.textSecondary
        }
    }

    /// 앰버 강조 글자(예: "Ready to hatch!", 도감 개수).
    var onPageAccent: Color {
        switch self {
        case .butter, .mint, .lavender: return Color(hex: 0x8F520A)   // 진한 앰버(파스텔 위 대비 4.9+)
        case .cocoa:                    return AppColor.legendary     // 기본 앰버는 Cocoa 위 대비 4.3
        case .nest, .midnight:          return AppColor.eggAccent
        }
    }

    /// 캐릭터·알 뒤 글로우 합성. 밝은 배경에서 일반 합성이면 회색 얼룩처럼 보여서 screen(밝히기)으로.
    var glowBlendMode: BlendMode { colorScheme == .light ? .screen : .normal }

    // 파스텔 위 진갈색 잉크.
    private static let inkPrimary = Color(hex: 0x3A2A1E)
    private static let inkBody = Color(hex: 0x4E3B2C)
    private static let inkSecondary = Color(hex: 0x6B5747)
    private static let inkDisabled = Color(hex: 0x9C8A78)

    /// Pro 전용 여부. true인 테마는 "출시 예정" 잠금으로 표시된다.
    var isPro: Bool { false }

    /// 피커 표시 이름.
    var displayName: LocalizedStringKey {
        switch self {
        case .nest:     return "Nest"
        case .midnight: return "Midnight"
        case .cocoa:    return "Cocoa"
        case .butter:   return "Butter"
        case .mint:     return "Mint"
        case .lavender: return "Lavender"
        }
    }

    /// 무료 테마(즉시 선택 가능).
    static var free: [AppTheme] { allCases.filter { !$0.isPro } }
    /// 잠금(Pro) 테마.
    static var locked: [AppTheme] { allCases.filter(\.isPro) }

    /// 저장된 선택 테마(없거나 무효면 기본 .nest). 테스트 위해 defaults 주입 가능.
    static func current(_ defaults: UserDefaults = .standard) -> AppTheme {
        AppTheme(rawValue: defaults.string(forKey: storageKey) ?? "") ?? .nest
    }
}

extension EnvironmentValues {
    /// 현재 테마. 앱 루트(EggtimerApp)가 @AppStorage 값으로 주입 → 하위 화면·시트가 상속.
    @Entry var appTheme: AppTheme = .nest
}

/// 화면 루트 배경. 선택된 테마의 단색 위에 픽셀 그림을 깐다.
/// 그림은 색의 overlay라 크기는 색이 정한다 — scaledToFill 그림이 레이아웃을 밀어내지 않게.
struct ThemedBackground: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        theme.pageBackground
            .overlay {
                if let name = theme.backgroundImage {
                    Image(name)
                        .resizable()
                        .interpolation(.none)   // 픽셀 경계 유지
                        .scaledToFill()
                }
            }
            .clipped()
            .ignoresSafeArea()
    }
}
