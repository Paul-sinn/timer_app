# Phase 3 · Step 3 — AuthService 스캐폴딩

**완료:** 2026-06-11

## 목표
Supabase Auth 세션 상태를 앱의 단일 소스로 노출(로그인 user_id = 동기화 소유자). 실제 Apple/Google 공급자 설정은 사용자 권한이라 보류.

## 작업
- `Services/AuthService.swift` (`@Observable @MainActor`):
  - `currentUserID: UUID?` / `isAuthenticated` — `authStateChanges` 스트림 구독으로 갱신.
  - `signIn(provider:idToken:nonce:)` — `signInWithIdToken`(OIDC). Apple/Google 공통.
  - `signOut()`.
  - self 약참조로 무한 스트림이 인스턴스를 붙들지 않게 처리(retain cycle 회피, deinit 불필요).
- `SupabaseService`를 `nonisolated`로 — 네트워크 레이어를 MainActor에 묶지 않음.

## 검증
- 빌드 성공(테스트 타겟 포함).

## 보류 (사용자 권한 필요)
- Supabase 대시보드: Apple/Google 공급자 활성화 + Client ID/Secret.
- Apple Developer: Sign in with Apple capability + 엔타이틀먼트.
- 로그인 UI(SignInWithAppleButton + nonce)와 RootView 로그인 게이트 연결 — 공급자 설정 후. 현재는 앱 사용성 유지 위해 게이트 미적용.

## 다음
- Step 4: SwiftData ↔ Supabase 동기화 서비스 + 매핑 테스트.
