//
//  SyncRetryPolicyTests.swift
//  EggtimerTests
//
//  Supabase 동기화 오류 처리·재시도 정책의 순수 로직 검증(Phase 3-4):
//  에러 분류(재시도 가능/불가) · 지수 백오프 + 지터 · 시도/대기 상한 · 백그라운드 차단기.
//
//  SyncCoordinator 자체는 테스트하지 않는다 — AuthService/CollectionStore/FocusHistoryStore를 물고 있고,
//  SwiftData 컨테이너+fetch는 Swift Testing 컨텍스트에서 SIGTRAP(프로젝트 실패 로그 참조).
//  그래서 재시도 판단에 필요한 모든 결정을 순수 값 타입으로 뽑아내고 그것만 검증한다.
//

import Testing
import Foundation
@testable import Eggtimer

// MARK: - 테스트 더블

/// 결정적 지터 테스트용 시드 난수원(SplitMix64). 같은 시드 → 항상 같은 수열.
/// 이웃한 시드(1, 2, 3…)도 서로 무관한 값을 내도록 avalanche가 강한 알고리즘을 쓴다 —
/// xorshift처럼 작은 시드에서 상위 비트가 비는 생성기는 "지터가 퍼지는가" 검증을 무의미하게 만든다.
private nonisolated struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// 분류기에 어떤 단서도 주지 못하는 에러(알 수 없는 실패 경로).
private nonisolated struct OpaqueError: Error {}

// MARK: -

struct SyncRetryPolicyTests {

    /// 테스트에서 쓰는 기준 정책. 숫자를 눈으로 따라갈 수 있게 단순한 값으로 고정한다.
    private let policy = SyncRetryPolicy(maxAttempts: 4,
                                         baseDelay: 1,
                                         multiplier: 2,
                                         maxDelay: 8,
                                         totalDelayBudget: 20,
                                         jitterFraction: 1)

    // MARK: - 재시도 가능 여부

    @Test func onlyTransientFailuresAreRetryable() {
        #expect(SyncFailureKind.transient.isRetryable)
        for kind in SyncFailureKind.allCases where kind != .transient {
            #expect(!kind.isRetryable, "\(kind.rawValue)는 재시도하면 안 된다")
        }
    }

    @Test func everyRealFailureHasAUserMessageButCancellationDoesNot() {
        // 취소는 사용자에게 보여줄 실패가 아니다.
        #expect(SyncFailureKind.cancelled.userMessage == nil)
        for kind in SyncFailureKind.allCases where kind != .cancelled {
            let message = kind.userMessage
            #expect(message?.isEmpty == false, "\(kind.rawValue)에 안내 문구가 없다")
        }
    }

    // MARK: - 에러 분류: HTTP 상태 코드

    @Test func transientHTTPStatusesAreRetried() {
        for status in [408, 425, 429, 500, 502, 503, 504, 522] {
            let kind = SyncFailureClassifier.kind(for: SyncFailureSignal(httpStatus: status))
            #expect(kind == .transient, "HTTP \(status)는 전송성 실패다")
            #expect(kind.isRetryable)
        }
    }

    @Test func authHTTPStatusesAreNotRetried() {
        for status in [401, 403] {
            let kind = SyncFailureClassifier.kind(for: SyncFailureSignal(httpStatus: status))
            #expect(kind == .auth, "HTTP \(status)는 인증 실패다")
            #expect(!kind.isRetryable)
        }
    }

    @Test func otherClientHTTPStatusesAreNotRetried() {
        for status in [400, 404, 409, 415, 422] {
            let kind = SyncFailureClassifier.kind(for: SyncFailureSignal(httpStatus: status))
            #expect(kind == .client, "HTTP \(status)는 클라이언트 오류다")
            #expect(!kind.isRetryable)
        }
    }

    // MARK: - 에러 분류: Postgres / PostgREST 코드

