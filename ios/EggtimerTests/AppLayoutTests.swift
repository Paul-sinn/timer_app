//
//  AppLayoutTests.swift
//  EggtimerTests
//
//  iPad(유니버설) 대응 레이아웃 규칙 검증. "화면 폭 → 열 개수/가로 배치 여부"를
//  뷰에서 분리해, 아이패드·Split View·작은 아이폰 모두 같은 규칙으로 판단하게 한다.
//

import Testing
import Foundation
@testable import Eggtimer

@MainActor
struct AppLayoutTests {

    // MARK: - gridColumns (폭에 맞는 열 개수)

    /// 아이폰 폭(393)에선 기존처럼 3열 — 아이폰 화면이 바뀌면 안 된다.
    @Test func iPhoneWidthKeepsThreeColumns() {
        #expect(AppLayout.gridColumns(forWidth: 393, minItemWidth: 100, spacing: 12) == 3)
    }

    /// 넓은 아이패드 가로 화면에선 열이 늘어난다(카드가 거대해지지 않게).
    @Test func iPadWidthAddsColumns() {
        #expect(AppLayout.gridColumns(forWidth: 1180, minItemWidth: 100, spacing: 12) == 10)
    }

    /// 아이템 하나도 못 들어가는 폭이어도 최소 1열(0열이면 그리드가 사라진다).
    @Test func neverReturnsZeroColumns() {
        #expect(AppLayout.gridColumns(forWidth: 50, minItemWidth: 100, spacing: 12) == 1)
        #expect(AppLayout.gridColumns(forWidth: 0, minItemWidth: 100, spacing: 12) == 1)
    }

    /// 상한을 주면 그 이상으로 늘리지 않는다.
    @Test func respectsMaxColumns() {
        #expect(AppLayout.gridColumns(forWidth: 1366, minItemWidth: 100, spacing: 12, maxColumns: 6) == 6)
    }

    // MARK: - usesSideBySide (좌우 2단 배치 여부)

    /// 아이폰 세로·Split View 좁은 창은 세로 1단.
    @Test func narrowIsStacked() {
        #expect(AppLayout.usesSideBySide(width: 393, height: 852) == false)
        #expect(AppLayout.usesSideBySide(width: 507, height: 820) == false)
    }

    /// 아이패드 가로(넓고 낮음)는 좌우 2단.
    @Test func wideLandscapeIsSideBySide() {
        #expect(AppLayout.usesSideBySide(width: 1180, height: 820) == true)
    }

    /// 아이패드 세로는 폭이 넓어도 세로가 더 길면 1단(가운데 정렬 컬럼).
    @Test func iPadPortraitIsStacked() {
        #expect(AppLayout.usesSideBySide(width: 820, height: 1180) == false)
    }
}
