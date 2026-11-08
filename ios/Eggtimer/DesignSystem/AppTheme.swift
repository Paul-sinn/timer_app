//
//  AppTheme.swift
//  Eggtimer
//
//  배경 테마. 화면 루트 배경(단색 또는 픽셀 그림)과 그 위에 바로 놓이는 글자색, 앱 colorScheme을 정한다.
//  카드·탭바·카드 안 글자는 테마와 무관하게 다크 고정. 색 재정의는 여기(단일 출처)에서만; 화면에서 하드코딩 금지.
//
//  - 첫 실행 기본 테마는 `defaultTheme`(.butter) 한 곳에서 정한다.
//  - .nest는 예전 기본 다크 — 기존 배경색·글자색을 그대로 재사용(온보딩·도감 상세 시트가 고정으로 쓴다).
//  - 파스텔(.butter/.mint/.lavender)은 colorScheme = .light → 상태바·시스템 UI가 어둡게 바뀌고,
//    배경 위 글자는 onPage* 진갈색을 쓴다. 대비 4.5:1 이상은 AppThemeTests가 강제한다.
//  - 그림 원본: images/backgrounds/ (270×480 픽셀 원본을 Assets에 넣고 .interpolation(.none)로 키운다)
//  - 월드마다 배경 묶음이 따로 있다(`world`). 지금 월드의 배경만 고를 수 있고, 월드를 바꾸면 배경도 따라 바뀐다.
//    기본 월드 선택은 기존 키(`storageKey`), 팩 월드 선택은 `worldStorageKey`에 따로 저장 → 기본 월드로 돌아가면 원래 배경.
//    크리스마스 배경 가공: scripts/make_christmas_backgrounds.py
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
    case christmasEve // 크리스마스 월드: 벽난로 방(다크).
    case snowyNight   // 크리스마스 월드: 보름달·산타 썰매가 뜬 눈 덮인 밤(다크).

    /// 선택 저장 키(@AppStorage / UserDefaults 공용).
    static let storageKey = "selectedTheme"
    /// 팩 월드(크리스마스 등)에서 고른 배경. 기본 월드 선택(`storageKey`)과 따로 둬서 돌아가면 원래 배경이 나온다.
    // shortcut: 팩 월드끼리는 이 키 하나를 같이 쓴다 → 팩이 둘 이상이면 다른 팩으로 갔다 오면 그 팩 기본 배경. 팩이 늘면 월드별 키로.
    static let worldStorageKey = "selectedWorldTheme"
    /// 아직 고른 적 없는 유저의 배경(앱 아이콘과 같은 버터크림 톤).
    nonisolated static let defaultTheme: AppTheme = .butter   // @Entry 기본값(nonisolated)에서도 읽는다

    var id: String { rawValue }

    /// 이 배경이 속한 월드.
    var world: World {
        switch self {
        case .nest, .midnight, .cocoa, .butter, .mint, .lavender: return .classic
        case .christmasEve, .snowyNight:                          return .christmas
        }
    }

    /// 배경 그림 에셋 이름. 단색 테마는 nil.
    var backgroundImage: String? {
        switch self {
        case .nest:     return nil
        case .midnight: return "BackgroundMidnightNavy"
        case .cocoa:    return "BackgroundCocoaNight"
        case .butter:   return "BackgroundButterYellow"
        case .mint:     return "BackgroundMintCream"
        case .lavender: return "BackgroundLavenderMilk"
        case .christmasEve: return "BackgroundChristmasEve"
        case .snowyNight:   return "BackgroundSnowyNight"
        }
    }

    /// 가로 4:3 그림(아이패드 가로·넓은 창). 세로 그림을 그대로 쓰면 위아래가 58% 잘려 바닥·빈 상단이 사라진다.
    var wideBackgroundImage: String? { backgroundImage.map { $0 + "Wide" } }

    /// 창 모양에 맞는 그림 — 세로보다 넓으면 가로 그림. 아이패드 Split View 좁은 창은 세로 그림.
    func backgroundImage(for size: CGSize) -> String? {
        size.width > size.height ? wideBackgroundImage : backgroundImage
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
        case .christmasEve: return Color(hex: 0x5B2D39)
        case .snowyNight:   return Color(hex: 0x1C2C50)
        }
    }

    /// 파스텔은 라이트 → 상태바 글자가 어두워진다.
    var colorScheme: ColorScheme {
        switch self {
        case .butter, .mint, .lavender: return .light
        case .nest, .midnight, .cocoa, .christmasEve, .snowyNight: return .dark
        }
    }

    // MARK: 배경 위에 바로 놓이는 글자(카드 안 글자는 AppColor 그대로)

    var onPagePrimary: Color { colorScheme == .light ? Self.inkPrimary : AppColor.textPrimary }
    var onPageBody: Color { colorScheme == .light ? Self.inkBody : AppColor.textBody }
    var onPageDisabled: Color { colorScheme == .light ? Self.inkDisabled : AppColor.textDisabled }

    var onPageSecondary: Color {
        switch self {
        case .butter, .mint, .lavender: return Self.inkSecondary
        // 기본 보조색은 Cocoa 위 대비 3.3·이브 방 벽 4.0·눈 덮인 밤 바닥(눈밭) 2:1 → 밝게
        case .cocoa, .christmasEve, .snowyNight: return Color(hex: 0xD6C7B2)
        case .nest, .midnight:          return AppColor.textSecondary
        }
    }

    /// 앰버 강조 글자(예: "Ready to hatch!", 도감 개수).
    var onPageAccent: Color {
        switch self {
        case .butter, .mint, .lavender: return Color(hex: 0x8F520A)   // 진한 앰버(파스텔 위 대비 4.9+)
        case .cocoa:                    return AppColor.legendary     // 기본 앰버는 Cocoa 위 대비 4.3
        case .nest, .midnight, .christmasEve, .snowyNight: return AppColor.eggAccent
        }
    }

    // MARK: 카드(배경 위 어두운 타일). 테마 색 계열로 물든 진한 색이라 배경과 어울린다.
    // 카드 안 글자는 AppColor 크림 그대로 — 대비 4.5:1은 AppThemeTests가 강제.

    var cardBackground: Color {
        switch self {
        case .nest:     return AppColor.cardBackground
        case .midnight: return Color(hex: 0x161C30)   // 페이지(네이비)보다 한 톤 깊게
        case .cocoa:    return Color(hex: 0x2E211B)
        case .butter:   return Color(hex: 0x2E2312)   // 진한 꿀갈색
        case .mint:     return Color(hex: 0x1A271F)   // 진한 숲색
        case .lavender: return Color(hex: 0x271F33)   // 진한 자두색
        case .christmasEve: return Color(hex: 0x2B171C)   // 진한 와인색
        case .snowyNight:   return Color(hex: 0x141D33)   // 하늘보다 깊은 남색
        }
    }

    /// 미발견 도감 카드(카드보다 한 톤 어둡게).
    var cardBackgroundMuted: Color {
        switch self {
        case .nest:     return AppColor.cardBackgroundMuted
        case .midnight: return Color(hex: 0x121729)
        case .cocoa:    return Color(hex: 0x261B16)
        case .butter:   return Color(hex: 0x261D0F)
        case .mint:     return Color(hex: 0x15201A)
        case .lavender: return Color(hex: 0x201A2B)
        case .christmasEve: return Color(hex: 0x231216)
        case .snowyNight:   return Color(hex: 0x10172A)
        }
    }

    /// 카드 테두리·구분선·비활성 막대.
    var cardBorder: Color {
        switch self {
        case .nest:     return AppColor.border
        case .midnight: return Color(hex: 0x2C3555)
        case .cocoa:    return Color(hex: 0x4A3830)
        case .butter:   return Color(hex: 0x4A3A22)
        case .mint:     return Color(hex: 0x2F4637)
        case .lavender: return Color(hex: 0x3F3352)
        case .christmasEve: return Color(hex: 0x4A2A32)
        case .snowyNight:   return Color(hex: 0x2C3A5E)
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
        case .christmasEve: return "Christmas Eve"
        case .snowyNight:   return "Snowy Night"
        }
    }

    /// 무료 테마(즉시 선택 가능).
    static var free: [AppTheme] { allCases.filter { !$0.isPro } }
    /// 잠금(Pro) 테마.
    static var locked: [AppTheme] { allCases.filter(\.isPro) }

    /// 이 월드에서 쓸 배경: 후보 저장값 중 이 월드 배경인 첫 값, 없으면 월드 기본 배경.
    /// 호출 순서 = (팩 월드 선택, 기본 월드 선택) — 각 월드는 자기 배경만 알아본다.
    static func resolved(_ candidates: String..., in world: World) -> AppTheme {
        candidates.lazy.compactMap(AppTheme.init(rawValue:)).first { $0.world == world } ?? world.defaultTheme
    }

    /// 이 배경을 고른 값으로 저장. 자기 월드의 키에 쓰므로 다른 월드의 선택은 그대로 남는다.
    func select(in defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: world == .classic ? Self.storageKey : Self.worldStorageKey)
    }

    /// 저장된 선택 테마(없거나 다른 월드 것이면 그 월드 기본). 테스트 위해 defaults 주입 가능.
    static func current(_ defaults: UserDefaults = .standard, world: World = .classic) -> AppTheme {
        resolved(defaults.string(forKey: worldStorageKey) ?? "", defaults.string(forKey: storageKey) ?? "", in: world)
    }
}

