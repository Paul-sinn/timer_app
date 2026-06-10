# Step 6: progress-screen

## 읽어야 할 파일

- `/docs/PRD.md` — Progress = 내가 얼마나 공부했는지(화면 안 끄고 유지했는지) 기록
- `/docs/UI_GUIDE.md` — 카드, 통계 표시, 좌측 정렬, 데이터 색상
- `/iOS/Eggtimer/Features/Progress/` — step3의 Progress 화면 placeholder(타입명 예: `ProgressScreen`)
- `/iOS/Eggtimer/Models/` — `FocusSession`(date, durationMinutes, keptScreenOn)
- `/iOS/Eggtimer/Mock/MockData.swift` — `populated`(세션 다수) / `empty`(없음)
- `/iOS/Eggtimer/Components/`, `/iOS/Eggtimer/DesignSystem/`

## 프로젝트 사실

- 빈 상태와 채움 상태를 모두 구현한다(데이터 없이 검수 가능).
- 모든 값은 더미. 실제 집계 로직/영속성은 만들지 않는다(주입된 `[FocusSession]`에서 단순 계산만).

## 작업

1. **요약 통계** — `iOS/Eggtimer/Features/Progress/ProgressScreen.swift`(필요 시 ViewModel 분리). 상단에 `AppCard` 기반 요약:
   - 총 집중 시간(분/시간 환산), 총 세션 수, 화면 유지 비율(`keptScreenOn == true` 비율) 등. 주입된 세션 배열에서 계산.
2. **세션 기록 리스트** — 날짜별 세션 목록(날짜, 시간, 화면 유지 여부 배지). 최신순 정렬.
3. **간단한 추이(선택)** — 일/주 단위 막대 같은 가벼운 시각화는 선택. 과하지 않게, UI_GUIDE 안티패턴 회피.
4. **빈 상태** — 세션이 없으면 "아직 기록이 없어요" 빈 상태.
5. **검수 가능성** — `sessions`를 init으로 주입(기본 = populated). `#Preview`에 populated/empty 모두.

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
   - 요약 통계가 주입된 세션에서 올바르게 계산되는가?
   - populated/empty 두 상태가 렌더되는가?
   - 화면 유지 여부(keptScreenOn)가 표현되는가?
3. step 6 status 업데이트(성공 시 `summary`에 통계 항목/빈상태 명시).

## 금지사항

- 실제 측정/타이머/영속성 로직을 만들지 마라. 주입된 더미에서 계산만. 이유: Phase 0 범위.
- 다른 탭 화면을 수정하지 마라.
- UI_GUIDE 안티패턴(gradient text, 네온 글로우 등)을 쓰지 마라.
- 기존 테스트를 깨뜨리지 마라.
