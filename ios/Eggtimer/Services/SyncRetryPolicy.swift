//
//  SyncRetryPolicy.swift
//  Eggtimer
//
//  Supabase 동기화의 오류 처리 정책(Phase 3-4). 전부 순수 값 타입 → 유닛 테스트 대상.
//  SyncCoordinator는 "언제 다시 보낼지 / 언제 포기할지"를 스스로 판단하지 않고 여기에 물어본다.
//
//  설계 요지
//  - 재시도는 **전송성 실패에만**. 인증 실패·쿼터 초과·클라이언트 오류는 몇 번을 더 보내도 같은 답이 온다.
//  - 정체를 모르는 에러는 **재시도하지 않는다**(보수적 기본값). 재시도 대상은 화이트리스트로만 넓힌다.
//  - 백오프에는 **반드시 지터**가 붙는다. 지터 없이 지수 백오프만 하면 장애가 풀리는 순간
//    같은 실패를 겪은 클라이언트가 한꺼번에 몰려(thundering herd) 서버를 다시 넘어뜨린다.
//  - 시도 횟수 상한과 누적 대기 상한을 **둘 다** 둔다. 어느 쪽이든 먼저 닿으면 포기한다.
//  - 포기해도 로컬 데이터는 그대로다(SwiftData가 이미 저장). SyncMerge가 id 기준 합집합이라
//    다음 syncOnLogin()이 빠진 항목을 전부 되살린다 — 그래서 "조용히 포기"가 안전하다.
//

import Foundation

// MARK: - 실패 분류

/// 동기화 실패의 성격. 재시도 가능 여부와 사용자 안내 문구의 단일 출처.
nonisolated enum SyncFailureKind: String, Sendable, CaseIterable {
    /// 네트워크 단절·타임아웃·5xx·429 등 다시 보내면 통할 수 있는 실패.
    case transient
    /// 401/403, JWT 만료, RLS 거부 — 재로그인 전에는 계속 실패한다.
    case auth
    /// 서버가 유저별 쓰기 쿼터 초과로 거부(B5). 재시도는 무의미하고 서버만 괴롭힌다.
    case quota
    /// 4xx·스키마/디코딩 불일치 등 우리 쪽 버그. 재시도해도 같은 결과.
    case client
    /// Task 취소. 실패가 아니라 "그만두라는 지시" — 사용자에게 알리지 않는다.
    case cancelled
    /// 정체 불명. 보수적으로 재시도하지 않는다.
    case unknown

    /// 재시도해도 되는 건 전송성 실패뿐.
    var isRetryable: Bool { self == .transient }

    /// 사용자에게 보여줄 안내(취소는 표시하지 않으므로 nil).
    /// 유저노출 문자열은 전부 String Catalog(Localizable.xcstrings)를 거친다. 앱 이름은 "Hatcho".
    var userMessage: String? {
        switch self {
        case .transient:
            return String(localized: "Couldn't reach Hatcho's server. Everything is saved on this device and will sync automatically next time.")
        case .auth:
            return String(localized: "Your sign-in expired. Sign in again to keep syncing. Nothing on this device was lost.")
        case .quota:
            return String(localized: "You've reached today's cloud save limit. Everything is saved on this device and will sync later.")
        case .client, .unknown:
            return String(localized: "Sync didn't finish. Everything is saved on this device and will sync automatically next time.")
        case .cancelled:
            return nil
        }
    }
}

/// 에러에서 뽑아낸 분류 단서. Supabase 타입에 의존하지 않는 순수 값이라
/// 분류 규칙 전체를 SDK 없이 테스트할 수 있다(매핑은 SyncErrorMapper 담당).
nonisolated struct SyncFailureSignal: Equatable, Sendable {
    /// HTTP 응답 상태 코드(HTTPError).
    var httpStatus: Int?
    /// PostgREST가 돌려준 SQLSTATE 또는 PGRSTxxx 코드(PostgrestError.code).
    var postgresCode: String?
    /// PostgrestError.hint — 서버가 거부 사유를 기계 판별용으로 심어 놓는 자리.
    var postgresHint: String?
    /// URLError.Code.rawValue.
    var urlErrorCode: Int?
    /// Task/URL 취소.
    var isCancelled: Bool
    /// 응답 디코딩 실패(스키마 불일치).
    var isDecodingFailure: Bool

    init(httpStatus: Int? = nil,
         postgresCode: String? = nil,
         postgresHint: String? = nil,
         urlErrorCode: Int? = nil,
         isCancelled: Bool = false,
         isDecodingFailure: Bool = false) {
        self.httpStatus = httpStatus
        self.postgresCode = postgresCode
        self.postgresHint = postgresHint
        self.urlErrorCode = urlErrorCode
        self.isCancelled = isCancelled
        self.isDecodingFailure = isDecodingFailure
    }
}

