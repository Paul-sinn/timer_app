# Step 5: collection-screen

## 읽어야 할 파일

- `/docs/PRD.md` — 컬렉션 = 지금까지 부화한 생명체들을 본다
- `/docs/UI_GUIDE.md` — 카드/그리드, 레어 강조색(#60A5FA), 좌측 정렬 기본
- `/iOS/Eggtimer/Features/Collection/` — step3의 `CollectionView` placeholder
- `/iOS/Eggtimer/Models/` — `Creature`, `Rarity`
- `/iOS/Eggtimer/Mock/MockData.swift` — `populated`(생명체 다수) / `empty`(없음)
- `/iOS/Eggtimer/Resources/CreatureImage.swift` — 캐릭터 placeholder 렌더
- `/iOS/Eggtimer/Components/`, `/iOS/Eggtimer/DesignSystem/`

## 프로젝트 사실

- 데이터 없이도 화면 검수가 가능해야 한다 → **빈 상태(empty)와 채움 상태(populated)를 모두** 구현한다.
- 모든 캐릭터 이미지는 `CreatureImage` placeholder를 거친다(실제 에셋 추후 교체).

## 작업

1. **CollectionView 그리드** — `iOS/Eggtimer/Features/Collection/CollectionView.swift`(필요 시 ViewModel 분리). `LazyVGrid`로 생명체 카드 그리드.
   - 각 셀: `CreatureImage` + 이름 + **레어도 배지**(`Rarity` 색/라벨). 레어 이상은 강조.
   - 데이터는 주입된 `[Creature]`(기본 `MockData.populated.creatures`).
2. **빈 상태** — `creatures`가 비면 빈 상태 뷰("아직 부화한 생명체가 없어요" + 안내 심볼)를 보여준다.
3. **상세(선택)** — 셀 탭 시 간단한 상세 시트/내비게이션(이름·레어도·부화일)을 더미로 표시(과하지 않게).
4. **검수 가능성** — `CollectionView`가 외부에서 `creatures`를 주입받을 수 있도록 init 파라미터(기본값 = populated)를 둔다. `#Preview`에 populated/empty 두 케이스를 모두 추가한다.

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
   - populated/empty 두 상태가 모두 렌더되는가?
   - 레어도 배지 색이 `Rarity`/`AppColor`와 일치하는가?
   - 이미지가 `CreatureImage`를 거치는가?
3. step 5 status 업데이트(성공 시 `summary`에 주입 파라미터/빈상태 처리 명시).

## 금지사항

- 실제 데이터 소스(SwiftData/네트워크)를 연결하지 마라. 더미 주입만. 이유: Phase 0 범위.
- 다른 탭 화면을 수정하지 마라.
- UI_GUIDE 안티패턴(모든 카드 동일 과한 라운드, 네온 글로우 등)을 쓰지 마라.
- 기존 테스트를 깨뜨리지 마라.
