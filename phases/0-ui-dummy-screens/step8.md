# Step 8: review-gallery

## 읽어야 할 파일

- `/docs/PRD.md` — 화면 트리 전체(이 step은 모든 화면을 한 곳에서 검수)
- `/docs/UI_GUIDE.md` — 일관성 검수 기준
- `/iOS/Eggtimer/App/RootView.swift` — TabView 구조
- `/iOS/Eggtimer/Features/Home/`, `Collection/`, `Progress/`, `MyPage/` — 완성된 4개 화면
- `/iOS/Eggtimer/Mock/MockData.swift` — `populated` / `empty` 스냅샷

## 프로젝트 사실

- 목표: **데이터 없이도 모든 화면과 모든 상태(빈/채움)를 한 곳에서 점프해 점검·검수**할 수 있는 화면을 만든다.
- 이 갤러리는 개발/검수 전용이다. 실제 사용자 플로우(4탭)는 그대로 두고, 갤러리는 별도 진입점으로 단다.

## 작업

1. **Review 갤러리 화면** — `iOS/Eggtimer/Features/Review/ReviewGalleryView.swift`. `NavigationStack` + 리스트로 아래 항목을 각각 링크한다(주입으로 상태 강제):
   - Home — 초기 상태 / 부화 임박 상태
   - Collection — populated / empty
   - Progress — populated / empty
   - MyPage — 로그인 전(더미 유저)
   각 항목 탭 시 해당 화면을 지정한 더미 상태로 띄운다(앞 step들에서 만든 init 주입 활용).

2. **진입점 연결** — 갤러리에 접근 가능하게 한다. 다음 중 하나(재량):
   - `MyPageView` 설정 맨 아래 "🛠 화면 검수 갤러리(DEBUG)" 행 → 갤러리로 push, 또는
   - `#if DEBUG`로 감싼 별도 탭/버튼.
   `#if DEBUG` 가드로 릴리스 빌드에는 노출되지 않게 하는 것을 권장한다.

3. **Preview 카탈로그 확인** — 각 화면 파일의 `#Preview`가 빈/채움 등 주요 상태를 포함하는지 점검하고, 누락분을 보강한다(Xcode 캔버스로 전 화면을 미리 볼 수 있게).

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
   - 갤러리에서 4개 화면 × 주요 상태(빈/채움)로 모두 점프 가능한가?
   - 갤러리 진입점이 존재하고(DEBUG 가드 권장) 일반 4탭 플로우는 그대로인가?
   - 각 화면 `#Preview`에 핵심 상태가 들어 있는가?
3. step 8 status 업데이트(성공 시 `summary`에 갤러리 경로/진입점/커버한 상태 목록 명시).

## 금지사항

- 4탭 정상 플로우(RootView 기본 동작)를 갤러리로 대체하지 마라. 이유: 갤러리는 검수 보조 진입점일 뿐.
- 새 기능 로직(타이머/인증/영속성)을 추가하지 마라. 이유: Phase 0는 화면 검수까지가 끝.
- `project.pbxproj`를 직접 편집하지 마라.
- 기존 테스트를 깨뜨리지 마라.
