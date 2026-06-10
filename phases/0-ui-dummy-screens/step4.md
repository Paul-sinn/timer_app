# Step 4: home-screen

## 읽어야 할 파일

- `/docs/PRD.md` — 홈 = 타이머 + 알, 15분마다 크랙, 부화 이벤트
- `/docs/UI_GUIDE.md` — "알이 주인공", 중앙 정렬(홈 예외), 타이머 숫자 타이포, 허용 애니메이션(알 idle 흔들림·크랙 트랜지션)
- `/iOS/Eggtimer/Features/Home/` — step3에서 만든 `HomeView` placeholder
- `/iOS/Eggtimer/Models/` — `EggState`, 15분 크랙 규칙
- `/iOS/Eggtimer/Mock/MockData.swift` — 더미 `egg`/유저 스냅샷
- `/iOS/Eggtimer/DesignSystem/`, `/iOS/Eggtimer/Components/`, `/iOS/Eggtimer/Resources/CreatureImage.swift`

## 프로젝트 사실

- 이번 Phase는 UI 더미다. **실제 타이머 카운트다운 로직/백그라운드 처리/화면 꺼짐 방지(idle timer)는 구현하지 않는다.** 표시와 상호작용 상태(UI state)만 만든다.
- ViewModel은 MockData를 주입받아 화면을 그린다(ARCHITECTURE의 1단계 데이터 흐름).

## 작업

1. **HomeView 레이아웃** — `iOS/Eggtimer/Features/Home/HomeView.swift`(필요 시 `HomeViewModel.swift` 분리). 다크 배경 위에:
   - 중앙에 **알**(`CreatureImage` 또는 전용 `EggView`)을 크게 배치. UI_GUIDE의 알 idle 미세 흔들림 애니메이션(루프) 허용.
   - 알 위(또는 인접)에 **타이머 표시**: 대형 모노스페이스 숫자(`AppFont` 타이머 스타일). 더미 값으로 `25:00` 등.
   - **크랙 단계 시각화**: `EggState.crackStage`에 따라 알에 금이 늘어나는 표현(오버레이 심볼/획). 15분 단위 진행을 시각적으로 드러낸다.
   - **시작/중단 컨트롤**: `PrimaryButton("집중 시작")` ↔ `DangerButton("중단")`. 누르면 로컬 `@State`(예: `isRunning`)만 토글한다(실제 카운트다운 없음).

2. **부화 진행 표시** — `EggState.progress`(0...1)를 진행 바/링 등으로 표현. 더미 값으로 채운다.

3. **상태 대응** — 막 시작한 알(진행 0, 크랙 0)과 부화 임박(진행 ~1, 크랙 다단계) 두 모습이 모두 자연스럽게 그려지도록 한다. `#Preview`에 두 상태를 모두 넣는다.

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
   - 알이 화면의 시각적 중심인가? 타이머 숫자가 대형 모노스페이스인가?
   - 시작/중단이 UI state를 토글하는가(실제 타이머 로직 없이)?
   - `#Preview`에 초기/부화임박 두 상태가 있는가?
3. step 4 status 업데이트(성공 시 `summary`에 HomeView 구성요소 명시).

## 금지사항

- 실제 카운트다운 타이머/`Timer`/백그라운드 스케줄링/`idleTimerDisabled`(화면 꺼짐 방지)를 구현하지 마라. 이유: 기능은 Phase 2 범위, 지금은 화면만.
- UI_GUIDE 안티패턴(네온 글로우, 보라색, glass blur)을 쓰지 마라.
- 다른 탭 화면(Collection/Progress/MyPage)을 건드리지 마라. 이유: step 분리 원칙.
- 기존 테스트를 깨뜨리지 마라.
