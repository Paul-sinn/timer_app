//
//  ProAccess.swift
//  Eggtimer
//
//  "Hatcho Pro"(번들 유료 언락) 접근 여부의 단일 진실 소스.
//  1.0은 결제 미도입 → 항상 잠금(false). 잠긴 콘텐츠는 화면에서 "출시 예정"으로만 노출한다.
//  1.1에서 StoreKit `Transaction.currentEntitlements`가 `isPro`를 채우도록 이 타입 구현만 교체(seam) —
//  호출부(테마 피커 등)는 손대지 않는다.
//
//  DEBUG 빌드는 검수용 토글로 게이트 콘텐츠를 미리 볼 수 있다(릴리스엔 토글 코드 자체가 없음).
//  저장은 기존 설정과 동일하게 UserDefaults(테스트는 격리 suite 주입).
//

import Foundation
import Observation

@Observable
@MainActor
final class ProAccess {
    @ObservationIgnored private let defaults: UserDefaults

    /// Pro 콘텐츠 접근 가능 여부. 뷰는 이 값만 보고 게이트한다.
    private(set) var isPro: Bool

    #if DEBUG
    /// 검수용 언락 플래그 키(DEBUG 전용).
    private static let debugKey = "debug.proUnlocked"
    #endif

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        #if DEBUG
        self.isPro = defaults.bool(forKey: Self.debugKey)   // 검수 토글 복원
        #else
        self.isPro = false                                  // 1.0: 결제 미도입. 1.1 StoreKit으로 대체.
        #endif
    }

    #if DEBUG
    /// 검수용: Pro 잠금/해제 토글(UserDefaults 영속).
    func setDebugPro(_ on: Bool) {
        defaults.set(on, forKey: Self.debugKey)
        isPro = on
    }
    #endif
}
