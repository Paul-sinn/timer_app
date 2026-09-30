//
//  AppLayout.swift
//  Eggtimer
//
//  화면 크기 대응(아이폰·아이패드·Split View) 레이아웃 규칙의 단일 출처.
//  - 크기 판단은 기기 종류가 아니라 "실제로 받은 창 크기"로 한다
//    (아이패드도 Split View/Stage Manager에선 아이폰만큼 좁아질 수 있다).
//  - 순수 함수는 AppLayoutTests가 검증한다.
//

import SwiftUI

enum AppLayout {
    /// 글·버튼·목록 컬럼의 최대 폭. 아이패드에서 한 줄이 화면 끝까지 늘어나지 않게 한다.
    static let readableWidth: CGFloat = 600
    /// 좌우 2단 화면의 전체 최대 폭.
    static let wideContentWidth: CGFloat = 1100
    /// 좌우 2단으로 바꾸는 최소 폭.
    static let sideBySideMinWidth: CGFloat = 700

    /// 주어진 폭에 `minItemWidth` 이상 카드가 몇 개 들어가는지. 최소 1, `maxColumns`로 상한.
    static func gridColumns(forWidth width: CGFloat,
                            minItemWidth: CGFloat,
                            spacing: CGFloat,
                            maxColumns: Int = .max) -> Int {
        guard width > 0, minItemWidth > 0 else { return 1 }
        let count = Int(((width + spacing) / (minItemWidth + spacing)).rounded(.down))
        return min(max(count, 1), maxColumns)
    }

    /// 좌우 2단 배치를 쓸지. 충분히 넓고 가로가 더 긴(가로 모드) 창일 때만.
    static func usesSideBySide(width: CGFloat, height: CGFloat) -> Bool {
        width >= sideBySideMinWidth && width > height
    }
}

extension View {
    /// 콘텐츠를 `maxWidth` 이하로 제한하고 가운데 정렬한다. 아이폰 폭에선 아무 변화 없음.
    func readableWidth(_ maxWidth: CGFloat = AppLayout.readableWidth) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}
