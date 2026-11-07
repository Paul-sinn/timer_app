//
//  SnowfallView.swift
//  Eggtimer
//
//  눈 내리기 연출(그림 없이 코드로). 월드가 `hasSnowfall`이면 홈 배경 위·UI 아래에 깐다.
//  픽셀아트와 어울리게 네모 눈송이를 정수 좌표에 찍는다. 위치는 시각의 순수 함수라
//  프레임마다 상태를 들고 있지 않고(메모리·버그 ↓), 같은 시각이면 같은 자리라 테스트로 검증한다.
//  배터리: 집중 중 화면이 오래 켜져 있으므로 초당 20프레임으로 제한. 동작 줄이기면 멈춘 눈으로(연출은 남기고 움직임만 뺀다).
//

import SwiftUI

/// 눈송이 배치·이동 계산(순수 로직).
nonisolated enum Snowfall {
    struct Flake: Equatable {
        /// 가로 위치(화면 폭 비율 0…1).
        var x: Double
        /// 처음 세로 위치(화면 높이 비율 0…1).
        var y: Double
        /// 한 변 길이(pt). 정수라 픽셀처럼 보인다.
        var size: Double
        /// 떨어지는 속도(pt/초).
        var speed: Double
        /// 좌우 흔들림 위상(라디안).
        var phase: Double

        /// 작은 눈은 멀리 있는 것처럼 흐리게.
        var opacity: Double { 0.45 + 0.15 * (size - Snowfall.sizeRange.lowerBound) }
    }

    static let sizeRange: ClosedRange<Double> = 2...4
    static let speedRange: ClosedRange<Double> = 14...38
    /// 좌우 흔들림 최대 폭(pt).
    static let maxDrift: Double = 10
    /// 좌우 흔들림 빠르기(라디안/초).
    private static let driftFrequency: Double = 0.6

    /// 시드가 같으면 늘 같은 눈송이들(테스트·화면 재생성 시 튀지 않게).
    static func flakes(count: Int, seed: UInt64) -> [Flake] {
        var rng = SplitMix64(state: seed)
        let sizes = Array(stride(from: sizeRange.lowerBound, through: sizeRange.upperBound, by: 1))
        return (0..<count).map { _ in
            Flake(
                x: rng.unit(),
                y: rng.unit(),
                size: sizes[Int(rng.next() % UInt64(sizes.count))],
                speed: speedRange.lowerBound + rng.unit() * (speedRange.upperBound - speedRange.lowerBound),
                phase: rng.unit() * 2 * .pi
            )
        }
    }

    /// t초일 때 눈송이 왼쪽 위 좌표. 바닥을 지나면 위에서 다시 내려온다. 정수 좌표로 내린다.
    static func position(of f: Flake, at t: Double, in canvas: CGSize) -> CGPoint {
        let span = canvas.height + f.size
        let fallen = (f.y * span + f.speed * t).truncatingRemainder(dividingBy: span)
        let drift = maxDrift * (f.size / sizeRange.upperBound) * sin(t * driftFrequency + f.phase)
        return CGPoint(x: (f.x * canvas.width + drift).rounded(.down),
                       y: (fallen - f.size).rounded(.down))
    }

    /// 시드 고정 난수(SplitMix64).
    private struct SplitMix64 {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        /// 0…1 균등.
        mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    }
}

/// 화면 전체에 눈을 뿌린다. 터치·보이스오버에 끼어들지 않는다.
struct SnowfallView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let flakes = Snowfall.flakes(count: 70, seed: 2025)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { context in
            Canvas { gc, size in
                let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                for f in flakes {
                    let p = Snowfall.position(of: f, at: t, in: size)
                    gc.fill(Path(CGRect(x: p.x, y: p.y, width: f.size, height: f.size)),
                            with: .color(AppColor.snowflake.opacity(f.opacity)))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        AppColor.pageBackground.ignoresSafeArea()
        SnowfallView()
    }
}
