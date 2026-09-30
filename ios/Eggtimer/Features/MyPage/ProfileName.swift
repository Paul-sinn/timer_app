//
//  ProfileName.swift
//  Eggtimer
//
//  프로필 닉네임 규칙의 단일 출처. 유저가 직접 입력한 이름을 저장 전에 다듬고,
//  저장값이 없을 때 무엇을 보여줄지 정한다. 순수 함수라 유닛 테스트로 검증한다
//  (ProfileNameTests) — 뷰에서 trim/자르기를 재구현하면 규칙이 갈라진다.
//
//  저장은 UserDefaults(@AppStorage). SwiftData @Model을 건드리지 않으므로
//  마이그레이션 위험이 없다.
//

import Foundation

enum ProfileName {
    /// 저장 가능한 최대 글자 수(Character 기준 — 이모지 1개 = 1글자).
    /// 프로필 헤더가 한 줄에 들어가는 길이.
    static let maxLength = 20

    /// 아직 이름을 정하지 않은 유저에게 보여줄 기본 이름.
    static let fallback = String(localized: "Guest")

    /// 입력값을 저장 형태로 다듬는다.
    /// - Returns: 저장할 이름. 앞뒤 공백을 걷어낸 뒤 비면 `nil`(= 저장하지 않음).
    static func normalize(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxLength))
    }

    /// 화면에 그릴 이름. 저장값이 비었으면 기본 이름으로 대체한다.
    static func display(stored: String) -> String {
        normalize(stored) ?? fallback
    }
}
