//
//  OnboardingLayoutTests.swift
//  EggtimerTests
//
//  온보딩 일러스트/글씨 확대 규칙 검증. 아이폰은 반드시 배율 1(기존 모습 그대로),
//  큰 아이패드 창에서만 화면 비율에 맞춰 키운다.
//

import Testing
import SwiftUI
@testable import Eggtimer

@MainActor
struct OnboardingLayoutTests {

    // MARK: - artScale (창 크기 → 일러스트 배율)

    /// 모든 아이폰(세로·가로)은 배율 1 — 아이폰 화면이 바뀌면 안 된다.
    @Test(arguments: [
        CGSize(width: 375, height: 667),   // iPhone SE
        CGSize(width: 402, height: 874),   // iPhone 17 Pro
        CGSize(width: 420, height: 912),   // iPhone Air
        CGSize(width: 440, height: 956),   // iPhone 17 Pro Max
        CGSize(width: 956, height: 440),   // Pro Max 가로
    ])
    func iPhonesStayAtOne(size: CGSize) {
        #expect(OnboardingLayout.artScale(width: size.width, height: size.height) == 1)
    }

    /// iPad Air 11" 세로는 확대된다(높이가 제한 요인).
    @Test func iPadAirPortraitScalesUp() {
        let s = OnboardingLayout.artScale(width: 820, height: 1180)
        #expect(abs(s - 1180.0 / 852.0) < 0.001)
        #expect(s > 1.3)
    }

    /// iPad mini 세로도 확대된다.
    @Test func iPadMiniPortraitScalesUp() {
        let s = OnboardingLayout.artScale(width: 744, height: 1133)
        #expect(abs(s - 1133.0 / 852.0) < 0.001)
    }

    /// iPad Air 가로는 높이가 짧아 확대하지 않는다(기존 레이아웃이 들어간다).
    @Test func iPadAirLandscapeStaysAtOne() {
        #expect(OnboardingLayout.artScale(width: 1180, height: 820) == 1)
    }

    /// 아주 큰 창도 상한(1.6)을 넘지 않는다.
    @Test func capsAtMaximum() {
        #expect(OnboardingLayout.artScale(width: 2000, height: 3000) == OnboardingLayout.maxScale)
    }

    /// Split View처럼 좁고 긴 창은 폭이 제한 요인이라 1.
    @Test func narrowSplitViewStaysAtOne() {
        #expect(OnboardingLayout.artScale(width: 320, height: 1180) == 1)
    }

    /// 크기를 아직 모를 때(0)도 1.
    @Test func zeroSizeIsOne() {
        #expect(OnboardingLayout.artScale(width: 0, height: 0) == 1)
    }

    // MARK: - textSize (배율 → 글씨 크기 단계)

    /// 배율 1이면 사용자 글씨 크기를 그대로 둔다.
    @Test func noScaleKeepsUserTextSize() {
        #expect(OnboardingLayout.textSize(.large, scale: 1) == .large)
        #expect(OnboardingLayout.textSize(.xSmall, scale: 1.1) == .xSmall)
    }

    /// 확대되면 한 단계, 크게 확대되면 두 단계 키운다.
    @Test func scaledUpBumpsTextSize() {
        #expect(OnboardingLayout.textSize(.large, scale: 1.38) == .xLarge)
        #expect(OnboardingLayout.textSize(.large, scale: 1.6) == .xxLarge)
    }

    /// 표준 크기 상한(xxxLarge)을 넘겨 접근성 크기로 올리지 않는다.
    @Test func bumpCapsAtLargestStandardSize() {
        #expect(OnboardingLayout.textSize(.xxLarge, scale: 1.6) == .xxxLarge)
    }

    /// 이미 접근성 글씨 크기를 쓰는 사용자는 건드리지 않는다.
    @Test func accessibilitySizesUntouched() {
        #expect(OnboardingLayout.textSize(.accessibility2, scale: 1.6) == .accessibility2)
    }
}
