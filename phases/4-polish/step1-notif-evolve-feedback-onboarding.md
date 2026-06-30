# Phase 4 — Polish: 알림 · 진화 수정 · 사운드/햅틱 · 온보딩

날짜: 2026-06-30 · 빌드 성공 · EggtimerTests 통과 · 시뮬레이터 실런치 정상(크래시 없음).

## 배경
TestFlight 사용 중 가로모드 UI 깨짐 → iPhone 세로 고정으로 해결(pbxproj). 이어서 "더 만들 것" 점검:
DB는 이미 구축됨(Phase 3, RLS/edge function 라이브; 현재 무료 프로젝트 paused 추정). 코드 미구현 4종을 채움.

## 변경 내역

### 1. 로컬 알림 (신규)
- `Eggtimer/Services/FocusNotifier.swift` — `requestAuthorization`/`schedule(title:body:after:)`/`cancel`. 단일 식별자 1건 유지.
- `HomeView`: scenePhase `.background` → `scheduleFocusNotification()`(다음 전환=부화/포모도로 휴식까지 남은 실시간 1회 예약), `.active` → `FocusNotifier.cancel()`. 첫 집중 시작 시 `beginFocus()`에서 권한 1회 요청.
- 다음 전환 판정: `session.countdownSeconds >= session.remainingSeconds`면 부화, 아니면 휴식. (타임스탬프 기반이라 백그라운드 집중초=실시간초)

### 2. 진화 시스템 수정 (벽시계 → 누적 집중시간)
- `Models/Creature.swift`: `isEvolved`/`displayImageName`를 **computed → `func(focusSecondsSinceHatch:)`** 로. 부화 후 누적 집중초 ≥ `evolveAfter`(20분)이면 진화. (기존 `Date()-hatchedAt` 벽시계 제거)
- `Mock/FocusHistoryStore.swift`: `focusSeconds(since:)` 추가(해당 시점 이후 세션 activeSeconds 합).
- 주입 경로: `HomeView`(HatchedCenter), `RootView`→`CollectionView(focusSecondsSinceHatch:)`→CreatureSlot/DetailSheet. `HatchResultSheet`(미사용)는 0.
- 테스트 `CreatureSpeciesTests.evolutionTriggersAfter20MinutesOfFocus` 갱신. (진화 아트는 여전히 백호·피닉스 2종만 — 에셋 한계, by design)

### 3. 사운드 / 햅틱
- `HomeView`: 부화 시 `AudioServicesPlaySystemSound(1025)` + `.sensoryFeedback(.success, trigger: hatchling?.id)`. 휴식 진입 `.sensoryFeedback(.impact, trigger: session.isOnBreak)`.

### 4. 온보딩 (신규)
- `Eggtimer/Features/Onboarding/OnboardingView.swift` — 3페이지(집중→부화 / 수집 / 진화) paged TabView + 다음/시작하기.
- `RootView`: `@AppStorage("hasSeenOnboarding")` 게이트 → `.fullScreenCover`. 완료 시 영구 저장.

## 검증
- `xcodebuild build` 성공. `EggtimerTests/CreatureSpeciesTests` 전건 통과(진화 포함).
- simctl install+launch: PID 정상, 우리 번들 .ips 크래시 없음. 온보딩 1페이지 스크린샷 정상.

## 남은 것 / 보류
- 위젯·라이브액티비티: 미구현(사용자가 제외).
- 진화 아트 종 확장: 픽셀 에셋 필요(사용자/디자인).
- Supabase 프로젝트 paused 복구 + 실기기 동기화/알림 권한은 사용자 검증.
- 미커밋: 이번 변경 + 이전 세로고정 pbxproj.
