//
//  AppThemeTests.swift
//  EggtimerTests
//
//  배경 테마 순수 로직 검증. 기본 폴백·무료/잠금 파티션·기존 배경 회귀·
//  그림 에셋 존재·배경 위 글자 가독(대비)·라이트/다크 구분·월드별 배경(크리스마스).
//

import Testing
import SwiftUI
import UIKit
import Foundation
@testable import Eggtimer

struct AppThemeTests {

    @Test func defaultThemeIsButter() {
        // 2026-10-24 결정: 첫 실행 기본 배경 = Butter(앱 아이콘과 같은 버터크림 톤).
        #expect(AppTheme.defaultTheme == .butter)
    }

    @Test func currentFallsBackToDefaultTheme() {
        let defaults = UserDefaults(suiteName: "test.theme.\(UUID().uuidString)")!
        #expect(AppTheme.current(defaults) == AppTheme.defaultTheme)   // 저장값 없음 → 기본

        defaults.set("bogus-not-a-theme", forKey: AppTheme.storageKey)
        #expect(AppTheme.current(defaults) == AppTheme.defaultTheme)   // 무효값 → 기본

        defaults.set(AppTheme.midnight.rawValue, forKey: AppTheme.storageKey)
        #expect(AppTheme.current(defaults) == .midnight)      // 유효값 라운드트립
    }

    @Test func midnightKeepsItsLegacyStorageValue() {
        // 옛 단색 Midnight를 고른 기기가 새 Midnight Navy 그림으로 이어지도록 저장값 유지.
        #expect(AppTheme.midnight.rawValue == "midnight")
    }

    @Test func freeAndLockedPartitionCoversAllCases() {
        #expect(AppTheme.free.allSatisfy { !$0.isPro })
        #expect(AppTheme.locked.allSatisfy { $0.isPro })
        #expect(AppTheme.free.contains(AppTheme.defaultTheme))   // 기본은 무료
        #expect(!AppTheme.free.isEmpty)
        // 배경은 전부 무료 → locked 비어있음(placeholder 미끼 안 만듦).
        #expect(AppTheme.locked.isEmpty)
        // 무료 ∪ 잠금 = 전체, 겹침 없음.
        #expect(AppTheme.free.count + AppTheme.locked.count == AppTheme.allCases.count)
    }

    @Test func nestReusesLegacyPageBackground() {
        // 회귀: 기본 테마 배경 = 기존 페이지색(단일 출처 재사용).
        #expect(AppTheme.nest.pageBackground == AppColor.pageBackground)
    }

    @Test func nestOnPageTextMatchesLegacyTokens() {
        // 회귀: 기본 테마의 배경 위 글자는 기존 토큰 그대로 → 기본 화면 픽셀 변화 0.
        #expect(AppTheme.nest.onPagePrimary == AppColor.textPrimary)
        #expect(AppTheme.nest.onPageBody == AppColor.textBody)
        #expect(AppTheme.nest.onPageSecondary == AppColor.textSecondary)
        #expect(AppTheme.nest.onPageDisabled == AppColor.textDisabled)
        #expect(AppTheme.nest.onPageAccent == AppColor.eggAccent)
    }

    // MARK: - 그림 배경

    @Test func onlyNestIsPlainColor() {
        #expect(AppTheme.nest.backgroundImage == nil)
        for theme in AppTheme.allCases where theme != .nest {
            #expect(theme.backgroundImage != nil, "\(theme) 그림 없음")
        }
    }

    @Test func everyImageThemeHasAWideVersion() {
        // 아이패드 가로(창이 세로보다 넓을 때)용 4:3 그림. 단색 테마는 둘 다 없음.
        #expect(AppTheme.nest.wideBackgroundImage == nil)
        for theme in AppTheme.allCases where theme != .nest {
            #expect(theme.wideBackgroundImage != nil, "\(theme) 가로 그림 없음")
            #expect(theme.wideBackgroundImage != theme.backgroundImage)
        }
    }

    @Test func picksWideImageOnlyWhenWiderThanTall() {
        let theme = AppTheme.butter
        #expect(theme.backgroundImage(for: CGSize(width: 402, height: 874)) == theme.backgroundImage)      // 아이폰
        #expect(theme.backgroundImage(for: CGSize(width: 1032, height: 1376)) == theme.backgroundImage)    // 아이패드 세로
        #expect(theme.backgroundImage(for: CGSize(width: 1376, height: 1032)) == theme.wideBackgroundImage) // 아이패드 가로
        #expect(AppTheme.nest.backgroundImage(for: CGSize(width: 1376, height: 1032)) == nil)
    }

