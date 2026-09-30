//
//  CollectionLayoutTests.swift
//  EggtimerTests
//
//  컬렉션 그리드 열 개수 규칙 검증(아이패드 유니버설 대응).
//  "그리드 실제 폭 → 열 개수"만 본다. 아이폰은 기존 3열을 그대로 유지해야 한다.
//

import Testing
import Foundation
@testable import Eggtimer

@MainActor
struct CollectionLayoutTests {

    /// 폭을 아직 못 쟀을 때(첫 프레임)는 기존 3열 — 아이폰에서 열이 튀지 않게.
    @Test func unmeasuredWidthFallsBackToThreeColumns() {
        #expect(CollectionView.columnCount(forGridWidth: nil) == 3)
    }

    /// 아이폰(375·402pt 화면 − 좌우 패딩 24×2)은 기존 3열 그대로.
    @Test func iPhoneWidthsKeepThreeColumns() {
        #expect(CollectionView.columnCount(forGridWidth: 375 - 48) == 3)
        #expect(CollectionView.columnCount(forGridWidth: 402 - 48) == 3)
        #expect(CollectionView.columnCount(forGridWidth: 440 - 48) == 3)
    }

    /// 아이패드는 카드를 키운다(최소 160pt) — 세로 4열, 가로 6열, mini 세로 4열.
    @Test func iPadWidthsUseBiggerCards() {
        #expect(CollectionView.columnCount(forGridWidth: 744 - 48) == 4)   // iPad mini 세로
        #expect(CollectionView.columnCount(forGridWidth: 820 - 48) == 4)   // iPad Air 세로
        #expect(CollectionView.columnCount(forGridWidth: 1100 - 48) == 6)  // 가로(최대 폭 1100 캡)
    }

    /// Split View처럼 좁은 창은 기존 규칙(작은 카드) 그대로.
    @Test func narrowSplitViewUsesFewerColumns() {
        #expect(CollectionView.columnCount(forGridWidth: 320 - 48) == 2)
        #expect(CollectionView.columnCount(forGridWidth: 500 - 48) == 4)
    }

    /// 창을 넓힐수록 열이 줄어드는 역전이 없어야 한다(좁은 규칙 ↔ 넓은 규칙 경계에서 튀지 않게).
    @Test func columnCountNeverDecreasesAsWidthGrows() {
        var previous = 0
        for width in stride(from: CGFloat(200), through: 1100, by: 1) {
            let count = CollectionView.columnCount(forGridWidth: width)
            #expect(count >= previous, "width \(width): \(count) < \(previous)")
            previous = count
        }
    }

    // MARK: - 카드 내용 배율 (이미지·글자·여백)

    /// 아이폰(측정 전 포함)은 배율 1 — 기존 모습 그대로.
    @Test func iPhoneCardsKeepScaleOne() {
        #expect(CollectionView.cardContentScale(forGridWidth: nil) == 1)
        // 창 폭 - 좌우 패딩 48 (375/393/402/440). 식을 배열 안에 쓰면 타입 추론이 폭주한다.
        let gridWidths: [CGFloat] = [327, 345, 354, 392]
        for width in gridWidths {
            #expect(CollectionView.cardContentScale(forGridWidth: width) == 1)
        }
    }

    /// 아이패드의 큰 카드는 내용도 함께 커진다(카드만 크고 그림이 작은 문제 방지).
    @Test func iPadCardsScaleContentUp() {
        #expect(CollectionView.cardContentScale(forGridWidth: 820 - 48) > 1.4)
        #expect(CollectionView.cardContentScale(forGridWidth: 1100 - 48) > 1.3)
        #expect(CollectionView.cardContentScale(forGridWidth: 744 - 48) > 1.3)
    }
}
