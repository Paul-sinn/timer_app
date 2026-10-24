//
//  AppThemeTests.swift
//  EggtimerTests
//
//  배경 테마 순수 로직 검증. 기본 폴백·무료/잠금 파티션·기존 배경 회귀·
//  그림 에셋 존재·배경 위 글자 가독(대비)·라이트/다크 구분.
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
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private func luminance(_ color: Color) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        func linear(_ v: CGFloat) -> Double {
            let v = Double(v)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }
}
