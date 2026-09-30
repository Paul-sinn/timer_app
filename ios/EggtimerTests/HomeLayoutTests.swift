//
//  HomeLayoutTests.swift
//  EggtimerTests
//
//  홈 화면 크기 대응 규칙 검증. 아이폰에선 알 무대가 예전 그대로(240pt)여야 하고,
//  아이패드처럼 키 큰 창에서만 커지며, 좁은 창에선 폭을 넘지 않아야 한다.
//  (실제로 공간이 모자랄 때 더 줄어드는 건 레이아웃이 min~max 사이에서 처리한다.)
//

import CoreGraphics
import Testing
@testable import Eggtimer

struct HomeLayoutTests {

    // MARK: - 한 컬럼(아이폰·아이패드 세로·Split View)

    @Test func iPhoneStageIsSlightlyBiggerThanBefore() {
        // 라운드2: 아이폰 알을 예전(240)보다 ~8% 키운다. 폭·높이와 무관하게 상한은 기본값.
        #expect(HomeLayout.stageBaseHeight == 260)
        // iPhone 17 Pro(콘텐츠 폭 354 · 높이 ~729), Pro Max(392 · ~811).
        #expect(HomeLayout.stageMaxHeight(containerSize: CGSize(width: 354, height: 729)) == 260)
        #expect(HomeLayout.stageMaxHeight(containerSize: CGSize(width: 392, height: 811)) == 260)
        // 작은 창도 상한은 같다 — 더 줄이는 건 레이아웃(최소 stageMinHeight)이 한다.
        #expect(HomeLayout.stageMaxHeight(containerSize: CGSize(width: 327, height: 598)) == 260)
    }

    @Test func iPadPortraitStageGrowsWithHeight() {
        // iPad 11" 세로(콘텐츠 폭 ~720 · 높이 ~1090): 420~460.
        let portrait = HomeLayout.stageMaxHeight(containerSize: CGSize(width: 720, height: 1090))
        #expect(portrait >= 420)
        #expect(portrait <= 460)
        // 아주 큰 창도 상한을 넘지 않는다.
        #expect(HomeLayout.stageMaxHeight(containerSize: CGSize(width: 900, height: 3000)) == HomeLayout.stageMaxHeight)
    }

    @Test func narrowTallWindowNeverGrowsWiderThanTheColumn() {
        // Split View 좁은 창(폭 272 · 키 1090): 키만 보고 키우면 알이 옆으로 삐져나간다.
        #expect(HomeLayout.stageMaxHeight(containerSize: CGSize(width: 272, height: 1090)) == 272)
    }

    @Test func stageRangeIsValid() {
        #expect(HomeLayout.stageMinHeight < HomeLayout.stageBaseHeight)
        #expect(HomeLayout.stageBaseHeight < HomeLayout.stageMaxHeight)
    }

    // MARK: - 좌우 2단(아이패드 가로)

    @Test func sideBySideStageIsBiggerThanTheOldCap() {
        // iPad 가로(왼쪽 컬럼 ~526 폭 · 높이 ~740): 예전 상한 360보다 크게, 높이의 55%.
        let landscape = HomeLayout.sideBySideStageMaxHeight(columnSize: CGSize(width: 526, height: 740))
        #expect(landscape > 360)
        #expect(landscape <= HomeLayout.stageMaxHeight)
    }

    @Test func sideBySideStageIsLimitedByColumnWidthAndHeight() {
        // 폭이 좁으면 폭까지.
        #expect(HomeLayout.sideBySideStageMaxHeight(columnSize: CGSize(width: 300, height: 900)) == 300)
        // 키가 낮으면 높이의 일부까지(말풍선·배지 자리 확보).
        let short = HomeLayout.sideBySideStageMaxHeight(columnSize: CGSize(width: 526, height: 400))
        #expect(short < 400)
        #expect(short >= HomeLayout.stageMinHeight)
        // 극단적으로 작아도 최소값 아래로는 안 내려간다.
        #expect(HomeLayout.sideBySideStageMaxHeight(columnSize: CGSize(width: 80, height: 80)) == HomeLayout.stageMinHeight)
    }

    // MARK: - 좌우 여백(아이패드 세로에서 가운데 몰림 방지)

    @Test func compactWidthKeepsTheIPhoneMargin() {
        // 아이폰·Split View 좁은 창은 예전 여백 그대로.
        #expect(HomeLayout.horizontalMargin(forWidth: 320) == 24)
        #expect(HomeLayout.horizontalMargin(forWidth: 402) == 24)
        #expect(HomeLayout.horizontalMargin(forWidth: 440) == 24)
    }

    @Test func regularWidthUsesAProportionalMargin() {
        // iPad 세로(820): 여백이 폭에 비례해 커지되 콘텐츠가 폭의 85% 이상을 쓴다.
        let margin = HomeLayout.horizontalMargin(forWidth: 820)
        #expect(margin > 24)
        #expect((820 - margin * 2) / 820 >= 0.85)
    }

    // MARK: - 타이머 글자 크기

    @Test func timerFontStaysOnIPhoneAndGrowsOnWideWindows() {
        #expect(HomeLayout.timerFontSize(forWidth: 320) == HomeLayout.timerBaseFontSize)
        #expect(HomeLayout.timerFontSize(forWidth: 402) == HomeLayout.timerBaseFontSize)
        let portrait = HomeLayout.timerFontSize(forWidth: 820)
        #expect(portrait > HomeLayout.timerBaseFontSize)
        #expect(portrait <= HomeLayout.timerMaxFontSize)
        #expect(HomeLayout.timerFontSize(forWidth: 2000) == HomeLayout.timerMaxFontSize)
    }

    // MARK: - 섬광 발광 지점(전역 → 오버레이 로컬 좌표)

    @Test func revealOriginIsConvertedIntoOverlaySpace() {
        // 오버레이가 창 원점에 있으면 그대로.
        let same = HatchRevealOverlay.localCenter(origin: CGPoint(x: 200, y: 300),
                                                  overlayFrame: CGRect(x: 0, y: 0, width: 400, height: 800))
        #expect(same == CGPoint(x: 200, y: 300))
        // 오버레이가 창 안에서 밀려 있으면(Split View 오른쪽 등) 그만큼 뺀다.
        let shifted = HatchRevealOverlay.localCenter(origin: CGPoint(x: 700, y: 300),
                                                     overlayFrame: CGRect(x: 500, y: 20, width: 400, height: 800))
        #expect(shifted == CGPoint(x: 200, y: 280))
        // 발광 지점을 모르면 오버레이 중앙.
        let fallback = HatchRevealOverlay.localCenter(origin: nil,
                                                      overlayFrame: CGRect(x: 500, y: 20, width: 400, height: 800))
        #expect(fallback == CGPoint(x: 200, y: 400))
    }
}
