# FocusEgg — 기능 설계 (Phase 2 기능 구현 설계서)

> 대상 독자: SwiftUI 엔지니어 / PM
> 전제 스택(ARCHITECTURE.md·ADR): SwiftUI + MVVM, 로컬 **SwiftData**, 원격 **Supabase**(Auth/Postgres/Storage), 민감 로직 **FastAPI** 경유.
> 본 문서는 **설계만** 다룬다(코드 미변경). 각 기능은 1)아키텍처 2)데이터 모델 3)상태관리 4)DB 스키마 5)SwiftUI 통합 6)엣지케이스 7)MVP vs 확장 순으로 기술한다.

## 0. 확정 결정 (이 설계의 전제)

| 주제 | 결정 |
|---|---|
| 등급 체계 | **4단계 유지**: Common / Uncommon / Rare / Legendary. (Epic은 *향후 옵션*, 지금 도입 안 함) |
| 성장/부화 | **시간 기반**: 누적 집중 시간으로 crack 단계가 오르고, 목표 시간 도달 시 부화. (기존 `EggState` 유지) |
| XP | **연출용 파생 값**. 성장/부화를 좌우하지 않는다. 누적 집중 시간에서 파생되는 "동기부여 숫자/팝업"일 뿐(별도 경제 X). |
| 산출물 | 본 설계 문서. 코드 변경 없음. |

## 0.1 기존 코드와의 매핑 (재사용/확장)

| 기존 타입 | 역할 | Phase 2 변화 |
|---|---|---|
| `EggState` (struct) | 누적분 → crack/진행도/부화 | **유지**. `GrowthEngine`가 이 규칙을 감싼다(초 단위 + 마일스톤). |
| `CreatureSpecies` (enum) | 7종 카탈로그 + 가중 `roll()` | **유지**. 확률표/프리미엄 플래그 확장. |
| `Creature` (struct) | 부화 인스턴스 + 20분 진화 | **유지**. SwiftData 영속본 `CollectedCreature`로 미러. |
| `Rarity` (enum, 4단계) | 등급/색/점 | **유지**. |
| `CollectionStore` (@Observable) | 메모리 도감 + `hatch()` | **CollectionManager**로 승격(영속화 연결). |
| `FocusSession` (struct) | 세션 1건(date/분/keptScreenOn) | **@Model로 확장**(시작·종료·중단·점수 등). |
| `ProgressViewModel` | 세션 → 통계 집계 | **유지**, StatsManager/롤업 위에서 동작. |
| `HomeViewModel` | 타이머/알 표시 | SessionManager·GrowthManager 구독으로 전환. |

---

# A. 전체 아키텍처 (Feature 10 — 토대)

나머지 9개 기능은 모두 이 토대 위에 얹힌다. **얇은 View → ViewModel(화면 상태) → Manager(도메인 서비스, 앱 1개) → Repository(영속/동기화) → SwiftData/Supabase** 의 단방향 흐름.

```
┌───────────────────────────────────────────────────────────────┐
│ SwiftUI Views (Home / Collection / Progress / MyPage)         │
│   @Environment 로 Manager 주입, @State ViewModel 로 화면 상태  │
└───────────────┬───────────────────────────────────────────────┘
                │ 구독(@Observable) / 액션 호출
┌───────────────▼───────────────────────────────────────────────┐
│ Managers (앱 수명 동안 1개, App 에서 생성·주입)               │
│  SessionManager   GrowthManager   InterruptionTracker         │
│  CollectionManager  StatsManager   DialogueManager            │
│  EntitlementManager  ScreenAwakeManager  AppBlockManager(미래) │
└───────────────┬───────────────────────────────────────────────┘
                │ 도메인 객체 ↔ 영속/원격
┌───────────────▼───────────────────────────────────────────────┐
│ Repositories (프로토콜)  ──  PersistenceController(SwiftData)  │
│                           └─ SyncService → FastAPI → Supabase  │
└───────────────────────────────────────────────────────────────┘
```

## A.1 매니저 책임