    @Test func transientPostgresClassesAreRetried() {
        // 08=connection_exception, 40=transaction_rollback, 53=insufficient_resources,
        // 57=operator_intervention, 58=system_error — 전부 다시 보내면 통할 수 있는 실패.
        for code in ["08000", "08006", "40001", "40P01", "53300", "57014", "57P03", "58030"] {
            let kind = SyncFailureClassifier.kind(for: SyncFailureSignal(postgresCode: code))
            #expect(kind == .transient, "SQLSTATE \(code)는 전송성 실패다")
        }
    }

    @Test func postgrestInfrastructureCodesAreRetried() {
        for code in ["PGRST000", "PGRST001", "PGRST002", "PGRST003"] {
            #expect(SyncFailureClassifier.kind(for: SyncFailureSignal(postgresCode: code)) == .transient)
        }
    }

    @Test func writeQuotaCodesAreNeverRetried() {
        // B5 마이그레이션의 유저별 쓰기 쿼터 거부. 몇 번을 더 보내도 하루가 지나기 전엔 같은 답이 온다.
        for code in SyncFailureClassifier.quotaPostgresCodes {
            let kind = SyncFailureClassifier.kind(for: SyncFailureSignal(postgresCode: code))
            #expect(kind == .quota, "SQLSTATE \(code)는 쿼터 초과다")
            #expect(!kind.isRetryable)
        }
        #expect(SyncFailureClassifier.quotaPostgresCodes.contains("PT429"))
    }

