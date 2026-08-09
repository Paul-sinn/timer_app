//
//  AppThemeTests.swift
//  EggtimerTests
//
//  배경 테마 순수 로직 검증. 기본 폴백·무료/잠금 파티션·기존 배경 회귀.
//

import Testing
import SwiftUI
import Foundation
@testable import Eggtimer

struct AppThemeTests {

    @Test func currentFallsBackToNest() {
        let defaults = UserDefaults(suiteName: "test.theme.\(UUID().uuidString)")!
        #expect(AppTheme.current(defaults) == .nest)          // 저장값 없음 → 기본

        defaults.set("bogus-not-a-theme", forKey: AppTheme.storageKey)
        #expect(AppTheme.current(defaults) == .nest)          // 무효값 → 기본

        defaults.set(AppTheme.midnight.rawValue, forKey: AppTheme.storageKey)
        #expect(AppTheme.current(defaults) == .midnight)      // 유효값 라운드트립
    }

    @Test func freeAndLockedPartitionCoversAllCases() {
        #expect(AppTheme.free.allSatisfy { !$0.isPro })
        #expect(AppTheme.locked.allSatisfy { $0.isPro })
        #expect(AppTheme.free.contains(.nest))                // 기본은 무료
        #expect(!AppTheme.free.isEmpty)
        // MVP엔 실제 Pro 테마 없음 → locked 비어있음(placeholder 미끼 안 만듦).
        #expect(AppTheme.locked.isEmpty)
        // 무료 ∪ 잠금 = 전체, 겹침 없음.
        #expect(AppTheme.free.count + AppTheme.locked.count == AppTheme.allCases.count)
    }

    @Test func nestReusesLegacyPageBackground() {
        // 회귀: 기본 테마 배경 = 기존 페이지색(단일 출처 재사용).
        #expect(AppTheme.nest.pageBackground == AppColor.pageBackground)
    }
}