| Manager | 책임 | 주요 입력/출력 |
|---|---|---|
| **SessionManager** | 세션 생명주기(시작/일시정지/재개/완료/포기), 타임스탬프 기반 복구 | scenePhase, 시계 → `elapsed/remaining`, 완료 시 세션 영속 |
| **GrowthManager** | 누적 집중초 → crack 단계/마일스톤/XP 연출, 부화 트리거 | `focusedSeconds` → `GrowthStage`, milestone 이벤트 |
| **InterruptionTracker** | 백그라운드 이탈 시간 측정·분류, 집중 점수 | scenePhase 전이 → `InterruptionEvent[]`, focusScore |
| **CollectionManager** | 부화 추첨·중복 처리·도감 영속 | `Creature.hatch()` → `CollectedCreature` upsert |
| **StatsManager** | 일/주/월 집계, 스트릭, 완료율, 롤업 캐시 | sessions → `DailyStat`, 차트 데이터 |
| **DialogueManager** | 트리거별 대사 선택, 쿨다운/비반복 | trigger → `DialogueLine` |
| **EntitlementManager** | 프리미엄 권한 확인(StoreKit2 + 서버 검증) | productId → `isActive(.premium)` |
| **ScreenAwakeManager** | 세션 중 화면 꺼짐 방지 토글 | running → `isIdleTimerDisabled` |
| **AppBlockManager**(미래) | Screen Time API로 앱 차단 | FamilyControls 권한 → shield |

## A.2 주입 패턴

```swift
@main
struct EggtimerApp: App {
    @State private var env = AppEnvironment()        // 모든 Manager 보유
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(env.session)
                .environment(env.growth)
                .environment(env.collection)
                .environment(env.stats)
                .environment(env.dialogue)
                .environment(env.entitlement)
                .modelContainer(env.modelContainer)  // SwiftData
        }
    }
}
```
- `@Observable` Manager → View는 `@Environment(SessionManager.self)`로 구독.
- 도메인 규칙(확률/성장/점수)은 **순수 함수/값 타입**으로 분리해 `@testable` 단위 테스트(현재 `CreatureSpeciesTests` 패턴 유지).

## A.3 영속 레이어 원칙
- **SwiftData = 진실 원본(오프라인 우선)**. 앱은 항상 로컬을 읽고 쓴다.
- **Supabase = 동기화 대상**. `SyncService`가 백그라운드로 push/pull(낙관적, last-write-wins + updatedAt).
- 서버 권위가 필요한 것(확률 검증, 프리미엄 영수증)만 FastAPI 경유(ADR-004).

---

# Feature 1 — 집중 세션 시스템 (Focus Session)

> 사용자가 제안한 "startTime + plannedDuration + sessionId 저장 후 resume 시 재계산" 방식은 **정답 패턴**이다. 아래는 그것을 견고화한 설계.

### 1) 아키텍처
- **단조 시계 기준의 타임스탬프 재계산** + **상태 머신** + **즉시 영속**.
- 백그라운드에서 `Timer`를 신뢰하지 않는다. 화면 갱신용 1초 `Timer`는 foreground에서만 돌리고, **진실은 항상 타임스탬프에서 재계산**한다.
- 상태 머신:
```
 idle ──start──▶ running ──pause──▶ paused
                  │  ▲                 │
          complete│  └─────resume──────┘
                  ▼                 abandon
              completed ◀──────────── (any)
```

### 2) 데이터 모델
```swift
enum SessionState { case idle, running, paused, completed, abandoned }

@Model final class FocusSessionRecord {        // 영속(진행 중 + 완료 모두)
    @Attribute(.unique) var id: UUID
    var startedAt: Date                  // 벽시계(절대 시각)
    var plannedSeconds: Int
    var accumulatedActiveSeconds: Int    // 일시정지 누적 보정용
    var lastResumedAt: Date?             // running 구간 시작점
    var endedAt: Date?
    var stateRaw: String                 // SessionState
    var eggTargetSeconds: Int            // 부화 목표(성장 연동)
    var hatchedCreatureID: UUID?
    // 무결성/안티치트
    var bootSentinel: TimeInterval       // systemUptime 기준선(재부팅 감지)
    var interruptionCount: Int
    var distracted: Bool
}
```
- **핵심 파생값**(저장 X, 계산):
```
activeSeconds = accumulatedActiveSeconds
              + (state == .running ? now - lastResumedAt : 0)
remaining     = max(plannedSeconds - activeSeconds, 0)
isComplete    = activeSeconds >= plannedSeconds
```