extension EnvironmentValues {
    /// 현재 테마. 앱 루트(EggtimerApp)가 @AppStorage 값으로 주입 → 하위 화면·시트가 상속.
    @Entry var appTheme: AppTheme = AppTheme.defaultTheme
}

/// 앱 루트에서 지금 월드의 배경을 골라 하위 화면에 주입하고 colorScheme을 정한다.
/// App이 아니라 View 수식어 안에서 읽어야 팩 소유 확인(ProAccess)이 늦게 끝나도 바로 다시 그린다.
struct WorldThemeRoot: ViewModifier {
    @Environment(ProAccess.self) private var pro
    @AppStorage(AppTheme.storageKey) private var classicRaw = AppTheme.defaultTheme.rawValue
    @AppStorage(AppTheme.worldStorageKey) private var worldThemeRaw = ""
    @AppStorage(World.storageKey) private var worldRaw = World.classic.rawValue

    func body(content: Content) -> some View {
        let theme = AppTheme.resolved(worldThemeRaw, classicRaw, in: World.resolved(worldRaw, owns: pro.owns))
        content
            .environment(\.appTheme, theme)
            .preferredColorScheme(theme.colorScheme)   // 파스텔 테마만 라이트(상태바가 어두워짐), 나머지 다크
    }
}

/// 화면 루트 배경. 선택된 테마의 단색 위에 픽셀 그림을 깐다.
/// 그림은 색의 overlay라 크기는 색이 정한다 — scaledToFill 그림이 레이아웃을 밀어내지 않게.
struct ThemedBackground: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        theme.pageBackground
            .overlay {
                GeometryReader { geo in
                    if let name = theme.backgroundImage(for: geo.size) {
                        Image(name)
                            .resizable()
                            .interpolation(.none)   // 픽셀 경계 유지
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
            }
            .clipped()
            .ignoresSafeArea()
    }
}
