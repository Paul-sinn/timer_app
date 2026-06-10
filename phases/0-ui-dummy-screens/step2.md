# Step 2: mock-data

## 읽어야 할 파일

- `/docs/PRD.md` — 핵심 기능(타이머·부화·확률 생명체·컬렉션·집중 기록)과 화면 트리
- `/docs/ARCHITECTURE.md` — `Models/`, `Mock/`, `Resources/` 위치와 "1단계: Mock 더미 주입" 데이터 흐름
- `/docs/ADR.md` — ADR-006(캐릭터 이미지 Mock 우선)
- `/iOS/Eggtimer/DesignSystem/AppColor.swift` — 레어도 색상 등에 토큰 재사용

## 프로젝트 사실

- synchronized group이라 `iOS/Eggtimer/Models/`, `iOS/Eggtimer/Mock/`, `iOS/Eggtimer/Resources/`에 추가한 파일은 자동 포함.
- 이 데이터는 화면이 **로그인·백엔드 없이** 렌더되도록 하는 더미다. 모든 화면은 이 Mock만으로 그려진다.

## 작업

1. **도메인 모델** — `iOS/Eggtimer/Models/`. 일반 Swift 값 타입(struct/enum)으로 정의한다. SwiftData `@Model` 금지.
   - `Creature` — `id`, `name`, `rarity: Rarity`, `imageName: String`(추후 실제 에셋명으로 교체될 placeholder 키), `hatchedAt: Date`.
   - `Rarity` — `enum { common, rare, epic, legendary }`. 각 케이스에 표시색(`AppColor` 매핑)과 라벨 제공.
   - `FocusSession` — `id`, `date: Date`, `durationMinutes: Int`, `keptScreenOn: Bool`(집중 유효성 = 화면 안 끔 여부).
   - `EggState` — `crackStage: Int`, `progress: Double(0...1)`, 목표까지 남은 시간 등. 15분마다 crack 단계가 오르는 규칙을 표현하는 순수 계산 프로퍼티 포함.

2. **Mock 프로바이더** — `iOS/Eggtimer/Mock/MockData.swift`. 화면 검수를 위해 **두 가지 상태**를 반드시 제공한다.
   ```swift
   enum MockData {
       static let populated: AppSnapshot  // 생명체/세션이 채워진 상태
       static let empty: AppSnapshot      // 데이터가 비어 있는 상태(빈 화면 검수용)
   }
   ```
   `AppSnapshot`은 `creatures: [Creature]`, `sessions: [FocusSession]`, `egg: EggState`, 더미 유저(`displayName` 등)를 묶는 컨테이너로 정의한다. `populated`는 다양한 레어도/날짜를 골고루 포함한다.

3. **캐릭터 이미지 placeholder** — 실제 캐릭터 이미지는 추후 직접 제작하므로 지금은 자리만 채운다.
   - `iOS/Eggtimer/Resources/CreatureImage.swift`에 `CreatureImage`(View)를 만들어, `imageName`을 받아 **SF Symbol 기반 placeholder + 레어도 색 배경**으로 렌더한다(예: 알/생명체 느낌의 심볼).
   - 실제 에셋 교체가 한 곳에서 가능하도록, 이미지 렌더는 이 View 한 곳만 거치게 한다.

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
   - 모델이 순수 Swift 값 타입인가? (SwiftData 미사용)
   - `MockData.populated` 와 `MockData.empty` 가 모두 존재하는가?
   - 이미지 렌더가 `CreatureImage` 한 곳을 거치는가?
3. step 2 status 업데이트(성공 시 `summary`에 모델 타입·MockData 진입점 명시 — 다음 step들이 이걸 주입해 화면을 그린다).

## 금지사항

- SwiftData `@Model`/`ModelContainer`를 쓰지 마라. 이유: Phase 0는 영속성 없이 더미만 사용.
- 네트워크/Supabase/FastAPI 호출 코드를 만들지 마라. 이유: 이 step은 메모리 더미 데이터만 담당.
- 화면(View 레이아웃)을 구현하지 마라. `CreatureImage` placeholder는 예외(데이터 렌더 유틸).
- 기존 테스트를 깨뜨리지 마라.