### 3) 상태관리
- `SessionManager`(@Observable)가 `current: FocusSessionRecord?` 하나를 보유.
- foreground 진입(`scenePhase == .active`) 시 `recompute()` 호출 → UI 즉시 정합.
- 화면 표시는 0.5~1s `Timer` 틱으로 `recompute()`만 반복(상태 변경 아님).

### 4) DB 스키마
| SwiftData `FocusSessionRecord` | Supabase `focus_sessions` |
|---|---|
| id (uuid, unique) | id uuid pk |
| startedAt | started_at timestamptz |
| plannedSeconds | planned_seconds int |
| accumulatedActiveSeconds | active_seconds int |
| endedAt | ended_at timestamptz null |
| stateRaw | state text |
| interruptionCount | interruption_count int |
| distracted | distracted bool |
| hatchedCreatureID | hatched_creature_id uuid null |
- 인덱스: `(user_id, started_at desc)`. 완료 세션만 통계로 롤업.

### 5) SwiftUI 통합
- `HomeView`의 시작/일시정지/중단 버튼 → `session.start()/pause()/resume()/abandon()`.
- 타이머 텍스트 = `session.remainingDisplay`(현 `HomeViewModel.timerDisplay` 더미 대체).
- `.onChange(of: scenePhase)` → active 시 `recompute()` + `InterruptionTracker.appReturned()`.
- 앱 실행 시 `SessionManager.restore()`가 미완료 레코드를 찾아 자동 복구(이어하기/완료 처리).

### 6) 엣지케이스
- **앱 강제종료/크래시**: 진행 세션을 SwiftData에 즉시 기록 → 재실행 시 복구.
- **재부팅**: `systemUptime` 기준선(`bootSentinel`)으로 감지. 벽시계(`startedAt`)로 elapsed 계산하되, 시계 조작 방지 위해 **재계산 elapsed를 plannedSeconds로 캡**.
- **시스템 시계 변경(치트)**: `now < lastResumedAt`(역행) 감지 시 해당 구간 0 처리 + 로그. 핵심 보상은 서버(FastAPI)에서 한 번 더 검증(ADR-004).
- **DST/타임존**: 절대시각(`Date`)만 사용, 표시만 로컬화.
- **plannedDuration 초과**: 부화 후 추가 시간은 "보너스 집중"으로 통계엔 반영하되 부화는 1회.
- **백그라운드 장기 체류**: 복귀 시 한 번에 재계산(중간 보간 불필요).

### 7) MVP vs 확장
- **MVP**: 로컬 타임스탬프 복구 + 상태 머신 + 미완료 복원.
- **확장**: 서버 검증, 멀티기기 이어하기, 세션 종료 로컬 알림(`UNUserNotification`), Live Activity(Dynamic Island) 카운트다운.

---

# Feature 2 — 알 성장 시스템 (Egg Growth, XP는 연출)

> 결정: **성장/부화는 시간 기반**(기존 `EggState`). **XP는 동기부여 연출**(특정 시각에 팝업/숫자), 성장을 좌우하지 않음.

### 1) 아키텍처
- `GrowthManager`가 `session.activeSeconds`를 구독 → **마일스톤 테이블**을 통과할 때마다 이벤트 발행.
- 시각 단계(알 이미지)는 기존 `EggState.stageIndex`(0~5) 규칙 유지, 단위만 분→초로 정밀화.

### 2) 데이터 모델
```swift
struct GrowthMilestone {            // 데이터로 분리(조정 가능)
    let atSeconds: Int
    let kind: Kind
    enum Kind { case xp(Int), wiggle, crack(stage: Int), majorGrowth, hatchReady }
    let toast: String?              // "5분 집중! +5 XP" 같은 연출 문구
}

// 기본 테이블(예시; 목표 60분)
[ .init(atSeconds: 5*60,  kind: .xp(5),        toast: "5분 집중! 🥚 +5 XP"),
  .init(atSeconds: 15*60, kind: .wiggle,        toast: "알이 꿈틀!"),
  .init(atSeconds: 30*60, kind: .crack(2),      toast: "금이 가기 시작했어요"),
  .init(atSeconds: 60*60, kind: .majorGrowth,   toast: "거의 다 왔어요!"),
  // 목표 도달 → hatchReady ]
```
- **XP**: `lifetimeXP = 누적 집중 분`에서 파생(저장은 분 합계 한 개). 레벨/문구는 표시용. → 성장 로직 불변.

