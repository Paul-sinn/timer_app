# 프로젝트: {프로젝트명}

## 기술 스택
- {프레임워크 (예: Next.js 15)}
- {언어 (예: TypeScript strict mode)}
- {스타일링 (예: Tailwind CSS)}

## 아키텍처 규칙
- CRITICAL: {절대 지켜야 할 규칙 1 (예: 모든 API 로직은 app/api/ 라우트 핸들러에서만 처리)}
- CRITICAL: {절대 지켜야 할 규칙 2 (예: 클라이언트 컴포넌트에서 직접 외부 API를 호출하지 말 것)}
- {일반 규칙 (예: 컴포넌트는 components/ 폴더에, 타입은 types/ 폴더에 분리)}

## 개발 프로세스
- CRITICAL: 새 기능 구현 시 반드시 테스트를 먼저 작성하고, 테스트가 통과하는 구현을 작성할 것 (TDD)
- 커밋 메시지는 conventional commits 형식을 따를 것 (feat:, fix:, docs:, refactor:)

## 명령어
npm run dev      # 개발 서버
npm run build    # 프로덕션 빌드
npm run lint     # ESLint
npm run test     # 테스트

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

- **2026-06-12 · UITest "Simulator device failed to launch" → 코드 크래시로 오인 금지**
  - 증상: `xcodebuild test`가 앱 런치 실패를 반복 재시도하며 묶임. 동시에 `MobileCal`/`WidgetRenderer` .ips 크래시 리포트 발생.
  - 원인: 시뮬레이터 launchd 불안정(테스트 호스트 런치). MobileCal/WidgetRenderer는 **시스템 앱**이라 우리 앱과 무관. 우리 앱(Eggtimer/hatchly) .ips는 없음 = 코드 크래시 아님.
  - 교훈: 런치 실패 시 우리 번들 .ips 유무로 코드 크래시/환경 문제 구분. 검증은 `simctl install + launch`로 직접 런치(살아있으면 정상) + `-only-testing:EggtimerTests`로 UITest 제외하고 순수 로직만 확인.
