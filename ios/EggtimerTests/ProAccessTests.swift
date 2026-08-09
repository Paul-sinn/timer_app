//
//  ProAccessTests.swift
//  EggtimerTests
//
//  "Hatchly Pro" 접근 게이트 검증. 1.0은 결제 미도입 → 기본 잠금(false).
//  DEBUG 검수 토글이 UserDefaults에 영속되는지 확인. 격리된 suite로 표준 defaults 오염 방지.
//

import Testing
import Foundation
@testable import Eggtimer

@MainActor
struct ProAccessTests {

    /// 매 테스트 격리용 임시 UserDefaults(표준 슬롯 오염 금지).
    private func freshDefaults() -> UserDefaults {
        let suite = "test.pro.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func defaultsToLocked() {
        let pro = ProAccess(defaults: freshDefaults())
        #expect(pro.isPro == false)   // 결제 없음 → 잠금
    }

    #if DEBUG
    @Test func debugToggleUnlocksAndPersists() {
        let defaults = freshDefaults()
        let pro = ProAccess(defaults: defaults)
        pro.setDebugPro(true)
        #expect(pro.isPro == true)

        // 같은 defaults로 재생성해도 해제 상태 유지(영속).
        let restored = ProAccess(defaults: defaults)
        #expect(restored.isPro == true)

        pro.setDebugPro(false)
        #expect(pro.isPro == false)
    }
    #endif
}