### 3) 상태관리
- `GrowthManager.stage: GrowthStage`(파생), `lastShownMilestoneIndex`(중복 팝업 방지).
- 마일스톤 통과 시 `DialogueManager`/토스트로 연출 전달(이벤트 단방향).

### 4) DB 스키마
- 성장 자체는 **세션의 activeSeconds에서 파생** → 별도 저장 불필요.
- 알 종류만 영속:
```swift
@Model final class EggInstance { var id: UUID; var typeRaw: String; var targetSeconds: Int; var startedAt: Date; var hatched: Bool }
```

### 5) SwiftUI 통합
- `EggView(stageIndex:)` 그대로 사용(이미 6단계 에셋). `GrowthManager.stageIndex` 주입.
- 마일스톤 토스트 = 상단 오버레이/대사 말풍선(Feature 4 재사용).

### 6) 엣지케이스
- 일시정지 중 시간 정지(성장도 정지) — `activeSeconds` 기준이라 자동 충족.
- 마일스톤 **건너뛰기**(백그라운드 복귀로 한 번에 통과): 미표시 마일스톤은 "묶음 토스트" 또는 마지막 것만 표시.
- 목표시간 변경(설정): 테이블을 비율로 스케일.

### 7) MVP vs 확장
- **MVP**: 고정 마일스톤 테이블 + crack/부화 + XP 토스트.
- **확장**: 알 종류별 테이블/연출, XP 레벨업 화면, 시즌 알.

---

# Feature 3 — 생명체 컬렉션 (Collection)

> 등급은 **4단계 유지**(Common/Uncommon/Rare/Legendary). Epic은 향후 옵션.

### 1) 아키텍처
- 정적 카탈로그(`CreatureSpecies`, 코드) + 영속 수집본(`CollectedCreature`, SwiftData). `CollectionManager`가 부화→upsert.

### 2) 데이터 모델
```swift
@Model final class CollectedCreature {
    @Attribute(.unique) var speciesRaw: String   // CreatureSpecies.rawValue (종당 1행)
    var count: Int                               // 중복 수
    var firstHatchedAt: Date
    var lastHatchedAt: Date
    var representativeImage: String              // 대표 변형(닭 표정 등)
    var isEvolvedSeen: Bool                      // 진화본 본 적 있음
}
```
- 등급/이름/확률/이미지풀은 `CreatureSpecies`에서 파생(중복 저장 X).

### 3) 상태관리(언락/중복)
```
hatch():
  species = CreatureSpecies.roll()             // 기존 가중 추첨
  if let row = fetch(species):                  // 이미 보유 → 중복
       row.count += 1; row.lastHatchedAt = now
       award(.duplicateXP)                       // 중복은 XP/연출 보상(연출)
  else:                                          // 신규 언락
       insert(CollectedCreature(...)); markNew()
```
- 발견 판정: `count > 0`. 컬렉션의 실루엣/"?"(이미 구현) 그대로 사용.

### 4) DB 스키마
| SwiftData `CollectedCreature` | Supabase `collected_creatures` |
|---|---|
| speciesRaw (unique) | (user_id, species) unique |
| count | count int |
| firstHatchedAt / lastHatchedAt | first_at / last_at timestamptz |
| representativeImage | rep_image text |

### 5) SwiftUI 통합
- 현 `CollectionView`(7종 나열·발견 n/7·실루엣)에 `CollectionManager` 주입으로 교체.
- 상세 시트에 "보유 N마리 / 최초 부화일" 추가.

### 6) 엣지케이스
- 같은 종 다른 변형(닭 표정) → 대표 변형 1개 유지 + 보유 변형 set(확장).
- 오프라인 부화 후 동기화 충돌 → count는 **합산(merge)** 정책.

### 7) MVP vs 확장 (수익화 호환)
- **MVP**: 무료 7종, 중복=XP.
- **확장(수익화 대비 필드만 선반영)**: `CreatureSpecies`에 `isPremiumOnly`, `source(free/premium/event)`. 프리미엄 종은 무료 풀 가중치에서 제외하고 별도 알/이벤트에서만 추첨 → Feature 9의 entitlement 게이트와 연결.

---

