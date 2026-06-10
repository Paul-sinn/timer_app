//
//  AppSpacing.swift
//  Eggtimer
//
//  UI_GUIDE.md 레이아웃 간격의 단일 출처.
//  - 요소 간: 12~16
//  - 섹션 간: 24~32
//  - 카드/버튼 모서리/패딩 등 공통 수치
//

import Foundation

enum AppSpacing {
    // 요소 간 간격
    static let elementTight: CGFloat = 12
    static let element: CGFloat = 16

    // 섹션 간 간격
    static let section: CGFloat = 24
    static let sectionLoose: CGFloat = 32

    // 컴포넌트 내부 패딩
    static let cardPadding: CGFloat = 16

    // 모서리 반경
    static let cardCornerRadius: CGFloat = 14
    static let buttonCornerRadius: CGFloat = 12

    // 보더 두께
    static let borderWidth: CGFloat = 1
}
