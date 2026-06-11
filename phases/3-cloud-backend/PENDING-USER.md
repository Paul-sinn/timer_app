# Phase 3 — 사용자(폴)가 직접 해야 하는 작업

내(Claude) 권한 밖이라 코드 스캐폴딩만 해둔 항목들. 아래를 마치면 로그인·동기화가 실제로 동작한다.

번들 ID: `com.paulsin.studymon` / Supabase 프로젝트: `qvaqiuabsplcwfedoklu`
콜백 URL: `https://qvaqiuabsplcwfedoklu.supabase.co/auth/v1/callback`

## 1. Google 로그인  ✅ (완료)
- Google Cloud에 **iOS 클라이언트**(secret 없음 — 정상) + **웹 애플리케이션 클라이언트**(ID+secret) 생성.
- Supabase Google provider: Client ID/Secret = 웹 값, **Authorized Client IDs = 웹 ID + iOS ID**(쉼표), iOS는 **Skip nonce check 켜기**.
- 웹 클라이언트 승인 리디렉션 URI에 위 콜백 URL 등록.

## 2. Apple 로그인 (네이티브 전용 — OAuth 설정 불필요!)
> Supabase 문서: "네이티브 앱만 만들면 OAuth 설정(Services ID/Team ID/.p8 등)은 필요 없다."
- **Apple Developer**: App ID `com.paulsin.studymon`에 **Sign in with Apple** capability 체크(S2S notification endpoint는 비움).
- **Supabase Apple provider**: 활성화 → **Client IDs 칸에 `com.paulsin.studymon`만** 입력. Secret Key/Services ID/Team ID 칸은 **비워둠**.
- **Xcode**: 타겟 Signing & Capabilities에 **Sign in with Apple** 추가(엔타이틀먼트) — 로그인 UI 붙일 때 내가 처리.

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