# Feature 4 — 캐릭터 대사 시스템 (Dialogue)

### 1) 아키텍처
- `DialogueManager`가 트리거를 받아 **조건 필터 → 가중 랜덤 → 비반복/쿨다운**으로 한 줄 선택.

### 2) 데이터 모델
```swift
struct DialogueLine: Identifiable {
    let id: String
    let text: String
    let trigger: Trigger          // tick / appReturn / sessionComplete / streak / idle
    let weight: Int
    let minStreak: Int?           // 조건(예: 7일 이상)
    let speciesScope: [CreatureSpecies]?   // 특정 종 전용(옵션)
    let cooldown: TimeInterval    // 이 줄 재등장 최소 간격
}
enum Trigger { case tick, appReturn, sessionComplete, streakMilestone, idle }
```

### 3) 트리거 시스템
| 트리거 | 발생원 |
|---|---|
| tick | GrowthManager 마일스톤 / N분 주기 |
| appReturn | scenePhase active 복귀(Feature 6 연동) |
| sessionComplete | SessionManager 완료 |
| streakMilestone | StatsManager 스트릭 갱신 |
| idle | 일정 시간 무입력 |

### 4) 랜덤/비반복/쿨다운
- **최근 표시 링버퍼**(최근 K개 제외) + **줄별 cooldown** + **전역 글로벌 쿨다운**(예: 같은 세션 30초 내 1회).
- 가중 랜덤은 기존 `roll()` 패턴 재사용(주입형 RNG → 테스트 가능).
```
candidates = lines.filter(trigger == t && conditionsMet && notInRecent && cooldownElapsed)
pick = weightedRandom(candidates); recent.push(pick.id); pick.lastShown = now
```

### 5) SwiftUI 통합
- 알/캐릭터 위 말풍선 View. `DialogueManager.currentLine` 구독 → 페이드 인/아웃.

### 6) 엣지케이스
- 후보 고갈(전부 쿨다운) → 폴백 줄 또는 표시 생략.
- 빠른 연속 트리거 → 글로벌 쿨다운으로 스팸 방지.

### 7) MVP vs 확장
- **MVP**: 로컬 정적 문구 테이블(JSON/Swift) + 비반복.
- **확장**: 종/시간/날씨/스트릭 맥락 문구, 서버 리모트 컨피그로 문구 교체, (후순위) AI 생성 대사(ADR-005).

---

# Feature 5 — 집중 통계 (Statistics)

### 1) 아키텍처
- **원자료 = 완료 세션**(`FocusSessionRecord`). **롤업 캐시 = `DailyStat`**(일 단위 사전 집계)로 주/월/스트릭을 O(일수)로 계산.

### 2) 데이터 모델
```swift
@Model final class DailyStat {
    @Attribute(.unique) var day: Date     // 자정 기준
    var totalActiveSeconds: Int
    var sessionCount: Int
    var completedCount: Int
    var interruptionCount: Int
    var hatchedCount: Int
}
```
- 스트릭 = `DailyStat`에서 `totalActiveSeconds >= 임계` 연속일 계산.
- 완료율 = `completedCount / sessionCount`.

### 3) 집계 전략
- 세션 종료 시 해당 일자 `DailyStat` **증분 갱신**(전체 재계산 X).
- 주/월 차트 = 해당 범위 `DailyStat`만 조회(현 `ProgressViewModel.weeklyHours` 로직을 롤업 기반으로 이전).

### 4) DB 스키마
| `DailyStat`(SwiftData) | Supabase `daily_stats` |
|---|---|
| day (unique) | (user_id, day) unique |
| totalActiveSeconds | total_active_seconds int |
| sessionCount/completedCount | … int |
| interruptionCount/hatchedCount | … int |

### 5) SwiftUI 통합
- `ProgressScreen` 유지. `StatsManager`가 일/주/월 세그먼트, 스트릭(현재 더미 `"12일"`→실제), 완료율, 컬렉션 진행도(`CollectionManager`에서) 제공.

### 6) 엣지케이스
- 타임존/자정 경계: 세션의 `startedAt` 로컬 자정으로 버킷팅, 자정 걸친 세션은 시작일 귀속(또는 분할 — MVP는 시작일).
- 롤업 누락 복구: 앱 시작 시 마지막 롤업 이후 세션만 재집계.

