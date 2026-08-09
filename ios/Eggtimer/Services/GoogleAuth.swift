//
//  GoogleAuth.swift
//  Eggtimer
//
//  Google 로그인 헬퍼(Phase 3). GoogleSignIn-iOS SDK가 프로젝트에 추가됐을 때만 컴파일된다
//  (#if canImport). SDK 미추가 상태에서도 앱이 빌드되도록 전체를 게이트로 감쌌다 —
//  사용자가 Xcode에서 패키지를 추가하면 Google 버튼이 자동 활성화된다.
//
//  Supabase 네이티브 Google 로그인: SDK로 받은 ID 토큰을 signInWithIdToken(.google)에 넘긴다.
//  (Supabase iOS는 Skip nonce check를 켜둠 → nonce 불필요)
//

import Foundation

#if canImport(GoogleSignIn)
import GoogleSignIn
import UIKit

enum GoogleAuth {
    /// Google Cloud Console에서 발급한 **iOS** OAuth 클라이언트 ID.
    /// ⚠️ 실제 값으로 교체할 것(예: "1234-abcd.apps.googleusercontent.com").
    /// URL scheme(reversed client ID)도 Info에 등록해야 콜백이 앱으로 돌아온다.
    static let iosClientID = "REPLACE_WITH_IOS_CLIENT_ID.apps.googleusercontent.com"

    /// Settings값이 채워졌는지(플레이스홀더면 버튼 숨김 판단에 사용).
    static var isConfigured: Bool { !iosClientID.hasPrefix("REPLACE_WITH") }

    /// 앱 Start 시 1회 호출.
    static func configure() {
        guard isConfigured else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: iosClientID)
    }

    /// OAuth 콜백 URL을 SDK로 전달(SwiftUI .onOpenURL에서 호출).
    @discardableResult
    static func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    enum GoogleAuthError: Error { case noPresenter, noIDToken }

    /// Google 로그인 시트를 띄우고 ID 토큰을 반환한다.
    @MainActor
    static func signIn() async throws -> String {
        guard let presenter = Self.topViewController() else { throw GoogleAuthError.noPresenter }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        guard let idToken = result.user.idToken?.tokenString else { throw GoogleAuthError.noIDToken }
        return idToken
    }

    /// 현재 화면 최상단 뷰컨트롤러(로그인 시트 presenting용).
    @MainActor
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
#endif