    /// 이 프로젝트에서 가장 위험한 오분류: B5 쿼터 거부(PT429)는 **HTTP 429**로 내려온다.
    /// 상태 코드만 보고 판단하면 "잠깐 뒤 재시도"로 오해해서 영구 실패를 계속 두드리게 된다.
    @Test func writeQuotaRejectionIsNotMistakenForAGatewayRateLimit() {
        // 서버가 실제로 보내는 모양: HTTP 429 + 바디 {code: PT429, hint: hatcho_write_quota_exceeded}
        let quota = SyncFailureSignal(httpStatus: 429,
                                      postgresCode: "PT429",
                                      postgresHint: "hatcho_write_quota_exceeded")
        #expect(SyncFailureClassifier.kind(for: quota) == .quota)
        #expect(!SyncFailureClassifier.kind(for: quota).isRetryable)

        // code만 있어도, hint만 있어도 알아봐야 한다.
        #expect(SyncFailureClassifier.kind(for: SyncFailureSignal(postgresCode: "PT429")) == .quota)
        #expect(SyncFailureClassifier.kind(for: SyncFailureSignal(httpStatus: 429,
                                                                  postgresHint: "hatcho_write_quota_exceeded")) == .quota)

        // 반대로, 바디 단서가 전혀 없는 진짜 게이트웨이 rate limit은 재시도 대상이다.
        #expect(SyncFailureClassifier.kind(for: SyncFailureSignal(httpStatus: 429)) == .transient)
    }

    @Test func postgRESTStatusCodesMapThroughTheirHTTPStatus() {
        // PostgREST 규약: SQLSTATE 'PT<3자리>' → 그 HTTP 상태. B4의 미래 timestamp 거부가 PT400이다.
        #expect(SyncFailureClassifier.kind(for: SyncFailureSignal(postgresCode: "PT400")) == .client)
        #expect(SyncFailureClassifier.kind(for: SyncFailureSignal(postgresCode: "PT401")) == .auth)
        #expect(SyncFailureClassifier.kind(for: SyncFailureSignal(postgresCode: "PT503")) == .transient)
    }

    @Test func quotaCodesAreNotSwallowedByTheirSQLSTATEClass() {
        // 53400은 class 53(전송성)에 속하지만 쿼터 판정이 먼저다 — 순서가 뒤집히면 무한 재시도가 된다.
        #expect(SyncFailureClassifier.quotaPostgresCodes.contains("53400"))
        #expect(SyncFailureClassifier.kind(for: SyncFailureSignal(postgresCode: "53400")) == .quota)
        #expect(SyncFailureClassifier.kind(for: SyncFailureSignal(postgresCode: "53300")) == .transient)
    }

    @Test func permissionAndJWTCodesAreAuthFailures() {
        for code in ["42501", "PGRST301", "PGRST302"] {
            let kind = SyncFailureClassifier.kind(for: SyncFailureSignal(postgresCode: code))
            #expect(kind == .auth, "\(code)는 인증/권한 실패다")
            #expect(!kind.isRetryable)
        }
    }

    @Test func unrecognizedPostgresCodesAreNotRetried() {
        // 제약 위반·스키마 불일치 등: 우리 쪽 버그. 재시도는 서버만 괴롭힌다.
        for code in ["23505", "23514", "22P02", "PGRST116", "PGRST204"] {
            let kind = SyncFailureClassifier.kind(for: SyncFailureSignal(postgresCode: code))
            #expect(!kind.isRetryable, "\(code)를 재시도하면 안 된다")
        }
    }

    // MARK: - 에러 분류: URL 오류 / 취소 / 알 수 없음

    @Test func networkURLErrorsAreRetried() {
        let codes: [URLError.Code] = [.notConnectedToInternet, .networkConnectionLost, .timedOut,
                                      .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
                                      .dataNotAllowed, .internationalRoamingOff]
        for code in codes {
            let kind = SyncFailureClassifier.kind(for: SyncFailureSignal(urlErrorCode: code.rawValue))
            #expect(kind == .transient, "URLError \(code.rawValue)는 전송성 실패다")
        }
    }

    @Test func cancellationBeatsEveryOtherSignal() {
        let signal = SyncFailureSignal(httpStatus: 503, postgresCode: "08006",
                                       urlErrorCode: URLError.Code.timedOut.rawValue,
                                       isCancelled: true)
        #expect(SyncFailureClassifier.kind(for: signal) == .cancelled)
        #expect(!SyncFailureKind.cancelled.isRetryable)
    }

    @Test func decodingFailureIsAClientBug() {
        let kind = SyncFailureClassifier.kind(for: SyncFailureSignal(isDecodingFailure: true))
        #expect(kind == .client)
        #expect(!kind.isRetryable)
    }

    @Test func signalWithoutAnyClueIsUnknownAndNotRetried() {
        let kind = SyncFailureClassifier.kind(for: SyncFailureSignal())
        #expect(kind == .unknown)
        #expect(!kind.isRetryable, "정체를 모르는 실패는 보수적으로 재시도하지 않는다")
    }

    // MARK: - 실제 Error → 분류

    @Test func mapsURLErrorToTransient() {
        #expect(SyncErrorMapper.kind(for: URLError(.notConnectedToInternet)) == .transient)
        #expect(SyncErrorMapper.kind(for: URLError(.timedOut)) == .transient)
    }

    @Test func mapsCancellationToCancelled() {
        #expect(SyncErrorMapper.kind(for: CancellationError()) == .cancelled)
        #expect(SyncErrorMapper.kind(for: URLError(.cancelled)) == .cancelled)
    }

    @Test func mapsBridgedNSURLErrorToTransient() {
        let bridged = NSError(domain: NSURLErrorDomain, code: URLError.Code.networkConnectionLost.rawValue)
        #expect(SyncErrorMapper.kind(for: bridged) == .transient)
    }

    @Test func mapsUnrecognizedErrorToUnknownWithoutRetrying() {
        let kind = SyncErrorMapper.kind(for: OpaqueError())
        #expect(kind == .unknown)
        #expect(!kind.isRetryable)
    }

    // MARK: - 지수 백오프

    @Test func delayCapGrowsExponentiallyThenClamps() {
        #expect(policy.delayCap(forRetry: 1) == 1)   // base
        #expect(policy.delayCap(forRetry: 2) == 2)
        #expect(policy.delayCap(forRetry: 3) == 4)
        #expect(policy.delayCap(forRetry: 4) == 8)   // maxDelay 도달
        #expect(policy.delayCap(forRetry: 5) == 8)   // 그 위로는 안 자란다
        #expect(policy.delayCap(forRetry: 99) == 8)
    }

    @Test func fullJitterSpansZeroToCap() {
        #expect(policy.delay(forRetry: 3, randomUnit: 0) == 0)
        #expect(policy.delay(forRetry: 3, randomUnit: 1) == 4)
        #expect(abs(policy.delay(forRetry: 3, randomUnit: 0.5) - 2) < 0.000_001)
    }

    @Test func delayAlwaysLandsInsideTheDeclaredRange() {
        for retry in 1...6 {
            let range = policy.delayRange(forRetry: retry)
            for unit in stride(from: 0.0, through: 1.0, by: 0.1) {
                let d = policy.delay(forRetry: retry, randomUnit: unit)
                #expect(range.contains(d), "retry \(retry), unit \(unit) → \(d)가 \(range) 밖")
            }
        }
    }

    @Test func randomUnitIsClampedSoOutOfRangeInputCannotExceedTheCap() {
        #expect(policy.delay(forRetry: 2, randomUnit: 5) == policy.delayCap(forRetry: 2))
        #expect(policy.delay(forRetry: 2, randomUnit: -3) == 0)
    }

    @Test func zeroJitterFractionCollapsesToThePlainExponentialCap() {
        // 지터는 끌 수 있는 노브지만, 프리셋은 전부 켜져 있어야 한다(아래 preset 테스트).
        let noJitter = SyncRetryPolicy(maxAttempts: 3, baseDelay: 1, multiplier: 2,
                                       maxDelay: 8, totalDelayBudget: 20, jitterFraction: 0)
        #expect(noJitter.delay(forRetry: 2, randomUnit: 0) == 2)
        #expect(noJitter.delay(forRetry: 2, randomUnit: 1) == 2)
    }

    // MARK: - 지터 난수원 주입(결정적)

    @Test func seededGeneratorMakesJitterReproducible() {
        var a = SeededGenerator(seed: 42)
        var b = SeededGenerator(seed: 42)
        var first: [TimeInterval] = []
        var second: [TimeInterval] = []
        for retry in 1...5 { first.append(policy.delay(forRetry: retry, using: &a)) }
        for retry in 1...5 { second.append(policy.delay(forRetry: retry, using: &b)) }
        #expect(first == second)
    }

    @Test func jitterSpreadsClientsSoTheyDoNotStampedeTogether() {
        // 같은 순간 같은 실패를 겪은 클라이언트 200대가 서로 다른 시각에 재시도해야 한다.
        var delays: Set<Double> = []
        for seed in 1...200 {
            var generator = SeededGenerator(seed: UInt64(seed))
            delays.insert(policy.delay(forRetry: 2, using: &generator))
        }
        let range = policy.delayRange(forRetry: 2)
        #expect(delays.count > 150, "지터가 사실상 없다 — 서로 다른 대기값이 \(delays.count)개뿐")
        #expect(delays.allSatisfy { range.contains($0) })
        // 창의 앞쪽과 뒤쪽 모두 사용해야 진짜로 퍼진 것.
        let mid = (range.lowerBound + range.upperBound) / 2
        #expect(delays.contains { $0 < mid } && delays.contains { $0 > mid })
    }

    // MARK: - 상한(시도 횟수 / 총 대기)

    @Test func nonRetryableKindsNeverGetADelay() {
        for kind in SyncFailureKind.allCases where kind != .transient {
            let delay = policy.nextDelay(afterAttempt: 1, kind: kind, elapsedDelay: 0, randomUnit: 0.5)
            #expect(delay == nil, "\(kind.rawValue)에 재시도 대기를 주면 안 된다")
        }
    }

    @Test func stopsRetryingAtMaxAttempts() {
        for attempt in 1..<policy.maxAttempts {
            #expect(policy.nextDelay(afterAttempt: attempt, kind: .transient,
                                     elapsedDelay: 0, randomUnit: 0.5) != nil)
        }
        #expect(policy.nextDelay(afterAttempt: policy.maxAttempts, kind: .transient,
                                 elapsedDelay: 0, randomUnit: 0.5) == nil)
        #expect(policy.nextDelay(afterAttempt: policy.maxAttempts + 5, kind: .transient,
                                 elapsedDelay: 0, randomUnit: 0.5) == nil)
    }

    @Test func singleAttemptPolicyNeverRetries() {
        let once = SyncRetryPolicy(maxAttempts: 1, baseDelay: 1, multiplier: 2,
                                   maxDelay: 8, totalDelayBudget: 20, jitterFraction: 1)
        #expect(once.nextDelay(afterAttempt: 1, kind: .transient, elapsedDelay: 0, randomUnit: 0.5) == nil)
    }

    @Test func returnsNilOnceTheTotalDelayBudgetIsSpent() {
        #expect(policy.nextDelay(afterAttempt: 1, kind: .transient,
                                 elapsedDelay: policy.totalDelayBudget, randomUnit: 1) == nil)
        #expect(policy.nextDelay(afterAttempt: 1, kind: .transient,
                                 elapsedDelay: policy.totalDelayBudget + 1, randomUnit: 1) == nil)
    }

    @Test func clampsTheLastDelayToWhateverBudgetRemains() {
        let remaining = 0.25
        let delay = policy.nextDelay(afterAttempt: 3, kind: .transient,
                                     elapsedDelay: policy.totalDelayBudget - remaining,
                                     randomUnit: 1)
        #expect(delay == remaining)
    }

    @Test func aFullRetryLoopStaysInsideBothCaps() {
        // 최악값(randomUnit = 1)으로 루프를 끝까지 돌려도 시도 횟수·누적 대기가 상한을 넘지 않아야 한다.
        let tight = SyncRetryPolicy(maxAttempts: 5, baseDelay: 2, multiplier: 3,
                                    maxDelay: 30, totalDelayBudget: 10, jitterFraction: 1)
        var attempt = 0
        var elapsed: TimeInterval = 0
        var waits: [TimeInterval] = []
        while let delay = tight.nextDelay(afterAttempt: attempt + 1, kind: .transient,
                                          elapsedDelay: elapsed, randomUnit: 1) {
            attempt += 1
            elapsed += delay
            waits.append(delay)
            #expect(attempt <= tight.maxAttempts, "무한 루프")
        }
        #expect(attempt + 1 <= tight.maxAttempts)
        #expect(elapsed <= tight.totalDelayBudget + 0.000_001)
        #expect(waits.allSatisfy { $0 >= 0 })
    }

    // MARK: - 프리셋

    @Test func everyPresetIsBoundedAndJittered() {
        let presets: [(String, SyncRetryPolicy)] = [
            ("loginPull", .loginPull), ("loginPush", .loginPush), ("backgroundPush", .backgroundPush)
        ]
        for (name, preset) in presets {
            #expect(preset.maxAttempts >= 1 && preset.maxAttempts <= 3, "\(name) 시도 횟수 과다")
            #expect(preset.jitterFraction > 0, "\(name)에 지터가 없다")
            #expect(preset.totalDelayBudget <= 30, "\(name) 총 대기 상한 과다")
            // 지터 없는 최악 누적 대기가 예산 안에 들어야 예산이 사후 안전망으로만 작동한다.
            let worstCase = (1..<preset.maxAttempts).reduce(0.0) { $0 + preset.delayCap(forRetry: $1) }
            #expect(worstCase <= preset.totalDelayBudget, "\(name) 최악 누적 대기 \(worstCase) > 예산")
        }
    }

    @Test func loginPullRetriesLessThanPushBecauseTheSDKAlreadyRetriesGETs() {
        // supabase-swift PostgrestBuilder는 GET/HEAD만 503/520·네트워크 오류에 3회 자체 재시도한다.
        // pull에 우리 재시도를 곱하면 왕복이 폭증하므로 pull 쪽을 더 짧게 잡는다.
        #expect(SyncRetryPolicy.loginPull.maxAttempts <= SyncRetryPolicy.loginPush.maxAttempts)
    }

    // MARK: - 백그라운드 차단기

    private var now: Date { Date(timeIntervalSince1970: 1_700_000_000) }

    @Test func breakerStartsClosed() {
        let breaker = SyncCircuitBreaker(failureThreshold: 3, cooldown: 300)
        #expect(breaker.allowsRequest(at: now))
    }

    @Test func breakerOpensOnlyAfterRepeatedTransientFailures() {
        var breaker = SyncCircuitBreaker(failureThreshold: 3, cooldown: 300)
        breaker.recordFailure(.transient, at: now)
        #expect(breaker.allowsRequest(at: now))
        breaker.recordFailure(.transient, at: now)
        #expect(breaker.allowsRequest(at: now))
        breaker.recordFailure(.transient, at: now)
        #expect(!breaker.allowsRequest(at: now), "연속 3회 실패 후엔 백그라운드 push를 멈춰야 한다")
    }

    @Test func successResetsTheFailureRun() {
        var breaker = SyncCircuitBreaker(failureThreshold: 3, cooldown: 300)
        breaker.recordFailure(.transient, at: now)
        breaker.recordFailure(.transient, at: now)
        breaker.recordSuccess()
        breaker.recordFailure(.transient, at: now)
        #expect(breaker.allowsRequest(at: now), "성공이 끼면 연속 카운트가 초기화돼야 한다")
    }

    @Test func hopelessFailuresOpenTheBreakerImmediately() {
        for kind in [SyncFailureKind.auth, .quota] {
            var breaker = SyncCircuitBreaker(failureThreshold: 3, cooldown: 300)
            breaker.recordFailure(kind, at: now)
            #expect(!breaker.allowsRequest(at: now), "\(kind.rawValue)는 한 번으로 즉시 차단해야 한다")
        }
    }

    @Test func cancellationIsNotAFailure() {
        var breaker = SyncCircuitBreaker(failureThreshold: 1, cooldown: 300)
        breaker.recordFailure(.cancelled, at: now)
        #expect(breaker.allowsRequest(at: now))
    }

    @Test func breakerClosesAfterCooldownAndReopensIfItFailsAgain() {
        var breaker = SyncCircuitBreaker(failureThreshold: 1, cooldown: 300)
        breaker.recordFailure(.transient, at: now)
        #expect(!breaker.allowsRequest(at: now.addingTimeInterval(299)))
        // half-open: 쿨다운이 지나면 한 번 더 시도해 본다.
        #expect(breaker.allowsRequest(at: now.addingTimeInterval(300)))
        // 그 시도가 또 실패하면 다시 닫힌다.
        breaker.recordFailure(.transient, at: now.addingTimeInterval(300))
        #expect(!breaker.allowsRequest(at: now.addingTimeInterval(301)))
    }

    @Test func resetClosesTheBreakerForAnExplicitUserAction() {
        var breaker = SyncCircuitBreaker(failureThreshold: 1, cooldown: 300)
        breaker.recordFailure(.quota, at: now)
        #expect(!breaker.allowsRequest(at: now))
        breaker.reset()
        #expect(breaker.allowsRequest(at: now), "로그인 같은 명시적 액션은 차단을 풀어야 한다")
    }

    // MARK: - 관찰 상태

    @Test func syncStatusExposesOutcomeAndMessage() {
        let ok = SyncStatus(outcome: .success, at: now)
        #expect(!ok.isFailure)
        #expect(ok.failureKind == nil)
        #expect(ok.userMessage == nil)

        let bad = SyncStatus(outcome: .failure(.transient), at: now)
        #expect(bad.isFailure)
        #expect(bad.failureKind == .transient)
        #expect(bad.userMessage == SyncFailureKind.transient.userMessage)
        #expect(bad.at == now)
    }
}
