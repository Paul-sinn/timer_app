//
//  ProAccess.swift
//  Eggtimer
//
//  유료 콘텐츠 접근 여부의 단일 진실 소스.
//  - 월드 팩(비소모성): StoreKit 2 `Transaction.currentEntitlements`가 보유 상품을 채운다 → `owns(_:)`.
//  - `isPro`: DEBUG 검수 토글(릴리스는 항상 false). 켜면 모든 팩·잠금 테마를 미리 볼 수 있다.
//  화면은 `owns(_:)`/`isPro`만 본다. 결제 흐름(구매·복원·환불 반영)은 이 타입 안에만 둔다.
//  저장: 보유 상태는 StoreKit이 기기에 보관하므로 따로 저장하지 않는다(매 실행 `start()`에서 다시 확인).
//

import Foundation
import Observation
import StoreKit

@Observable
@MainActor
final class ProAccess {
    @ObservationIgnored private let defaults: UserDefaults

    /// DEBUG 검수용 전체 잠금 해제. 릴리스 빌드는 항상 false.
    private(set) var isPro: Bool

    /// StoreKit이 확인한(검증·미환불) 보유 상품 ID.
    private(set) var ownedProductIDs: Set<String> = []

    #if DEBUG
    /// 검수용 언락 플래그 키(DEBUG 전용).
    private static let debugKey = "debug.proUnlocked"
    #endif

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        #if DEBUG
        self.isPro = defaults.bool(forKey: Self.debugKey)   // 검수 토글 복원
        #else
        self.isPro = false
        #endif
    }

    /// 이 월드를 쓸 수 있는지. 무료 월드는 항상 true.
    func owns(_ world: World) -> Bool {
        guard let id = world.productID else { return true }
        return isPro || ownedProductIDs.contains(id)
    }

    /// 확인된 보유 상품으로 교체한다(환불되면 빠진다). StoreKit 밖에서 검증 가능하게 분리.
    func applyEntitlements(_ productIDs: Set<String>) {
        ownedProductIDs = productIDs
    }

    #if DEBUG
    /// 검수용: Pro 잠금/해제 토글(UserDefaults 영속).
    func setDebugPro(_ on: Bool) {
        defaults.set(on, forKey: Self.debugKey)
        isPro = on
    }
    #endif

    // MARK: - StoreKit 2

    /// 앱 루트 `.task`에서 1회: 보유 확인 후, 결제 변경(다른 기기 구매·환불·승인 대기 완료)을 계속 반영한다.
    /// `.task`가 취소되면 루프도 끝난다 → 저장해 둘 Task·deinit 정리가 필요 없다.
    func start() async {
        await refreshEntitlements()
        for await update in Transaction.updates {
            if case .verified(let transaction) = update { await transaction.finish() }
            await refreshEntitlements()
        }
    }

    /// 지금 기기에 있는 보유 내역을 다시 읽는다.
    func refreshEntitlements() async {
        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                ids.insert(transaction.productID)
            }
        }
        applyEntitlements(ids)
    }

    /// 가격 표시용 상품 정보. 상품이 없으면(App Store Connect 미등록·오프라인) nil.
    func product(for world: World) async -> Product? {
        guard let id = world.productID else { return nil }
        return try? await Product.products(for: [id]).first
    }

    enum PurchaseOutcome { case purchased, pending, cancelled }

    enum PurchaseError: Error { case productUnavailable, unverified }

    func purchase(_ world: World) async throws -> PurchaseOutcome {
        guard let product = await product(for: world) else { throw PurchaseError.productUnavailable }
        switch try await product.purchase() {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { throw PurchaseError.unverified }
            await transaction.finish()
            await refreshEntitlements()
            return .purchased
        case .pending:
            return .pending          // 자녀 구매 승인 등. 승인되면 `start()`의 updates 루프가 반영한다.
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    /// 구매 복원(새 기기·재설치). 애플 계정 로그인 창이 뜰 수 있다.
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }
}