### 7) MVP vs 확장
- **MVP**: 로컬 롤업 + 일/주 차트 + 스트릭.
- **확장**: 월/연 히트맵, 목표 설정, 서버 집계·리더보드(후순위).

---

# Feature 6 — 이탈/방해 추적 (Interruption Tracking)

### 1) 아키텍처
- `scenePhase` / `UIApplication` 전이를 `InterruptionTracker`가 받아 **이탈 구간**을 측정·분류·점수화. Feature 1 세션에 종속.

### 2) 이벤트/분류
```swift
struct InterruptionEvent { let leftAt: Date; let returnedAt: Date; var seconds: Int { ... }
    var severity: Severity {
        switch seconds {
        case ..<30:   return .ignored          // 0–30s 무시(잠금화면/알림센터)
        case ..<180:  return .minor            // 30s–3m
        case ..<600:  return .interruption     // 3–10m
        default:      return .distracted       // 10m+
        }
    }
}
enum Severity { case ignored, minor, interruption, distracted }
```

### 3) 이벤트 추적
- 백그라운드 진입 → `leftAt = now`. 복귀 → `returnedAt = now`, 이벤트 확정.
- 세션에 누적: `interruptionCount`(minor 이상), `distracted = any(.distracted)`.

### 4) 스코어링
```
focusScore (0~100) = 100
   - minor*2 - interruption*8 - distracted*20      // 가중 페널티
   - max(0, (planned-active)/planned * 30)          // 미달 페널티
```
- 기존 `keptScreenOn`(Boolean)을 **focusScore + severity**로 대체(더 정밀).

### 5) SwiftUI 통합
- 세션 완료 시트에 "방해 N회 · 집중 점수 86" 표시. Progress에 평균 점수/방해 추이.

### 6) 엣지케이스
- 전화/FaceID/제어센터(짧음) → 30초 유예로 자연 흡수.
- 의도적 일시정지(pause)는 이탈로 보지 않음(별도 상태).
- 연속 토글(빠른 전환) → 디바운스.

### 7) MVP vs 확장
- **MVP**: 이탈 시간 측정·4단계 분류·세션 점수.
- **확장**: 알림/통화 원인 구분, 주간 "집중 품질" 리포트.

---

# Feature 7 — 화면 꺼짐 방지 (Keep Screen Awake)

### 1) 구현 접근
- `UIApplication.shared.isIdleTimerDisabled = true` — **세션 running 동안만** ON. pause/complete/abandon/백그라운드에서 OFF.
- SwiftUI에서는 `ScreenAwakeManager`가 UIKit 호출을 캡슐화(`@MainActor`).

### 2) 설정 통합
- `@AppStorage("keepScreenAwake") var enabled = true` (MyPage 토글).
- `SessionManager`가 시작 시 설정값 확인 → `ScreenAwakeManager.apply(running, enabled)`.

### 3) 배터리 고려
- 세션 중에만 활성, 종료 즉시 해제(영구 ON 금지).
- 토글 설명에 배터리 영향 명시. 저전력 모드 감지 시 권고 문구(옵션).
- **유효 집중 판정**과 연동: 화면 유지 시 집중 품질 가점(Feature 6).

### 엣지/확장
- 백그라운드 전환 시 시스템이 자동 해제 → 복귀 시 재적용.
- 확장: 밝기 자동 디밍(집중 모드), 화면 위 최소 UI.

---

# Feature 8 — 앱 차단 (App Blocking) — *미래*

### 1) 아키텍처 제안
- Apple **Screen Time API** 3종: `FamilyControls`(권한/선택) + `ManagedSettings`(차단 적용) + `DeviceActivity`(스케줄 감시).
- `AppBlockManager`: 권한 요청 → 사용자 앱 선택 → 세션 동안 shield 적용 → 종료 시 해제.

### 2) 전략/권한 흐름
```
AuthorizationCenter.requestAuthorization(.individual)   // Family Controls 권한(애플 승인 필요)
FamilyActivityPicker → FamilyActivitySelection           // 사용자가 차단 앱 선택(앱은 목록 직접 못 읽음)
ManagedSettingsStore.shield.applications = selection      // 세션 중 차단
DeviceActivityCenter.startMonitoring(schedule)           // 스케줄 기반 강제(옵션)
```

