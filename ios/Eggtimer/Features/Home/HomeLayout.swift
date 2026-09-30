//
//  HomeLayout.swift
//  Eggtimer
//
//  홈 화면 크기 대응 규칙(순수 계산 — HomeLayoutTests가 검증).
//  알/캐릭터 "무대"의 높이 상한만 정한다. 실제 높이는 레이아웃이 남는 공간을 보고
//  stageMinHeight ~ 상한 사이에서 고른다(짧은 화면에선 알이 줄어들어 버튼이 안 잘린다).
//

import SwiftUI

enum HomeLayout {
    /// 아이폰 기본 무대 높이. 처음엔 240이었는데 알이 작아 보여 ~8% 키웠다(라운드2).
    static let stageBaseHeight: CGFloat = 260
    /// 공간이 모자랄 때 무대가 줄어드는 하한. 이보다도 안 들어가면 화면이 스크롤된다.
    static let stageMinHeight: CGFloat = 120
    /// 아이패드처럼 큰 창에서 무대가 커질 수 있는 상한.
    static let stageMaxHeight: CGFloat = 460
    /// 이 높이를 넘는 창부터 무대를 키운다(아이폰 Pro Max 콘텐츠 높이 ~811보다 크게 잡는다).
    static let tallContainerHeight: CGFloat = 900
    /// 키 큰 창에서 초과 높이 1pt당 무대를 몇 pt 키울지. iPad 11" 세로(~1090) → ~450.
    static let stageGrowthPerPoint: CGFloat = 1.0

    /// 이 폭부터 "넓은 창"(아이패드 전체폭 등)으로 보고 여백·타이머를 키운다.
    /// 아이폰(최대 ~440)·Split View 좁은 창은 이보다 좁아 예전 그대로.
    static let regularWidth: CGFloat = AppLayout.readableWidth
    /// 넓은 창의 좌우 여백 비율(폭의 6% → 콘텐츠가 폭의 ~88%를 쓴다).
    static let regularMarginRatio: CGFloat = 0.06

    /// 타이머 글자 크기. 기본값은 AppFont.timer와 같은 64(아이폰 그대로), 넓은 창에서 최대 96.
    static let timerBaseFontSize: CGFloat = 64
    static let timerMaxFontSize: CGFloat = 96

    /// 한 컬럼 레이아웃의 무대 높이 상한.
    /// - Parameter containerSize: 콘텐츠 컬럼 폭(좌우 여백 제외) × 홈 화면 높이.
    /// 아이폰에선 항상 240. 키 큰 창에서만 커지되, 컬럼 폭을 넘지 않는다(Split View 좁은 창).
    static func stageMaxHeight(containerSize: CGSize) -> CGFloat {
        let extra = max(0, containerSize.height - tallContainerHeight) * stageGrowthPerPoint
        let grown = min(stageMaxHeight, stageBaseHeight + extra)
        return max(stageBaseHeight, min(grown, containerSize.width))
    }

    /// 좌우 2단(아이패드 가로)에서 왼쪽 컬럼 무대 높이 상한.
    /// 컬럼 폭과 높이의 55%(말풍선·진화 배지 자리 확보) 중 작은 값, stageMinHeight~stageMaxHeight.
    static func sideBySideStageMaxHeight(columnSize: CGSize) -> CGFloat {
        let fit = min(columnSize.height * 0.55, columnSize.width)
        return min(stageMaxHeight, max(stageMinHeight, fit))
    }

    /// 한 컬럼 레이아웃의 좌우 여백. 좁은 창은 AppSpacing.section(예전 그대로),
    /// 넓은 창은 폭에 비례 — 가운데 600pt에 몰리지 않고 양쪽 여백이 고르게 벌어진다.
    static func horizontalMargin(forWidth width: CGFloat) -> CGFloat {
        guard width >= regularWidth else { return AppSpacing.section }
        return max(AppSpacing.section, width * regularMarginRatio)
    }

    /// 타이머 글자 크기. 좁은 창은 기본값, 넓은 창은 폭에 비례해 키우고 상한에서 멈춘다.
    static func timerFontSize(forWidth width: CGFloat) -> CGFloat {
        guard width >= regularWidth else { return timerBaseFontSize }
        return min(timerMaxFontSize, timerBaseFontSize * width / regularWidth)
    }
}

extension AppFont {
    /// AppFont.timer와 같은 스타일을 크기만 바꿔서. 아이패드 넓은 창의 큰 타이머용.
    static func timer(size: CGFloat) -> Font {
        size == HomeLayout.timerBaseFontSize
            ? timer
            : Font.system(size: size, weight: .bold, design: .rounded).monospacedDigit()
    }
}