    @MainActor
    @Test func backgroundImagesAreInTheAppBundle() {
        let missing = AppTheme.allCases
            .flatMap { [$0.backgroundImage, $0.wideBackgroundImage] }
            .compactMap { $0 }
            .filter { UIImage(named: $0) == nil }
        #expect(missing.isEmpty, "번들에 없는 배경: \(missing)")
    }

    // MARK: - 라이트/다크

    @Test func pastelThemesAreLight() {
        let light: Set<AppTheme> = [.butter, .mint, .lavender]
        for theme in AppTheme.allCases {
            #expect(theme.colorScheme == (light.contains(theme) ? .light : .dark), "\(theme)")
        }
    }

    // MARK: - 가독성 (WCAG 대비 4.5:1 = 작은 글자 기준)

    @Test func onPageTextIsReadableOnEveryTheme() {
        for theme in AppTheme.allCases {
            let roles: [(String, Color)] = [
                ("primary", theme.onPagePrimary),
                ("body", theme.onPageBody),
                ("secondary", theme.onPageSecondary),
                ("accent", theme.onPageAccent),
            ]
            for (role, color) in roles {
                let ratio = contrast(color, theme.pageBackground)
                #expect(ratio >= 4.5, "\(theme).\(role) 대비 \(ratio)")
            }
        }
    }

    // MARK: - 월드별 배경 (월드 = 캐릭터 + 배경 + BGM 한 세트)

    @Test func everyWorldHasItsOwnThemes() {
        #expect(World.classic.themes == [.nest, .midnight, .cocoa, .butter, .mint, .lavender])
        #expect(World.christmas.themes == [.christmasEve, .snowyNight])
        for world in World.allCases {
            #expect(world.themes.contains(world.defaultTheme), "\(world)")
        }
        #expect(World.classic.defaultTheme == AppTheme.defaultTheme)   // 기본 월드 첫 실행 배경은 그대로
    }

    @Test func themeFollowsTheSelectedWorld() {
        // 인자 순서 = (월드 팩에서 고른 배경, 기본 월드에서 고른 배경). 앞에서부터 이 월드 배경인 첫 값.
        #expect(AppTheme.resolved("", "mint", in: .christmas) == World.christmas.defaultTheme)   // 처음 → 팩 기본 배경
        #expect(AppTheme.resolved("snowyNight", "mint", in: .christmas) == .snowyNight)
        #expect(AppTheme.resolved("snowyNight", "mint", in: .classic) == .mint)                 // 돌아가면 원래 배경
        #expect(AppTheme.resolved("mint", "mint", in: .christmas) == World.christmas.defaultTheme) // 다른 월드 배경은 무시
        #expect(AppTheme.resolved("", "bogus", in: .classic) == AppTheme.defaultTheme)
    }

    @Test func selectingAThemeRemembersItPerWorld() {
        let defaults = UserDefaults(suiteName: "test.theme.\(UUID().uuidString)")!
        AppTheme.lavender.select(in: defaults)
        AppTheme.snowyNight.select(in: defaults)
        #expect(AppTheme.current(defaults, world: .christmas) == .snowyNight)
        #expect(AppTheme.current(defaults, world: .classic) == .lavender)        // 크리스마스에서 골라도 원래 배경 유지
        #expect(defaults.string(forKey: AppTheme.storageKey) == "lavender")     // 기존 저장 키 그대로(업데이트해도 배경 안 바뀜)
    }

    @Test func christmasThemesAreDark() {
        // 둘 다 밤 장면 → 크림 글자·다크 상태바.
        for theme in World.christmas.themes {
            #expect(theme.colorScheme == .dark, "\(theme)")
        }
    }

    // MARK: - 실제 그림 픽셀 검사

    @MainActor
    @Test func pageBackgroundIsTheImageTopColor() {
        // 글자 대비는 pageBackground로 검사한다 → 그림을 바꾸면(예: 눈 덮인 밤 v3) 이 값도 함께 바꿔야 한다.
        for theme in AppTheme.allCases {
            for name in [theme.backgroundImage, theme.wideBackgroundImage].compactMap({ $0 }) {
                guard let image = BundleImage(name) else { Issue.record("\(name) 없음"); continue }
                let top = image.dominantColor(rows: 0..<(image.height * 3 / 10))
                let page = rgb(theme.pageBackground)
                #expect(zip(top, page).allSatisfy { abs($0 - $1) <= 3 }, "\(name) 상단 \(top) ≠ pageBackground \(page)")
            }
        }
    }

