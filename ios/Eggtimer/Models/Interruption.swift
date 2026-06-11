//
//  Interruption.swift
//  Eggtimer
//
//  집중 세션 중 앱 이탈(백그라운드) 시간 분류(Feature 6). 순수 로직.
//  0–30초: 무시(잠금화면/알림센터), 30초–3분: minor, 3–10분: interruption, 10분+: distracted.
//

import Foundation

enum InterruptionSeverity {
    case ignored        // 0–30초: 집중 흐름으로 간주(무시)
    case minor          // 30초–3분
    case interruption   // 3–10분
    case distracted     // 10분+

    /// minor 이상(통계에 집계되는 실질 이탈).
    var counts: Bool { self != .ignored }
}

enum Interruption {
    static func severity(awaySeconds: Int) -> InterruptionSeverity {
        switch awaySeconds {
        case ..<30:  return .ignored
        case ..<180: return .minor
        case ..<600: return .interruption
        default:     return .distracted
        }
    }
}
