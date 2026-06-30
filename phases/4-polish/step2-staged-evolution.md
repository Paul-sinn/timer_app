# Phase 4 step2 — 단계 진화(Staged Evolution) 재설계

날짜: 2026-06-30 · 빌드 성공 · CreatureSpeciesTests 통과 · 시뮬 실런치 정상.

## 배경 / 컨셉(사용자 확정)
리텐션: 1시간으론 부족한 유저가 "이어서 집중"으로 계속하게 → 동료가 **단계별로 진화**.
- **3번 진화 = 최종**(단계 0=부화 → 1 → 2 → 3=최종). `Creature.maxEvolutionStage = 3`.
- **이어서 집중 1세션(완료) = +1단계.** (step1의 누적 집중초 방식 폐기)
- **모든 7종** 단계 진화. 전용 진화 아트(백호·피닉스)는 최종 단계에서 이미지 교체, 나머지는 **같은 아트 + 글로우·배지 연출**로 표현(아트는 추후 종별 구축).

## 구현
- **단계는 파생값**(스키마 변경 0): `FocusHistoryStore.completedSessions(since:)` = 부화 시각 이후 완료(목표도달) 세션 수. `Creature.evolutionStage(completedSessionsSinceHatch:)` = min(n, max).
- `Creature`: `isEvolved/displayImageName(focusSecondsSinceHatch:)` 제거 → `evolutionStage`/`isFinalEvolved(stage:)`/`displayImageName(stage:)`/`hasFinalArt`. `evolveAfter` → `maxEvolutionStage`.
- `Resources/EvolutionBadge.swift`(신규): 단계 점(pip) + "진화 n/3" / "최종 진화 ✨". compact=컬렉션 셀.
- `HomeView`: `companionStage` 파생, `HatchedCenter(stage:)`(글로우 단계 가중 `stageGlow`), centerStage `.id`에 단계 포함 → **진화 시 등장연출 자동 재생**. 단계 배지 노출. `onChange(companionStage)` → 진화 문구(`justEvolvedStage`, 3s 자동해제)+시스템사운드+`.sensoryFeedback(.success)`. 부화/새 알 받기/이어서집중 시 문구 리셋. HatchRevealCard·timerHeader 문구를 전 종 진화 안내로.
- `CollectionView`: 클로저 `completedSessionsSinceHatch`로 교체, 슬롯·상세에 단계 배지(상세는 "최종 진화"/"이어서 집중하면 진화해요").
- `RootView`: `{ history.completedSessions(since: $0.hatchedAt) }` 주입.
- 테스트 재작성: `evolutionStagesByCompletedSessions`, `finalArtSpeciesUseEvolvedImageAtFinalStage`.

## 미래(메모만, 지금 X)
- **리롤/유료**: 이미 최종진화한 종을 "새 알 받기"로 다시 받으면 또 1시간 집중 → 같은 종 또 뜰 수 있음 → 리롤 기능. 유료 플랜 시 도입.
- 종별 단계별 진화 **아트** 제작(현재 백호·피닉스 최종 아트만).
- **콜드런치 동료 복원**: 현재 `hatchling`은 @State라 앱 재시작 시 알로 초기화('새 알 받기'와 충돌 때문에 이번엔 보류). 영속하려면 "현재 동료 id" 플래그 필요.

## 검증
- `xcodebuild build` 성공. `EggtimerTests/CreatureSpeciesTests` 통과. simctl install+launch PID 정상, .ips 크래시 없음.
- 진화 시각 UI(배지/연출)는 부화→이어서집중 완료 시 노출 — DEBUG 고속(10s/30s)로 사용자 실검 가능.
