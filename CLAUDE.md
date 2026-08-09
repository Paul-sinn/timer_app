# 알아둬야할것

본 개발자는 아직 초보개발자라 어려운단어나 생소한 단어 혹은 coding agent 만 아는 단어들에대해 잘모른다 그러니 초등학생한테 설명하듯이 쉬운풀이나 설명을 간략하게 덧붙여서 대답해라.
초보개발자인만큼 배우고싶은게많다, 그러니 내가 개발을진행하면서 계속배울수있게 내가 질문을하면 간략하고 쉽게 설명을해야한다.

# 프로젝트: Hatcho (알 부화 집중 타이머)

집중 세션을 완주하면 알이 부화해 생명체를 얻고, 이어서 집중할수록 그 생명체가 진화하는 iOS 앱.
**앱 표시명(App Store·홈화면)은 `Hatcho`** (CFBundleDisplayName, 유저노출 이름의 단일 출처 — 새 유저노출 문자열은 "Hatcho"로).
Xcode 타깃/코드베이스 이름은 `Eggtimer`, 번들 ID는 `com.paulsin.hatchly` (둘 다 그대로 유지 — 바꾸면 유저 데이터 컨테이너가 갈린다).

상세 설계는 `docs/` 참조: `PRD.md`(요구사항) · `ARCHITECTURE.md`(구조) · `ADR.md`(결정 기록) · `UI_GUIDE.md`(디자인 토큰) · `FEATURE_DESIGN.md` · `DIALOGUE_SYSTEM.md`.

## 기술 스택
- Swift 5 언어 모드 / SwiftUI, 배포 타깃 iOS 26.5
- SwiftData (로컬 영속) + Supabase (Auth·Postgres 미러, 로그인 시에만)
- 로그인: Apple Sign In + Google Sign-In
- 테스트: Swift Testing(`@Test`, EggtimerTests) / XCUITest(EggtimerUITests)
- 빌드 설정: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`

## 디렉토리
```
ios/Eggtimer/
├── App/           # RootView(4탭 TabView), RootTab
├── DesignSystem/  # AppColor · AppFont · AppSpacing (색/폰트/간격 단일 출처)
├── Models/        # Creature · CreatureSpecies · Rarity · FocusSession · @Model 레코드
├── Components/    # 공용 버튼·카드·행
├── Features/      # Home · Collection · Progress · MyPage · Settings · Onboarding · Dialogue · Review
├── Services/      # Auth · Supabase · Sync · Notifier · AppSettings
├── Resources/     # 캐릭터 렌더링(CreatureArt/CreatureImage/AnimatedCreatureView) · Localizable.xcstrings
├── Stats/         # StatsEngine (통계 순수 로직)
└── Mock/          # CollectionStore · FocusHistoryStore (SwiftData 래퍼)
images/            # 원본 아트(앱 번들 아님). 런타임 에셋은 Assets.xcassets에 파생본으로 넣는다.
```

## 아키텍처 규칙
- CRITICAL: **Xcode 프로젝트는 `PBXFileSystemSynchronizedRootGroup`(objectVersion 77)이다.** `Eggtimer/` 아래에 파일을 만들면 타깃에 자동 포함된다 — `project.pbxproj`를 손으로 고치지 말 것(충돌·손상 위험).
- CRITICAL: 색·폰트·간격은 `AppColor`/`AppFont`/`AppSpacing`만 사용. 뷰에 하드코딩 금지. 앱은 **다크모드 고정**(`preferredColorScheme(.dark)`).
- CRITICAL: 확률·등급·진화 규칙의 단일 출처는 `CreatureSpecies`/`Creature`. 화면에서 재구현하지 말 것.
- 네트워크·데이터 레이어 타입은 `nonisolated`로 선언해 MainActor 격리 전파를 끊는다(`SyncMerge`, `SupabaseService` 참고).
- 순수 로직(통계·머지·추첨·에셋 해석)은 뷰에서 분리해 유닛 테스트 가능하게 유지.

## 캐릭터 아트 파이프라인
- 원본 PNG: `images/final-character/{character}/{character}_stage{1-3}_{idle|action}.png` (941×1672, 배경 불투명). **원본은 손대지 않는다.**
- 런타임 에셋: 배경 제거 + **캐릭터별 공통 캔버스에 bottom-center 배치**한 파생본을 `Assets.xcassets/{변형}Stage{1-3}{Idle|Action}.imageset`에 넣는다. 한 캐릭터의 6프레임은 캔버스 크기가 같아야 프레임/단계 전환에서 튀지 않는다(`CreatureArtTests`가 강제).
- 화면은 에셋명을 직접 쓰지 말고 **`CreatureArt`(해석) + `AnimatedCreatureView`(렌더)** 를 거친다.
- 애니메이션 세트가 없는 종(`Chicken1`·슬라임 등)은 `CreatureArt.animatedAssetName`이 nil을 주고 기존 단일 이미지로 폴백한다.
- 픽셀아트는 `.interpolation(.none)`, 프레임 교체엔 `.transaction { $0.animation = nil }`로 크로스페이드를 차단한다.

## 데이터 영속/마이그레이션 (CRITICAL — 유저 데이터 보호)
영속 데이터: SwiftData `@Model` `HatchedCreatureRecord`(부화 이력) / `FocusSessionRecord`(집중 이력). 로그인 시 Supabase 미러(추가 백업·기기간 동기화). 비로그인은 로컬만(기기 백업엔 포함).
- CRITICAL: `@Model` 필드를 **이름변경/삭제/타입변경 금지**. 하면 자동 lightweight 마이그레이션 실패 → 앱 업데이트 시 유저 데이터 소실/크래시.
- CRITICAL: 필드 추가는 **옵셔널 또는 기본값**으로만(lightweight 호환). 그 외 스키마 변경은 반드시 `VersionedSchema` + `SchemaMigrationPlan`을 작성하고 구버전 데이터로 마이그레이션 테스트 후 릴리스.
- CRITICAL: 동기화/머지는 **id 기준 idempotent 합집합**만(기존 로직 유지). 원격 데이터로 로컬을 통째 덮어쓰지 말 것.
- 진화 단계 등 파생값은 저장하지 말고 이력에서 계산(스키마 안정성↑). 새 영속 필드는 신중히.

## 개발 프로세스
- CRITICAL: 새 기능 구현 시 반드시 테스트를 먼저 작성하고, 테스트가 통과하는 구현을 작성할 것 (TDD)
- 커밋 메시지는 conventional commits 형식을 따를 것 (feat:, fix:, docs:, refactor:)

## 명령어
```bash
cd ios
SIM='platform=iOS Simulator,name=iPhone 17 Pro'