/// 단서 → 실패 종류. 화이트리스트 방식(모르면 재시도 안 함).
nonisolated enum SyncFailureClassifier {

    // MARK: 코드 표

    /// 서버가 유저별 쓰기 쿼터 초과를 거부할 때 쓰는 SQLSTATE.
    /// B5(`supabase/migrations/20260809113000_add_write_quota.sql`)의 계약:
    ///   `raise exception … using errcode = 'PT429', hint = 'hatcho_write_quota_exceeded'`
    /// PostgREST는 `PT<3자리>`를 그 HTTP 상태로 매핑하므로 응답은 **HTTP 429 + code "PT429"** 다.
    ///
    /// ⚠️ 여기가 이 파일에서 제일 미끄러운 지점이다: 일반 게이트웨이 rate limit도 429다.
    /// 상태 코드만 보면 "잠깐 뒤 재시도"로 오판하지만 쿼터 초과는 하루가 지나기 전엔 절대 통과하지 않는다.
    /// 그래서 **바디의 code/hint가 상태 코드보다 우선**한다(아래 kind(for:) 판정 순서).
    static let quotaPostgresCodes: Set<String> = [
        "PT429",  // B5 일일 INSERT 쿼터 초과
        "53400",  // configuration_limit_exceeded
        "54000"   // program_limit_exceeded
    ]

    /// 코드가 유실돼도 쿼터를 알아볼 수 있게 하는 2차 단서(B5가 hint에 심는 기계 판별용 문자열).
    static let quotaPostgresHints: Set<String> = ["hatcho_write_quota_exceeded"]

    /// 다시 보내면 통할 수 있는 SQLSTATE 클래스(앞 2자리).
    /// 08 connection_exception · 40 transaction_rollback · 53 insufficient_resources
    /// 57 operator_intervention · 58 system_error
    static let transientPostgresClasses: Set<String> = ["08", "40", "53", "57", "58"]

    /// PostgREST 자체 인프라 오류(DB 연결 실패·스키마 캐시 로드 실패·타임아웃).
    static let transientPostgrestCodes: Set<String> = ["PGRST000", "PGRST001", "PGRST002", "PGRST003"]

    /// 권한/인증 거부. 재로그인 전에는 재시도 무의미.
    static let authPostgresCodes: Set<String> = [
        "42501",     // insufficient_privilege (RLS 거부)
        "28000",     // invalid_authorization_specification
        "28P01",     // invalid_password
        "PGRST301",  // JWT 만료/무효
        "PGRST302"   // 익명 접근 불가
    ]

    /// 전송성 HTTP 상태(429 = rate limit, 5xx = 서버, 408/425 = 타임아웃/early data).
    static let transientHTTPStatuses: Set<Int> = [408, 425, 429]

    /// 인증 실패 HTTP 상태.
    static let authHTTPStatuses: Set<Int> = [401, 403]

    /// 다시 보내면 통할 수 있는 URLError.
    static let transientURLErrorCodes: Set<Int> = [
        URLError.Code.timedOut.rawValue,
        URLError.Code.cannotFindHost.rawValue,
        URLError.Code.cannotConnectToHost.rawValue,
        URLError.Code.networkConnectionLost.rawValue,
        URLError.Code.dnsLookupFailed.rawValue,
        URLError.Code.resourceUnavailable.rawValue,
        URLError.Code.notConnectedToInternet.rawValue,
        URLError.Code.badServerResponse.rawValue,
        URLError.Code.internationalRoamingOff.rawValue,
        URLError.Code.callIsActive.rawValue,
        URLError.Code.dataNotAllowed.rawValue,
        URLError.Code.secureConnectionFailed.rawValue
    ]

    /// 인증이 필요하다고 URL 로더가 알려준 경우.
    static let authURLErrorCodes: Set<Int> = [URLError.Code.userAuthenticationRequired.rawValue]

    // MARK: 판정

    static func kind(for signal: SyncFailureSignal) -> SyncFailureKind {
        // 취소는 다른 어떤 단서보다 우선한다(취소된 요청이 5xx로 끝났을 수도 있다).
        if signal.isCancelled { return .cancelled }
        // 쿼터 hint는 코드·상태보다 먼저 본다 — HTTP 429로 위장한 영구 실패를 걸러야 하기 때문.
        if let hint = signal.postgresHint, quotaPostgresHints.contains(hint) { return .quota }
        // 바디의 SQLSTATE가 상태 코드보다 정확하다(PT429 = 쿼터 초과 vs 429 = 게이트웨이 rate limit).
        if let code = signal.postgresCode { return kind(forPostgresCode: code) }
        if let status = signal.httpStatus { return kind(forHTTPStatus: status) }
        if let code = signal.urlErrorCode { return kind(forURLErrorCode: code) }
        if signal.isDecodingFailure { return .client }
        return .unknown
    }

    private static func kind(forPostgresCode code: String) -> SyncFailureKind {
        // 쿼터 판정이 어떤 클래스/상태 판정보다 **먼저**여야 한다.
        // PT429는 HTTP 429로, 53400은 class 53(전송성)으로 각각 "재시도해도 된다"로 오분류될 수 있다.
        // 순서가 뒤집히면 하루가 지나기 전엔 절대 통과하지 못할 요청을 계속 두드리게 된다.
        if quotaPostgresCodes.contains(code) { return .quota }
        if authPostgresCodes.contains(code) { return .auth }
        if transientPostgrestCodes.contains(code) { return .transient }
        // 나머지 PGRSTxxx는 요청/스키마 문제 → 재시도 무의미.
        if code.hasPrefix("PGRST") { return .client }
        // PostgREST 규약: SQLSTATE 'PT<3자리>'는 그 3자리를 HTTP 상태로 그대로 매핑한다.
        // (B4의 미래 timestamp 거부 'PT400' → 400 → .client)
        if let status = httpStatus(forPostgRESTStatusCode: code) { return kind(forHTTPStatus: status) }
        if transientPostgresClasses.contains(String(code.prefix(2))) { return .transient }
        return .client
    }

    /// 'PT429' → 429. PT 규약이 아니면 nil.
    private static func httpStatus(forPostgRESTStatusCode code: String) -> Int? {
        guard code.count == 5, code.hasPrefix("PT") else { return nil }
        return Int(code.dropFirst(2))
    }

    private static func kind(forHTTPStatus status: Int) -> SyncFailureKind {
        if authHTTPStatuses.contains(status) { return .auth }
        if transientHTTPStatuses.contains(status) { return .transient }
        if (500..<600).contains(status) { return .transient }
        if (400..<500).contains(status) { return .client }
        return .unknown
    }

    private static func kind(forURLErrorCode code: Int) -> SyncFailureKind {
        if code == URLError.Code.cancelled.rawValue { return .cancelled }
        if authURLErrorCodes.contains(code) { return .auth }
        if transientURLErrorCodes.contains(code) { return .transient }
        // 열거하지 않은 URL 오류(badURL, cannotParseResponse 등)는 정체를 모르는 것으로 보고 재시도하지 않는다.
        return .unknown
    }
}

