# Step 1: design-system

## 읽어야 할 파일

- `/docs/UI_GUIDE.md` — 색상표·타이포그래피·컴포넌트 스펙·AI 슬롭 안티패턴 (이 step의 핵심 근거)
- `/docs/ARCHITECTURE.md` — `Components/` 위치 규칙
- `/iOS/Eggtimer/App/RootView.swift` — step0에서 만든 골격
- `/iOS/Eggtimer/EggtimerApp.swift` — 다크모드 적용 확인

이전 step에서 만들어진 코드를 읽고 일관성을 유지하라.

## 프로젝트 사실

- 앱 소스 루트 `iOS/Eggtimer/`. synchronized group이라 `iOS/Eggtimer/DesignSystem/`, `iOS/Eggtimer/Components/`에 `.swift`를 추가하면 자동 포함된다.
- 다크모드 고정. 모든 색상은 UI_GUIDE.md의 값을 단일 출처로 토큰화한다.

## 작업

1. **색상 토큰** — `iOS/Eggtimer/DesignSystem/AppColor.swift`. UI_GUIDE.md 색상표를 SwiftUI `Color` 정적 토큰으로 정의한다. 최소 항목:
   - 배경: `pageBackground`(#0A0A0A), `cardBackground`(#161616), `tabBarBackground`(#111111)
   - 텍스트: `textPrimary`(#FFFFFF), `textBody`(#D4D4D4), `textSecondary`(#A3A3A3), `textDisabled`(#525252)
   - 시맨틱: `eggAccent`(#F5C451), `success`(#22C55E), `danger`(#EF4444), `rare`(#60A5FA)
   ```swift
   enum AppColor {
       static let pageBackground = Color(hex: 0x0A0A0A)
       // ...
   }
   ```
   `Color(hex:)` 헬퍼가 없으면 같은 파일 또는 `DesignSystem/Color+Hex.swift`에 추가한다.

2. **타이포그래피** — `iOS/Eggtimer/DesignSystem/AppFont.swift`. UI_GUIDE 타이포 표(타이머 숫자=대형 모노스페이스 굵게, 화면 제목=title2 semibold, 카드 제목=footnote medium, 본문=body)를 `Font`/`Text` 스타일로 토큰화한다.

3. **간격 토큰** — `iOS/Eggtimer/DesignSystem/AppSpacing.swift`. 요소 간 12~16, 섹션 간 24~32 등 상수.

4. **공용 컴포넌트** — `iOS/Eggtimer/Components/`에 다음을 시그니처 수준으로 구현한다(내부 스타일은 토큰 사용):
   - `AppCard<Content: View>` — 배경 cardBackground, 1px border #262626, 모서리 14, 패딩 16.
   - `PrimaryButton` — 채움 흰색/텍스트 검정/모서리 12. `init(_ title: String, action: @escaping () -> Void)`.
   - `DangerButton` — 외곽선형 danger 색.
   - `SectionHeader` — 화면 섹션 제목용.
   각 컴포넌트에 `#Preview`를 다크 배경 위에 추가한다.

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
   - 색상/폰트 값이 UI_GUIDE.md와 일치하는가?
   - 컴포넌트가 하드코딩 색상 대신 `AppColor` 토큰을 사용하는가?
   - 파일이 `DesignSystem/`, `Components/`에 위치하는가?
3. `phases/0-ui-dummy-screens/index.json`의 step 1 업데이트(성공 시 `completed` + `summary`에 생성한 토큰/컴포넌트 명시).

## 금지사항

- 화면(Feature/탭/네비게이션)을 구현하지 마라. 이유: 이 step은 디자인 시스템 레이어만 담당한다.
- UI_GUIDE의 "AI 슬롭 안티패턴"(glass blur, gradient text, 네온 글로우, 보라 브랜드색, 배경 orb)을 도입하지 마라.
- 색상을 컴포넌트 내부에 하드코딩하지 마라. 이유: 토큰 단일 출처를 깨면 일관성이 무너진다.
- 기존 테스트를 깨뜨리지 마라.
