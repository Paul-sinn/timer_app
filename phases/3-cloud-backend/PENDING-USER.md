# Phase 3 — 사용자(폴)가 직접 해야 하는 작업

번들 ID: `com.paulsin.hatchly` / 앱 표시명: **Hatcho** / Supabase 프로젝트: `qvaqiuabsplcwfedoklu`
콜백 URL: `https://qvaqiuabsplcwfedoklu.supabase.co/auth/v1/callback`

로그인 UI·자동 동기화·계정삭제는 **코드 구현 완료**. 아래 사용자 직접 항목만 마치면 실제 동작 + 심사 제출 가능.

---

## 🔴 남은 사용자 직접 작업 (심사 전 필수)

### 1. Google 로그인 활성화 (선택 — Apple만으로도 출시 가능)
Google 버튼은 SDK가 추가될 때만 자동으로 나타난다(`#if canImport(GoogleSignIn)`). 켜려면:
- **Xcode에 SDK 추가**: File ▸ Add Package Dependencies ▸ `https://github.com/google/GoogleSignIn-iOS` → `GoogleSignIn` + `GoogleSignInSwift` 추가.
- **iOS 클라이언트 ID 입력**: `ios/Eggtimer/Services/GoogleAuth.swift`의 `iosClientID` 상수를 Google Cloud의 **iOS** 클라이언트 ID로 교체.
- **URL scheme 등록**: 타겟 Info ▸ URL Types에 iOS 클라이언트 ID의 **reversed** 형태 추가
  (예: `com.googleusercontent.apps.1234-abcd`). 이게 있어야 로그인 콜백이 앱으로 복귀.
- (Supabase Google provider 백엔드 설정은 이미 ✅ 완료.)
> Google을 첫 출시에서 빼려면: SDK를 추가하지 않으면 됨(Apple만 노출, 빌드 정상).

### 2. Apple 로그인 (네이티브 — OAuth 설정 불필요)
- **Apple Developer**: App ID `com.paulsin.hatchly`에 **Sign in with Apple** capability 체크. ✅(완료했으면 OK)
- **Supabase Apple provider**: 활성화 + Client IDs = `com.paulsin.hatchly`. ✅
- **Xcode**: 타겟 Signing & Capabilities에 **Sign in with Apple** 추가(엔타이틀먼트). ← 아직이면 추가.

### 3. App Store Connect 메타데이터 (제출 필수)
- **Privacy Policy URL**, **Support URL** (필수 입력 — 없으면 제출 불가).
- 스크린샷(타이머 + 컬렉션 화면), 앱 아이콘(1024², 알파 없음).
- 카테고리: Productivity(주) / Education(부). 설명문구는 `appstore/app-store-listing-en.md`.

---

## ✅ 코드 구현 완료 (Claude)
- 원격 스키마 + RLS + 트리거, supabase-swift SDK, `SupabaseService`/`AuthService`/`SyncService`/`SyncMerge`.
- **로그인 UI**: Apple(`SignInWithAppleButton`+nonce) / Google(canImport 게이트) → `AuthService`. (MyPageView)
- **선택형 로그인**(게이트 없음) — 비로그인도 전 기능 사용, 로그인 시 동기화 ON.
- **자동 동기화**: 부화·세션종료 시 push, 로그인 시 양방향 합집합 머지(`SyncCoordinator`).
- **계정 삭제**: Supabase Edge Function `delete-account`(service_role, cascade) 배포 완료 + 앱 내 삭제 버튼.
- 앱 표시명 Hatcho, 버전 1.0, 빌드 성공.

## (참고) macOS/Catalyst 빌드 시
- `com.apple.security.network.client` 엔타이틀먼트 필요(iOS는 기본 허용). iOS 우선이라 보류.