// MARK: - 백오프 정책

/// 지수 백오프 + 지터 + 상한. 난수는 바깥에서 주입받아 계산이 완전히 결정적이다.
nonisolated struct SyncRetryPolicy: Sendable {
    /// 최초 시도를 포함한 총 시도 횟수(1이면 재시도 없음).
    let maxAttempts: Int
    /// 첫 재시도의 지터 없는 대기 상한.
    let baseDelay: TimeInterval
    /// 재시도마다 상한에 곱하는 배수.
    let multiplier: Double
    /// 단일 대기의 절대 상한.
    let maxDelay: TimeInterval
    /// 한 오퍼레이션이 재시도 대기로 쓸 수 있는 누적 시간 상한.
    let totalDelayBudget: TimeInterval
    /// 0 = 지터 없음, 1 = full jitter(0...cap 균등). 프리셋은 전부 1.
    let jitterFraction: Double

    init(maxAttempts: Int,
         baseDelay: TimeInterval,
         multiplier: Double = 2,
         maxDelay: TimeInterval,
         totalDelayBudget: TimeInterval,
         jitterFraction: Double = 1) {
        self.maxAttempts = max(1, maxAttempts)
        self.baseDelay = max(0, baseDelay)
        self.multiplier = max(1, multiplier)
        self.maxDelay = max(0, maxDelay)
        self.totalDelayBudget = max(0, totalDelayBudget)
        self.jitterFraction = min(max(jitterFraction, 0), 1)
    }

    // MARK: 프리셋

    /// 로그인 직후 pull(GET). 사용자가 스피너를 보며 기다리므로 짧게 끊는다.
    /// supabase-swift의 PostgrestBuilder가 **GET/HEAD에 한해** 503/520·네트워크 오류를
    /// 이미 3회(1s·2s·4s, 지터 없음) 자체 재시도한다 → 우리 재시도까지 곱하면 왕복이 폭증한다.
    static let loginPull = SyncRetryPolicy(maxAttempts: 2, baseDelay: 0.8, multiplier: 2,
                                           maxDelay: 4, totalDelayBudget: 6)

    /// 로그인 직후 push(POST upsert). SDK는 비멱등 메서드를 재시도하지 않으므로 우리가 책임진다.
    /// upsert는 PK 충돌 병합이라 재전송이 안전(idempotent).
    static let loginPush = SyncRetryPolicy(maxAttempts: 3, baseDelay: 0.8, multiplier: 2,
                                           maxDelay: 6, totalDelayBudget: 12)

    /// 부화·세션 종료 직후의 단건 push(사용자는 기다리지 않는다).
    /// 화면을 막지 않으니 간격은 넉넉히, 대신 총량은 30초로 잘라 배터리·데이터를 태우지 않는다.
    static let backgroundPush = SyncRetryPolicy(maxAttempts: 3, baseDelay: 3, multiplier: 4,
                                                maxDelay: 20, totalDelayBudget: 30)

    // MARK: 계산

    /// 지터 적용 전, retry번째(1-based) 재시도의 대기 상한.
    func delayCap(forRetry retry: Int) -> TimeInterval {
        guard retry >= 1 else { return 0 }
        return min(baseDelay * pow(multiplier, Double(retry - 1)), maxDelay)
    }

    /// 지터가 만들 수 있는 대기 구간(문서·테스트용).
    func delayRange(forRetry retry: Int) -> ClosedRange<TimeInterval> {
        let cap = delayCap(forRetry: retry)
        return (cap * (1 - jitterFraction))...cap
    }

    /// 결정적 대기 계산. `randomUnit`은 [0, 1] 범위의 난수(밖으로 나가면 잘린다).
    func delay(forRetry retry: Int, randomUnit: Double) -> TimeInterval {
        let cap = delayCap(forRetry: retry)
        let unit = min(max(randomUnit, 0), 1)
        return cap * (1 - jitterFraction) + cap * jitterFraction * unit
    }

    /// 난수원을 주입받는 편의 오버로드(테스트는 시드 생성기를 넣어 결정적으로 검증한다).
    func delay<G: RandomNumberGenerator>(forRetry retry: Int, using generator: inout G) -> TimeInterval {
        delay(forRetry: retry, randomUnit: Double.random(in: 0..<1, using: &generator))
    }

    /// 다음 재시도까지 기다릴 시간. nil이면 **더 시도하지 않는다**.
    /// - Parameters:
    ///   - attempt: 이미 끝난 시도 횟수(1-based).
    ///   - kind: 방금 실패의 성격.
    ///   - elapsedDelay: 지금까지 재시도 대기로 쓴 누적 시간.
    ///   - randomUnit: [0, 1] 난수(지터).
    func nextDelay(afterAttempt attempt: Int,
                   kind: SyncFailureKind,
                   elapsedDelay: TimeInterval,
                   randomUnit: Double) -> TimeInterval? {
        guard kind.isRetryable else { return nil }
        guard attempt >= 1, attempt < maxAttempts else { return nil }
        let remaining = totalDelayBudget - elapsedDelay
        guard remaining > 0 else { return nil }
        return min(delay(forRetry: attempt, randomUnit: randomUnit), remaining)
    }

    /// 난수원을 주입받는 편의 오버로드.
    func nextDelay<G: RandomNumberGenerator>(afterAttempt attempt: Int,
                                             kind: SyncFailureKind,
                                             elapsedDelay: TimeInterval,
                                             using generator: inout G) -> TimeInterval? {
        nextDelay(afterAttempt: attempt, kind: kind, elapsedDelay: elapsedDelay,
                  randomUnit: Double.random(in: 0..<1, using: &generator))
    }
}

