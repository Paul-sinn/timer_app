//
//  AppleSignInNonce.swift
//  Eggtimer
//
//  Sign in with Apple용 nonce 유틸(Phase 3). 재전송 공격 방지를 위해
//  Apple 요청에는 SHA256 해시 nonce를, Supabase 검증에는 원본(raw) nonce를 넘긴다.
//  CryptoKit만 사용(네이티브, 추가 의존성 없음).
//

import Foundation
import CryptoKit

enum AppleSignInNonce {
    /// 암호학적으로 안전한 랜덤 nonce 문자열(영숫자, 기본 32자).
    static func random(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            _ = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            for random in randoms where remaining > 0 {
                if random < UInt8(charset.count) {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    /// SHA256(nonce)를 16진 문자열로 — Apple 요청에 실어 보낼 값.
    static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}
