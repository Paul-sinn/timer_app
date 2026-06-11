//
//  AuthService.swift
//  Eggtimer
//
//  Supabase Auth 세션 상태(Phase 3-3). 로그인 사용자 ID를 단일 소스로 노출해 동기화의 소유자(user_id) 식별에 쓴다.
//  실제 Apple/Google 공급자 설정(대시보드 키, Apple Developer capability)은 사용자 권한이라 보류 —
//  이 서비스는 OIDC id_token만 받으면 동작하도록 스캐폴딩만 둔다(로그인 UI는 공급자 설정 후 연결).
//

import Foundation
import Supabase

@Observable
@MainActor
final class AuthService {
    /// 현재 로그인 사용자 ID(nil = 비로그인). RLS 소유자 식별자.
    private(set) var currentUserID: UUID?

    var isAuthenticated: Bool { currentUserID != nil }

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
        self.currentUserID = client.auth.currentUser?.id
        startObserving()
    }

    /// 세션 변화(로그인/로그아웃/토큰 갱신)를 구독해 currentUserID를 갱신.
    /// self는 약하게 잡아 무한 스트림이 인스턴스를 붙들지 않게 한다(self 해제 시 루프 종료).
    private func startObserving() {
        Task { [weak self] in
            guard let client = self?.client else { return }
            for await change in client.auth.authStateChanges {
                guard let self else { break }
                self.currentUserID = change.session?.user.id
            }
        }
    }

    /// Apple/Google이 발급한 OIDC id_token으로 로그인. (UI에서 받은 토큰 전달)
    @discardableResult
    func signIn(provider: OpenIDConnectCredentials.Provider, idToken: String, nonce: String? = nil) async throws -> UUID {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: provider, idToken: idToken, nonce: nonce)
        )
        currentUserID = session.user.id
        return session.user.id
    }

    func signOut() async {
        try? await client.auth.signOut()
        currentUserID = nil
    }
}
