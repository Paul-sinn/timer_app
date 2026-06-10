# Step 7: mypage-screen

## 읽어야 할 파일

- `/docs/PRD.md` — 마이페이지 = 내 정보 관리, 로그인(Apple/Google) 계정
- `/docs/ADR.md` — ADR-007(Apple+Google, Supabase Auth), ADR-002(UI 우선: 로그인 미구현)
- `/docs/UI_GUIDE.md` — 카드/리스트, 버튼 스타일
- `/iOS/Eggtimer/Features/MyPage/` — step3의 `MyPageView` placeholder
- `/iOS/Eggtimer/Mock/MockData.swift` — 더미 유저(displayName 등)
- `/iOS/Eggtimer/Components/`, `/iOS/Eggtimer/DesignSystem/`

## 프로젝트 사실

- 로그인은 **UI 껍데기만** 만든다. 실제 인증(Sign in with Apple, Google, Supabase) 연동은 하지 않는다.
- 로그인 안 해도 이 화면을 포함한 전 화면에 접근 가능해야 한다(게이트 금지).

## 작업

1. **프로필 헤더** — `iOS/Eggtimer/Features/MyPage/MyPageView.swift`. 더미 유저 아바타(placeholder 심볼) + `displayName` + 간단한 부가 정보(예: 가입일/누적 부화 수, 더미).
2. **계정 섹션** — 로그인 상태가 아닐 때를 가정한 **UI만**:
   - "Apple로 계속하기" 버튼(SF Symbol `applelogo` 활용, 흑/백 스타일).
   - "Google로 계속하기" 버튼.
   - 두 버튼의 action은 비워두거나 `// TODO: Phase 2 auth` 주석 + 단순 print. 실제 인증 호출 금지.
3. **설정 리스트** — `AppCard`/리스트로 더미 설정 항목(알림, 다크모드(고정 안내), 사운드, 정보/버전 등). 토글은 로컬 `@State`만.
4. **검수 가능성** — 더미 유저를 주입 가능하게(기본 = MockData). `#Preview`에 로그인 전(계정 버튼 노출) 모습 포함.

## Acceptance Criteria

```bash
xcodebuild -project iOS/Eggtimer.xcodeproj -scheme Eggtimer \
  -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO
```
→ `** BUILD SUCCEEDED **`.

## 검증 절차

1. AC 커맨드 실행.
2. 체크리스트:
   - Apple/Google 버튼이 UI로만 존재하고 실제 인증을 호출하지 않는가?
   - 로그인 게이트 없이 화면이 바로 보이는가?
   - 설정 토글이 로컬 `@State`로만 동작하는가?
3. step 7 status 업데이트(성공 시 `summary`에 섹션 구성/로그인 UI 더미임을 명시).

## 금지사항

- `AuthenticationServices`(Sign in with Apple), Google SDK, Supabase 인증을 실제로 연동하지 마라. 이유: ADR-002에 따라 인증은 Phase 2 범위.
- 로그인 강제 게이트를 만들지 마라. 이유: "로그인 없이 모든 화면 접근" 요구사항.
- 다른 탭 화면을 수정하지 마라.
- 기존 테스트를 깨뜨리지 마라.