### 3) 핵심 제약
- **Family Controls Distribution 엔타이틀먼트**(Apple 별도 승인) 필요 → 출시 일정 영향.
- 앱은 어떤 앱을 골랐는지 **불투명 토큰**으로만 다룸(프라이버시).
- DeviceActivity 모니터는 **앱 익스텐션**에서 동작.

### MVP vs 확장
- **MVP: 제외**(엔타이틀먼트 승인·익스텐션 비용 큼).
- **확장**: 프리미엄 기능으로 포지셔닝(Feature 9), 스케줄/요일 차단, 화이트리스트.

---

# Feature 9 — 프리미엄 (Premium / Entitlements)

### 1) 엔타이틀먼트 아키텍처
- **StoreKit 2** `Transaction.currentEntitlements`로 로컬 판정 + **서버 검증**(App Store Server Notifications → FastAPI → Supabase `entitlements`)로 멀티기기·환불 반영.
- `EntitlementManager.isActive(_:)` 단일 게이트. 모든 프리미엄 콘텐츠는 이 게이트만 본다.

```swift
enum Entitlement { case premium, premiumPlus }
protocol EntitlementGate { func isActive(_ e: Entitlement) -> Bool }
```

### 2) 콘텐츠 게이팅(데이터 플래그)
| 콘텐츠 | 게이트 방식 |
|---|---|
| 전용 알 / 전설 생명체 | `CreatureSpecies.isPremiumOnly` + 알 풀 분리 |
| 프리미엄 테마 | `Theme.isPremium` (다크+골드 외 스킨) |
| 부화 애니메이션 | `HatchAnimation.isPremium` |
| 고급 분석 | StatsManager 고급 뷰 게이트 |

### 3) 확장성
- 서버 권위 엔타이틀먼트(ADR-004 FastAPI) → 가격/구성 변경을 서버에서.
- 구독 티어 추가 시 `Entitlement` enum만 확장.
- 프로모션/평가판: `expiresAt` 포함 엔타이틀먼트 레코드.

### MVP vs 확장
- **MVP**: 인터페이스(`EntitlementGate`)와 데이터 플래그만 선반영(전부 무료로 동작). 결제 미연결.
- **확장**: StoreKit2 결제 + 서버 검증 + 프리미엄 콘텐츠 활성화.

---

# B. MVP 로드맵 (Phase 매핑)

| 순서 | 묶음 | 포함 기능 | 비고 |
|---|---|---|---|
| **2-1** | 세션 코어 | F1 세션, F7 화면유지, F2 성장/부화 연결 | 기존 EggState/EggView 재사용, 홈 실작동 |
| **2-2** | 영속/도감 | SwiftData 도입, F3 컬렉션 영속, CollectionManager | CollectionStore 승격 |
| **2-3** | 측정/통계 | F6 이탈추적, F5 통계 롤업 | keptScreenOn → focusScore |
| **2-4** | 정서 보상 | F4 대사 시스템 | 말풍선/토스트 |
| **3-x** | 백엔드/계정 | Supabase Auth, Sync, F9 결제 | ADR-007 |
| **future** | 고급 | F8 앱차단, AI 대사 | 엔타이틀먼트 승인 필요 |

## C. 횡단 관심사
- **테스트**: 도메인 규칙(세션 재계산·성장 마일스톤·추첨·점수·스트릭)은 순수 함수 + 주입형 RNG/Clock으로 단위 테스트(현 `CreatureSpeciesTests` 패턴).
- **시간 추상화**: `protocol Clock { var now: Date }` 주입 → 시계 의존 로직 테스트·치트 방지.
- **동기화 정책**: 카운트/통계는 merge(합산), 단일 값은 updatedAt last-write-wins.
- **접근성/현지화**: 문구 테이블 분리(대사·토스트), Dynamic Type 유지.

## D. 결정 로그(Decision Log)
1. 등급 4단계 유지(Epic 보류).
2. 성장/부화는 시간 기반, XP는 연출용 파생(경제 아님).
3. 세션은 타임스탬프 재계산 + 즉시 영속 + 상태머신.
4. 통계는 DailyStat 롤업으로 성능 확보.
5. keptScreenOn(Bool) → focusScore/severity로 대체.
6. 프리미엄/앱차단은 인터페이스·플래그만 선반영, 활성화는 후순위.
