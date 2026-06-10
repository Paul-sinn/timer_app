//
//  Color+Hex.swift
//  Eggtimer
//
//  Color 를 0xRRGGBB 정수 리터럴로 생성하는 헬퍼.
//  UI_GUIDE.md 색상표를 그대로 토큰화하기 위한 단일 진입점.
//

import SwiftUI

extension Color {
    /// 0xRRGGBB 형식의 16진수 값으로 Color 를 만든다. (다크모드 고정이라 항상 불투명)
    init(hex: UInt32, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
