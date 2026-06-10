//
//  AppFont.swift
//  Eggtimer
//
//  UI_GUIDE.md 타이포그래피 표의 단일 출처.
//  - 타이머 숫자: 대형 모노스페이스 계열, 굵게
//  - 화면 제목: title2, semibold
//  - 카드 제목: footnote, medium
//  - 본문: body
//

import SwiftUI

enum AppFont {
    /// 타이머 숫자. 대형 모노스페이스 + 굵게. (홈 화면 중앙 타이머)
    static let timer = Font.system(size: 64, weight: .bold, design: .monospaced)

    /// 화면 제목. title2 semibold.
    static let screenTitle = Font.title2.weight(.semibold)

    /// 카드 제목. footnote medium.
    static let cardTitle = Font.footnote.weight(.medium)

    /// 본문. body.
    static let body = Font.body
}
