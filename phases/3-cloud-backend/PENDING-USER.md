# Phase 3 — 사용자(폴)가 직접 해야 하는 작업

내(Claude) 권한 밖이라 코드 스캐폴딩만 해둔 항목들. 아래를 마치면 로그인·동기화가 실제로 동작한다.

## 1. Supabase 대시보드 — Auth 공급자 설정
프로젝트: `qvaqiuabsplcwfedoklu`
- **Apple**: Authentication → Providers → Apple 활성화. Services ID / Team ID / Key ID / Private Key(.p8) 입력.
- **Google**: Authentication → Providers → Google 활성화. Google Cloud OAuth Client ID/Secret 입력.
- (선택) Redirect URL / Authorized Client IDs에 iOS 번들 `com.paulsin.Eggtimer` 관련 값 등록.

## 2. Apple Developer — Sign in with Apple
- App ID(`com.paulsin.Eggtimer`)에 **Sign in with Apple** capability 추가.
- Xcode 타겟 Signing & Capabilities에 **Sign in with Apple** 추가(엔타이틀먼트 생성).

## 3. (macOS 빌드 시) 네트워크 엔타이틀먼트
- macOS/Catalyst 빌드에서 `com.apple.security.network.client` 필요(iOS는 기본 허용). 지금은 iOS 우선이라 보류.

---

## 위가 끝나면 내가 이어서 할 일 (말해주면 진행)
- 로그인 UI: `SignInWithAppleButton`(+nonce) / Google 버튼 → `AuthService.signIn(provider:idToken:nonce:)` 연결.
- RootView 로그인 게이트(비로그인 시 로그인 화면) — 현재는 앱 사용성 위해 미적용.
- 자동 동기화 연결: 부화/세션 종료 시 `SyncService.push*`, 로그인 시 `fetch*`→로컬 머지(`currentUserID != nil`일 때만).
- 라이브 push/pull을 실기기/시뮬레이터에서 RLS와 함께 검증.

## 이미 완료(내가 한 것)
- ✅ 원격 스키마 + RLS + 트리거 (마이그레이션 2건, `supabase/migrations/`)
- ✅ supabase-swift SDK 연동 + `SupabaseService`(URL/publishable 키)
- ✅ `AuthService`(세션 상태) + `SyncService`/DTO(매핑 테스트 6/6)
- ✅ 빌드/테스트 통과, 커밋·푸시 완료
