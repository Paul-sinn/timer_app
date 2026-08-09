//
//  SyncErrorMapper.swift
//  Eggtimer
//
//  supabase-swift가 던지는 실제 에러 → SyncFailureSignal(순수 단서) 변환.
//  SDK 의존은 이 파일 하나에 가둔다 — 분류 규칙 자체(SyncFailureClassifier)는 SDK 없이 테스트된다.
//
//  supabase-swift 2.47.0 PostgrestBuilder.execute()가 던질 수 있는 것(소스 확인):
//   - PostgrestError  : 비 2xx 응답 바디가 {"message": …}로 디코딩될 때. code = SQLSTATE 또는 PGRSTxxx.
//                       ⚠️ HTTP 상태 코드를 담고 있지 않다.
//   - HTTPError       : 비 2xx인데 바디가 PostgrestError로 디코딩되지 않을 때. response.statusCode 보유.
//   - URLError        : URLSession 전송 실패(오프라인/타임아웃/DNS…).
//   - DecodingError   : 2xx인데 응답을 우리 모델로 못 읽을 때.
//   - CancellationError: Task 취소.
//

import Foundation
import Supabase

nonisolated enum SyncErrorMapper {

    /// 에러에서 분류 단서를 뽑는다. 알아볼 수 없으면 빈 단서(→ .unknown → 재시도 안 함).
    static func signal(for error: any Error) -> SyncFailureSignal {
        if error is CancellationError {
            return SyncFailureSignal(isCancelled: true)
        }
        if let urlError = error as? URLError {
            if urlError.code == .cancelled { return SyncFailureSignal(isCancelled: true) }
            return SyncFailureSignal(urlErrorCode: urlError.code.rawValue)
        }
        if let httpError = error as? HTTPError {
            return SyncFailureSignal(httpStatus: httpError.response.statusCode)
        }
        if let postgrestError = error as? PostgrestError {
            // code가 nil인 응답(예: 게이트웨이가 만든 {"message": "..."} 형태의 429/503)은
            // 상태 코드가 사라진 상태라 정체를 알 수 없다 → .unknown → 재시도하지 않는다(보수적).
            // hint는 B5 쓰기 쿼터('hatcho_write_quota_exceeded') 판별용 2차 단서.
            return SyncFailureSignal(postgresCode: postgrestError.code,
                                     postgresHint: postgrestError.hint)
        }
        if error is DecodingError {
            return SyncFailureSignal(isDecodingFailure: true)
        }
        // URLError로 캐스팅되지 않고 NSError로 브리지된 네트워크 오류(백그라운드 세션 등).
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return SyncFailureSignal(urlErrorCode: nsError.code)
        }
        return SyncFailureSignal()
    }

    /// 에러 → 실패 종류(재시도 판단의 입력).
    static func kind(for error: any Error) -> SyncFailureKind {
        SyncFailureClassifier.kind(for: signal(for: error))
    }
}
