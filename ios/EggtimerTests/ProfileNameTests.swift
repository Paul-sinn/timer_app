//
//  ProfileNameTests.swift
//  EggtimerTests
//
//  프로필 닉네임 정규화 규칙 검증. 저장 전에 다듬는 로직을 뷰에서 분리해
//  "빈 이름이 저장돼 화면이 비는" 사고를 막는다.
//

import Testing
import Foundation
@testable import Eggtimer

struct ProfileNameTests {

    // MARK: - normalize (저장할 값 다듬기)

    @Test func trimsSurroundingWhitespace() {
        #expect(ProfileName.normalize("  Paul  ") == "Paul")
        #expect(ProfileName.normalize("\nPaul\t") == "Paul")
    }

    /// 공백만 입력하면 저장하지 않는다(nil) — 저장되면 이름이 빈칸으로 보인다.
    @Test func rejectsBlankInput() {
        #expect(ProfileName.normalize("") == nil)
        #expect(ProfileName.normalize("   ") == nil)
        #expect(ProfileName.normalize("\n\t ") == nil)
    }

    /// 너무 긴 이름은 잘라서 저장한다(레이아웃 깨짐 방지).
    @Test func truncatesToMaxLength() {
        let long = String(repeating: "가", count: ProfileName.maxLength + 10)
        let normalized = ProfileName.normalize(long)
        #expect(normalized?.count == ProfileName.maxLength)
    }

    @Test func keepsNamesAtOrUnderMaxLength() {
        let exact = String(repeating: "a", count: ProfileName.maxLength)
        #expect(ProfileName.normalize(exact) == exact)
        #expect(ProfileName.normalize("짧은이름") == "짧은이름")
    }

    /// 이모지는 한 글자로 세야 한다(UTF-16 길이로 자르면 이모지가 깨진다).
    @Test func countsEmojiAsSingleCharacter() {
        let emoji = String(repeating: "🐣", count: ProfileName.maxLength)
        #expect(ProfileName.normalize(emoji) == emoji)

        let tooMany = String(repeating: "🐣", count: ProfileName.maxLength + 3)
        #expect(ProfileName.normalize(tooMany)?.count == ProfileName.maxLength)
    }

    // MARK: - display (화면에 그릴 값)

    /// 저장값이 없거나 공백뿐이면 기본 이름으로 대체한다.
    @Test func fallsBackWhenNothingStored() {
        #expect(ProfileName.display(stored: "") == ProfileName.fallback)
        #expect(ProfileName.display(stored: "   ") == ProfileName.fallback)
    }

    @Test func showsStoredNameWhenPresent() {
        #expect(ProfileName.display(stored: "Paul") == "Paul")
        #expect(ProfileName.display(stored: "  Paul  ") == "Paul")
    }

    /// 기본 이름은 비어 있으면 안 된다(빈 헤더 방지).
    @Test func fallbackIsNotEmpty() {
        #expect(!ProfileName.fallback.isEmpty)
    }
}
