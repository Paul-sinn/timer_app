# Step 3: app-shell-nav

## 읽어야 할 파일

- `/docs/PRD.md` — 화면 트리(홈/컬렉션/Progress/마이페이지 4탭)와 "로그인 없이 전 화면 접근" 구현 순서
- `/docs/UI_GUIDE.md` — 하단 탭바 4개, Lucide 아이콘, 다크 탭바
- `/iOS/Eggtimer/App/RootView.swift` — step0 임시 골격(이 step에서 교체)
- `/iOS/Eggtimer/DesignSystem/AppColor.swift` — 탭바 색상 토큰
- `/iOS/Eggtimer/Mock/MockData.swift` — 각 탭 화면에 주입할 더미 스냅샷

## 프로젝트 사실

- 이 step은 4개 화면을 잇는 **네비게이션 뼈대**다. 로그인 게이트 없이 앱이 곧장 TabView로 진입해야 한다(요구사항: 로그인 안 해도 모든 화면 접근).
- 아이콘: 디자인 의도는 Lucide지만 SwiftUI에서는 대응되는 **SF Symbol**로 매핑한다.

## 작업

1. **탭 정의** — `iOS/Eggtimer/App/RootTab.swift`(또는 RootView 내부 enum). 4개 탭과 각 SF Symbol 매핑:
   - Home → `house` (Lucide home)
   - Collection → `square.grid.2x2` 또는 `archivebox` (Lucide library/grid)
   - Progress → `chart.bar` (Lucide bar-chart)
   - MyPage → `person.crop.circle` (Lucide user)

2. **RootView 교체** — `iOS/Eggtimer/App/RootView.swift`를 `TabView`로 교체한다.
   ```swift
   struct RootView: View {
       var body: some View {
           TabView {
               HomeView().tabItem { Label("홈", systemImage: "house") }
               CollectionView().tabItem { Label("컬렉션", systemImage: "square.grid.2x2") }
               ProgressView_Screen().tabItem { Label("기록", systemImage: "chart.bar") }
               MyPageView().tabItem { Label("마이", systemImage: "person.crop.circle") }
           }
       }
   }
   ```
   탭바/배경은 다크 톤(AppColor)으로 스타일링한다.

3. **각 화면 placeholder** — `iOS/Eggtimer/Features/{Home,Collection,Progress,MyPage}/`에 화면 View 4개를 **빈 placeholder**로 만든다(다음 step4~7에서 내용 채움). 단, 지금도 빌드되고 탭으로 진입 가능해야 한다.
   - `HomeView`, `CollectionView`, `ProgressView_Screen`(SwiftUI 기본 `ProgressView`와 이름 충돌 피하기 위해 화면 타입명은 `ProgressScreen` 등으로 명명 권장), `MyPageView`.
   - 각 placeholder는 화면 제목 텍스트 + "곧 구현됩니다" 수준이면 된다.

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
   - 앱 진입 시 로그인/스플래시 게이트 없이 곧장 4탭 TabView가 뜨는가?
   - 4개 탭 화면 타입이 `Features/` 하위에 위치하는가?
   - SwiftUI 내장 `ProgressView`와 화면 타입명이 충돌하지 않는가?
3. step 3 status 업데이트(성공 시 `summary`에 화면 타입명 4개와 진입 경로 명시 — 다음 step들이 이 타입을 채운다).

## 금지사항

- 인증/로그인 게이트(로그인 안 하면 막기)를 추가하지 마라. 이유: "로그인 없이 모든 화면 접근" 핵심 요구사항.
- 화면 본문 UI를 완성하지 마라. 이 step은 뼈대(placeholder)만. 이유: 각 화면은 step4~7에서 독립적으로 구현된다.
- `project.pbxproj`를 직접 편집하지 마라.
- 기존 테스트를 깨뜨리지 마라.
