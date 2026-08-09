//
//  AppFont.swift
//  Eggtimer
//
//  UI_GUIDE.md 타이포그래피 표의 단일 출처.
//  테마 "Nest": 디스플레이/제목/타이머 숫자는 SF Pro Rounded(친근한 라운드), 본문은 SF Pro Text.
//  - 타이머 숫자: 대형 라운드 + 굵게 + 탭ular digit(자리 안 튀게)
//  - 화면 제목: title2 라운드 bold
//  - 카드 제목: footnote 라운드 semibold
//  - 본문: body (SF Pro Text, 기본 디자인)
//

import SwiftUI

enum AppFont {
    /// 타이머 숫자. 대형 라운드 + 굵게, 자릿수 고정(monospacedDigit). (홈 화면 중앙 타이머)
    static let timer = Font.system(size: 64, weight: .bold, design: .rounded).monospacedDigit()

    /// 화면 제목. title2 라운드 bold.
    static let screenTitle = Font.system(.title2, design: .rounded).weight(.bold)

    /// 카드 제목. footnote 라운드 semibold.
    static let cardTitle = Font.system(.footnote, design: .rounded).weight(.semibold)

    /// 본문. body (SF Pro Text).
    static let body = Font.body
}