# 빌드
xcodebuild build -project Eggtimer.xcodeproj -scheme Eggtimer -destination "$SIM"

# 유닛 테스트만 (UITest는 시뮬레이터 런치가 불안정해 기본적으로 제외)
xcodebuild test -project Eggtimer.xcodeproj -scheme Eggtimer -destination "$SIM" \
  -only-testing:EggtimerTests -resultBundlePath /tmp/res.xcresult

# 실패 사유 확인 (추측 금지)
xcrun xcresulttool get test-results summary --path /tmp/res.xcresult
```

검수용 환경변수 훅(둘 다 DEBUG 전용, 프로덕션 UI에 진입 버튼 없음):
- `START_TAB` — 시작 탭 지정
- `CREATURE_GALLERY=1` — 캐릭터 아트 갤러리(5종 × 3단계 × idle/action)로 진입
  `SIMCTL_CHILD_CREATURE_GALLERY=1 xcrun simctl launch <device> com.paulsin.hatchly`

## 실수/실패 기록 (Claude 자기교정 로그)
> 규칙: 실수하거나 실패할 때마다 여기에 한 줄 추가한다. (증상 → 원인 → 교훈)

- **2026-06-11 · `plannedSeconds` didSet 무한재귀(SIGSEGV)**
  - 증상: 모든 SessionManagerTests가 0.000초에 동반 실패, 시뮬레이터 "Eggtimer 예상치 못하게 종료" 반복.
  - 원인: `var plannedSeconds { didSet { plannedSeconds = oldValue } }` — didSet 안에서 자기 대입 → 무한재귀 → 스택오버플로.
  - 교훈: 프로퍼티 setter에서 같은 프로퍼티에 대입 금지. 가드는 백킹 스토어 + computed setter로.

- **2026-06-11 · 크래시 원인을 로그 안 보고 추측해 시간 낭비**
  - 증상: 테스트가 "crashed"로 실패할 때 "시뮬레이터 불안정/dual-container"라고 여러 번 잘못 추측하며 재시도(시뮬레이터 churn 유발, 사용자 불편).
  - 원인: `~/Library/Logs/DiagnosticReports/*.ips` 크래시 리포트(시그널·백트레이스)를 먼저 안 읽음.
  - 교훈: 테스트/앱이 crash로 실패하면 **추측 전에 .ips 크래시 리포트의 시그널+백트레이스부터 확인**한다. (`xcresulttool get test-results summary/tests` 로 실제 실패 사유 먼저 확인)

- **2026-06-11 · SwiftData in-memory 스토어 fetch가 SIGTRAP**
  - 증상: 유닛 테스트에서 `ModelContainer(isStoredInMemoryOnly: true)` + `context.fetch`가 트랩(`try?`로 안 잡힘). 실제 앱(온디스크)은 정상.
  - 원인: iOS 26 시뮬레이터에서 in-memory 스토어 fetch 트랩.
  - 교훈: SwiftData 테스트는 in-memory 대신 **온디스크 임시 스토어(고유 URL)** 사용. `try?`는 trap을 못 잡는다.

- **2026-06-11 · SwiftData fetch가 Swift Testing 컨텍스트에서 SIGTRAP (테스트 불가)**
  - 증상: `CollectionStore.init`의 `context.fetch`가 유닛 테스트에서 트랩. 온디스크로 바꿔도 동일. 단, **실제 앱 런치 경로의 동일 fetch는 정상**.
  - 원인: SwiftData ModelContext fetch가 Swift Testing(@Sendable/Task) 실행 컨텍스트와 안 맞음(iOS 26 시뮬레이터). 코드 버그 아님.
  - 교훈: SwiftData "컨테이너+fetch" 통합은 Swift Testing 유닛 테스트로 검증하지 말 것. 매핑 등 순수 로직만 단위 테스트하고, 컨테이너 경로는 실제 앱 실행으로 검증. (XCTest UI/통합 테스트는 별도 고려)

- **2026-06-11 · 멈춘 빌드/테스트를 kill -9 남발 → 빌드 산출물/결과번들 손상**
  - 증상: `swiftStdLibTool` 행으로 보여 반복 kill → DerivedData/result bundle 손상(`mkstemp: No such file or directory`).
  - 교훈: 행으로 보여도 성급히 kill 말 것. 필요하면 DerivedData 클린 + `-resultBundlePath`를 깨끗한 경로로 지정.

- **2026-06-11 · @MainActor 클래스의 deinit에서 격리 프로퍼티 접근 → 컴파일 에러**
  - 증상: AuthService(`@Observable @MainActor`)에서 `deinit { observationTask?.cancel() }`가 "main actor-isolated property can not be referenced from a nonisolated context"로 빌드 실패.
  - 원인: 프로젝트가 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`라 타입이 기본 MainActor 격리되는데, deinit은 nonisolated → 격리 저장 프로퍼티 접근 불가.
  - 교훈: 격리 클래스 deinit에서 격리 상태 만지지 말 것. 무한 AsyncStream 구독은 **루프 안에서 self를 약참조**(`guard let self else { break }`)해 self 해제 시 자연 종료시키면 task 저장·deinit 취소가 불필요. 네트워크/데이터 레이어 타입은 `nonisolated`로 선언해 MainActor 격리 전파를 끊는다(기본격리 경고도 해소).

- **2026-06-12 · 명시적 `@MainActor` 클래스를 init 기본인자로 생성 → 컴파일 에러**
  - 증상: `init(auth: AuthService = AuthService())`가 "call to main actor-isolated initializer in a synchronous nonisolated context"로 실패. 단, `EggtimerApp.init`(MainActor) 안에서 직접 `AuthService()` 생성은 정상.
  - 원인: 기본인자 식은 호출부의 nonisolated 맥락에서 평가됨. 명시적 `@MainActor` 타입의 init은 MainActor 격리라 기본인자 위치에서 호출 불가. (추론 MainActor인 `CollectionStore()`는 통과 — 비대칭)
  - 교훈: 명시적 `@MainActor` 의존성은 init 기본인자로 두지 말 것. 필수 파라미터로 받고, 프리뷰/검수 호출부(SwiftUI `#Preview`·View body = MainActor)에서 명시적으로 주입.

- **2026-07-22 · 스프라이트 시트에서 자른 프레임을 원본 좌표 그대로 쓰면 캐릭터가 튄다**
  - 증상: 닭 idle/action 두 장이 같은 941×1672 캔버스인데 캐릭터 x좌표가 최대 138px 어긋남(annoyed stage1 등). 공통 crop box를 쓰면 전환 때 캐릭터가 옆으로 점프.
  - 원인: 2×3 생성 시트를 6칸으로 분할할 때 칸마다 캐릭터 위치가 달랐음(아트 의도가 아니라 분할 아티팩트). 이웃 칸에서 잘려 들어온 조각(헬창닭 2단계 발밑 빨간 점, 3단계 우측 회색 조각)도 있어 bbox까지 오염.
  - 교훈: 프레임 정렬 기준은 **원본 캔버스 좌표가 아니라 알파 bbox**. 프레임별로 타이트 크롭 → 캐릭터 단위 공통 캔버스에 **bottom-center 배치**해야 idle/action·단계 전환 모두 안 튄다. 배경 제거는 색 임계값 말고 **테두리에서 시작하는 연결 성분**으로(흰 깃털 보존). 테두리에 닿거나 본체 발밑보다 아래에 있는 조각은 버릴 것. `CreatureArtTests`가 캔버스 크기·종횡비 동일성을 회귀 검증한다.

- **2026-07-22 · `simctl install`이 무한 행 → CoreSimulator 서비스 재시작으로 해결**
  - 증상: 시뮬레이터는 Booted인데 `xcrun simctl install`이 5분+ 멈춤. 이후 `simctl` 호출까지 전부 블록(`get_app_container`도 행).
  - 원인: CoreSimulatorService 데몬이 꼬임. 앱/코드 문제 아님(같은 커밋으로 `xcodebuild test`는 82개 통과).
  - 교훈: `kill -TERM <hung simctl>` → `xcrun simctl shutdown all` → `killall -9 com.apple.CoreSimulator.CoreSimulatorService` → 재부팅 후 재설치. **DerivedData는 건드리지 말 것**(빌드 산출물은 멀쩡하다). 29MB 앱이라 정상 설치도 1~2분 걸리니 폴링으로 기다릴 것.

- **2026-07-22 · SourceKit이 모듈 전체를 "Cannot find type"으로 오진 → 무시하고 빌드로 확인**
  - 증상: 파일 추가 후 IDE 진단이 `Rarity`/`AppColor`/`Creature` 등 기존 타입까지 전부 "Cannot find in scope"로 표시.
  - 원인: 파일시스템 동기화 그룹에 새 파일이 들어오면서 SourceKit 인덱스가 일시적으로 깨짐. 실제 컴파일은 정상.
  - 교훈: 프로젝트 전반이 한꺼번에 "not found"로 뜨면 코드 문제가 아니라 인덱스 문제다. 고치려 들지 말고 `xcodebuild build`로 판정할 것.

- **2026-06-12 · UITest "Simulator device failed to launch" → 코드 크래시로 오인 금지**
  - 증상: `xcodebuild test`가 앱 런치 실패를 반복 재시도하며 묶임. 동시에 `MobileCal`/`WidgetRenderer` .ips 크래시 리포트 발생.
  - 원인: 시뮬레이터 launchd 불안정(테스트 호스트 런치). MobileCal/WidgetRenderer는 **시스템 앱**이라 우리 앱과 무관. 우리 앱(Eggtimer/hatchly) .ips는 없음 = 코드 크래시 아님.
  - 교훈: 런치 실패 시 우리 번들 .ips 유무로 코드 크래시/환경 문제 구분. 검증은 `simctl install + launch`로 직접 런치(살아있으면 정상) + `-only-testing:EggtimerTests`로 UITest 제외하고 순수 로직만 확인.

- **2026-07-28 · 파이프친 백그라운드 xcodebuild "완료" 알림을 믿고 두 번째 빌드 띄움 → build.db 락 충돌**
  - 증상: 백그라운드 `xcodebuild test ... | tail -30`이 "completed exit 0"으로 알림 왔길래 두 번째 test를 띄움 → `error: unable to attach DB: database is locked. Possibly there are two concurrent builds` → TEST FAILED(EXIT 65). 코드 실패 아님.
  - 원인: `| tail`은 xcodebuild가 **stdout을 닫으면**(테스트 출력 끝) 종료 → 백그라운드 태스크가 "완료"로 알림. 하지만 xcodebuild **프로세스는 xcresult 마무리 중**이라 아직 살아서 build.db 락을 쥐고 있음. tail 파이프의 exit도 xcodebuild의 실제 exit를 마스킹(항상 0).
  - 교훈: 백그라운드 xcodebuild는 (1) `| tail` 대신 `> log 2>&1; echo EXIT=$?`로 **실제 exit 캡처**, (2) 다음 build/test 띄우기 전에 `pgrep -f xcodebuild`로 **프로세스 실제 종료 확인**(태스크 "완료" 알림 ≠ 프로세스 종료), (3) 빌드는 **직렬화**(동시 실행 금지, 같은 DerivedData 공유). kill 금지(로그의 결과번들 손상 교훈).