// MARK: - 백그라운드 차단기

/// 백그라운드 단건 push가 죽은 서버(또는 만료된 세션·초과된 쿼터)에 계속 매달려
/// 배터리·데이터를 태우지 않게 막는 차단기. 순수 값 타입이라 시각을 주입해 결정적으로 테스트한다.
///
/// 차단 중 건너뛴 항목은 **로컬에 그대로 남아 있고**, SyncMerge가 id 기준 합집합이라
/// 다음 syncOnLogin()이 전부 원격으로 올린다 — 그래서 여기서 조용히 포기해도 데이터는 잃지 않는다.
nonisolated struct SyncCircuitBreaker: Sendable {
    /// 연속 실패가 이 횟수에 닿으면 차단한다.
    let failureThreshold: Int
    /// 차단 유지 시간. 지나면 half-open으로 한 번 더 시도해 본다.
    let cooldown: TimeInterval

    private(set) var consecutiveFailures: Int = 0
    private(set) var openUntil: Date?

    init(failureThreshold: Int = 3, cooldown: TimeInterval = 300) {
        self.failureThreshold = max(1, failureThreshold)
        self.cooldown = max(0, cooldown)
    }

    /// 지금 네트워크를 두드려도 되는가. 쿨다운이 지나면 다시 true(half-open).
    func allowsRequest(at now: Date) -> Bool {
        guard let openUntil else { return true }
        return now >= openUntil
    }

    mutating func recordSuccess() {
        consecutiveFailures = 0
        openUntil = nil
    }

    /// 명시적 사용자 액션(로그인 등)으로 차단을 푼다.
    mutating func reset() {
        recordSuccess()
    }

    mutating func recordFailure(_ kind: SyncFailureKind, at now: Date) {
        switch kind {
        case .cancelled:
            // 취소는 서버 상태에 대한 정보가 아니다.
            return
        case .auth, .quota:
            // 재시도가 무의미한 실패 → 한 번으로 즉시 차단.
            consecutiveFailures = failureThreshold
            openUntil = now.addingTimeInterval(cooldown)
        case .transient, .client, .unknown:
            consecutiveFailures += 1
            if consecutiveFailures >= failureThreshold {
                openUntil = now.addingTimeInterval(cooldown)
            }
        }
    }
}

// MARK: - 관찰 가능한 결과

/// 마지막 동기화 시도의 결과. SyncCoordinator가 @Observable 프로퍼티로 노출한다.
nonisolated struct SyncStatus: Equatable, Sendable {
    nonisolated enum Outcome: Equatable, Sendable {
        case success
        case failure(SyncFailureKind)
    }

    let outcome: Outcome
    /// 결과가 확정된 시각.
    let at: Date

    var isFailure: Bool { failureKind != nil }

    var failureKind: SyncFailureKind? {
        if case .failure(let kind) = outcome { return kind }
        return nil
    }

    /// 사용자에게 보여줄 문구(성공/취소는 nil).
    var userMessage: String? { failureKind?.userMessage }
}
