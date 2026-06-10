# Step 0: project-foundation

## 읽어야 할 파일

먼저 아래 파일들을 읽고 프로젝트의 아키텍처와 설계 의도를 파악하라:

- `/docs/ARCHITECTURE.md` — 디렉토리 구조와 MVVM 패턴
- `/docs/ADR.md` — 기술 스택 결정(SwiftUI, 다크모드 고정, UI 우선·더미 데이터)
- `/docs/UI_GUIDE.md` — 다크모드 색상/원칙
- `/iOS/Eggtimer/EggtimerApp.swift` — 현재 앱 진입점(SwiftData 템플릿)
- `/iOS/Eggtimer/ContentView.swift` — 기본 템플릿 화면
- `/iOS/Eggtimer/Item.swift` — 기본 SwiftData 모델

## 프로젝트 사실 (반드시 숙지)

- Xcode 프로젝트: `iOS/Eggtimer.xcodeproj`, 타겟/스킴: `Eggtimer`, 앱 소스 루트: `iOS/Eggtimer/`.
- 이 프로젝트는 **file-system synchronized group**(objectVersion 77)을 사용한다. 즉 `iOS/Eggtimer/` 아래에 `.swift` 파일이나 하위 폴더를 만들면 **자동으로 빌드에 포함된다.**
- 이번 Phase는 **UI만 더미 데이터로** 구현한다. 로그인/백엔드/실제 기능은 구현하지 않는다.

## 작업

1. **폴더 구조 생성** — `iOS/Eggtimer/` 아래에 ARCHITECTURE.md를 따르는 빈 폴더 골격을 만든다(빈 폴더는 git에 안 잡히니, 각 폴더에 이번/다음 step에서 쓸 파일을 두며 자연스럽게 생성되게 한다). 목표 구조:
   ```
   iOS/Eggtimer/
   ├── App/            # 앱 진입점, RootView
   ├── DesignSystem/   # (step1) 색상·타이포 토큰
   ├── Components/      # (step1) 공용 컴포넌트
   ├── Features/
   │   ├── Home/
   │   ├── Collection/
   │   ├── Progress/
   │   └── MyPage/
   ├── Models/         # (step2) 도메인 타입
   ├── Mock/           # (step2) 더미 데이터
   └── Resources/      # (step2) mock 이미지 placeholder
   ```

2. **SwiftData 데모 제거** — 이번 Phase는 SwiftData를 쓰지 않는다.
   - `iOS/Eggtimer/Item.swift` 파일을 삭제한다.
   - `EggtimerApp.swift`를 정리한다: `ModelContainer`/`Schema`/`Item` 참조를 모두 제거하고, 다음 시그니처로 단순화한다.
     ```swift
     @main
     struct EggtimerApp: App {
         var body: some Scene {
             WindowGroup { RootView() }
                 .preferredColorScheme(.dark)   // 다크모드 고정 (ADR/UI_GUIDE)
         }
     }
     ```
   - 기존 `ContentView.swift`의 SwiftData(@Query/Item) 데모 코드를 제거한다. ContentView를 남길지 삭제할지는 재량이되, 빌드에서 `Item`/SwiftData 참조가 완전히 사라져야 한다.

3. **RootView 임시 골격** — `iOS/Eggtimer/App/RootView.swift`를 만든다. 지금은 임시로 앱 이름을 보여주는 최소 화면이면 된다(다음 step3에서 TabView로 교체된다).
   ```swift
   struct RootView: View {
       var body: some View { /* 임시 플레이스홀더. 예: Text("Eggtimer") 를 다크 배경 위에 중앙 정렬 */ }
   }
   ```

## Acceptance Criteria

```bash
xcodebuild -project iOS/Eggtimer.xcodeproj -scheme Eggtimer \
  -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO
```
→ `** BUILD SUCCEEDED **` 출력. 컴파일 에러/경고로 인한 실패 없음.

## 검증 절차

1. 위 AC 커맨드를 실행한다.
2. 아키텍처 체크리스트:
   - `iOS/Eggtimer/` 폴더 구조가 ARCHITECTURE.md를 따르는가?
   - 앱 전체에 `.preferredColorScheme(.dark)`가 적용되었는가?
   - 빌드 결과에 `Item`/SwiftData 잔재가 없는가?
3. 결과에 따라 `phases/0-ui-dummy-screens/index.json`의 step 0을 업데이트한다:
   - 성공 → `"status": "completed"`, `"summary": "산출물 한 줄 요약(생성한 폴더/파일 명시)"`
   - 3회 시도 후 실패 → `"status": "error"`, `"error_message"`
   - 사용자 개입 필요 → `"status": "blocked"`, `"blocked_reason"` 후 중단

## 금지사항

- `Eggtimer.xcodeproj/project.pbxproj`를 직접 편집하지 마라. 이유: synchronized group이라 폴더에 파일만 추가하면 자동 포함된다. 수동 편집은 프로젝트 파일을 손상시킨다.
- SwiftData(`@Model`, `ModelContainer`)를 남기거나 사용하지 마라. 이유: 이번 Phase는 더미 UI 전용이며 영속성은 Phase 2 범위다.
- 로그인/네비게이션/화면 UI를 구현하지 마라. 이유: 이 step은 토대 정리만 담당한다.
- 기존 테스트(`EggtimerTests`, `EggtimerUITests`)를 깨뜨리지 마라.