    @MainActor
    @Test func onPageTextIsReadableOnTheFloor() {
        // 아래 30%(바닥) 위에도 글자가 온다(홈 "Hatching progress"). 눈 덮인 밤은 눈밭이 밝아 여기서 걸린다.
        // 기준 3:1 = 기존 가장 어두운 바닥(Cocoa 보조 글자 3.04)과 같은 선. 불빛·눈 하이라이트 같은 작은 점(10%)은 뺀다.
        // 아이폰 세로 그림만 — 가로(아이패드) 화면은 글자 배치가 달라 여기서 보지 않는다.
        for theme in AppTheme.allCases {
            guard let name = theme.backgroundImage else { continue }
            guard let image = BundleImage(name) else { Issue.record("\(name) 없음"); continue }
            let floor = image.luminances(rows: (image.height * 7 / 10)..<image.height).sorted()
            let worst = theme.colorScheme == .dark ? floor[floor.count * 9 / 10] : floor[floor.count / 10]
            let roles: [(String, Color)] = [
                ("primary", theme.onPagePrimary),
                ("body", theme.onPageBody),
                ("secondary", theme.onPageSecondary),
            ]
            for (role, color) in roles {
                let ratio = contrast(luminance(color), worst)
                #expect(ratio >= 3, "\(theme).\(role) 바닥 대비 \(ratio)")
            }
        }
    }

    // MARK: - 카드(테마색으로 물든 진한 타일)

    @Test func nestCardsMatchLegacyTokens() {
        // 회귀: 기본 테마 카드 = 기존 카드색 그대로.
        #expect(AppTheme.nest.cardBackground == AppColor.cardBackground)
        #expect(AppTheme.nest.cardBackgroundMuted == AppColor.cardBackgroundMuted)
        #expect(AppTheme.nest.cardBorder == AppColor.border)
    }

    @Test func cardTextIsReadableOnEveryTheme() {
        // 카드 안 글자는 테마와 무관하게 AppColor 그대로 → 물든 카드 위에서도 읽혀야 한다.
        let inCard: [(String, Color)] = [
            ("textPrimary", AppColor.textPrimary),
            ("textBody", AppColor.textBody),
            ("textSecondary", AppColor.textSecondary),
            ("eggAccent", AppColor.eggAccent),
            ("rare", AppColor.rare),
            ("legendary", AppColor.legendary),
            ("success", AppColor.success),
            ("danger", AppColor.danger),
        ]
        for theme in AppTheme.allCases {
            for (role, color) in inCard {
                let ratio = contrast(color, theme.cardBackground)
                #expect(ratio >= 4.5, "\(theme) 카드 위 \(role) 대비 \(ratio)")
            }
        }
    }

    // MARK: - helpers

    /// WCAG 2.x 상대 휘도 대비.
    private func contrast(_ a: Color, _ b: Color) -> Double {
        contrast(luminance(a), luminance(b))
    }

    private func contrast(_ la: Double, _ lb: Double) -> Double {
        (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private func luminance(_ color: Color) -> Double {
        let c = rgb(color)
        return Self.luminance(c[0], c[1], c[2])
    }

    /// 0~255 sRGB 정수.
    private func rgb(_ color: Color) -> [Int] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b].map { Int(($0 * 255).rounded()) }
    }

    static func luminance(_ r: Int, _ g: Int, _ b: Int) -> Double {
        func linear(_ v: Int) -> Double {
            let v = Double(v) / 255
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }
}

/// 앱 번들 그림을 픽셀 격자 그대로 읽는다(배경 에셋은 270×480 / 480×360 원본 격자, sRGB 불투명).
private struct BundleImage {
    let width: Int
    let height: Int
    private let rgba: [UInt8]

    @MainActor
    init?(_ name: String) {
        guard let cg = UIImage(named: name)?.cgImage,
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let (w, h) = (cg.width, cg.height)
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = data.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))   // 메모리 첫 줄 = 그림 맨 위
            return true
        }
        guard drawn else { return nil }
        (width, height, rgba) = (w, h, data)
    }

    private func pixel(_ x: Int, _ y: Int) -> [Int] {
        let i = (y * width + x) * 4
        return [Int(rgba[i]), Int(rgba[i + 1]), Int(rgba[i + 2])]
    }

    /// 이 줄들에서 가장 많이 쓰인 색.
    func dominantColor(rows: Range<Int>) -> [Int] {
        var counts: [[Int]: Int] = [:]
        for y in rows { for x in 0..<width { counts[pixel(x, y), default: 0] += 1 } }
        return counts.max { $0.value < $1.value }!.key
    }

    /// 이 줄들의 픽셀별 상대 휘도.
    func luminances(rows: Range<Int>) -> [Double] {
        rows.flatMap { y in (0..<width).map { x in
            let p = pixel(x, y)
            return AppThemeTests.luminance(p[0], p[1], p[2])
        } }
    }
}
