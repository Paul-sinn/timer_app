//
//  HatchRevealOverlay.swift
//  Eggtimer
//
//  부화 리빌의 화면 전체 연출(가챠 리빌 톤). 알이 깨지는 순간 빛이 알 자리에서 터져나와
//  화면을 가득 채우고, 잠깐 붙잡았다가, 수축하며 사그라들면서 캐릭터를 드러낸다.
//
//  영상(HatchBurst.mov)은 가운데 240pt 네모 안에서만 그려지므로 화면을 채울 수 없다.
//  그 바깥을 담당하는 게 이 뷰다. 곡선·타이밍은 전부 HatchReveal(순수 계산, 테스트됨)에서 온다.
//
//  합성은 `.plusLighter`(더하기) — 빛은 덮는 게 아니라 더해지는 것이라 아래 그림이 죽지 않는다.
//

import SwiftUI

/// 화면을 채우는 섬광 + 빛줄기. 부화 연출 동안만 올라오며 스스로 시계를 돌린다.
/// 영상과 같은 순간에 올라오므로 두 시계가 자동으로 맞는다.
struct HatchRevealOverlay: View {
    /// 빛이 터져나오는 지점(전역 좌표). 알이 있는 자리 — nil이면 화면 중앙.
    /// 알은 화면 정중앙이 아니라 위쪽에 있어서, 중앙에서 터뜨리면 빛과 알이 어긋난다.
    var origin: CGPoint?

    /// "동작 줄이기"가 켜져 있으면 번쩍임을 은은한 발광으로 낮춘다(광과민성 배려).
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 연출 시작 시각. onAppear에서 잡는다(= 영상 재생 시작).
    @State private var start: Date?

    private var peakOpacity: Double {
        reduceMotion ? HatchReveal.reducedMotionPeakOpacity : HatchReveal.peakOpacity
    }

    var body: some View {
        GeometryReader { geometry in
            // 화면 어느 구석까지도 덮어야 한다. 발광 지점이 중앙에서 벗어날수록 더 멀리 가야 하므로
            // 네 모서리까지의 거리 중 최댓값을 반경으로 쓴다.
            let center = origin ?? CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let coverRadius = Self.radiusCovering(size: geometry.size, from: center)

            TimelineView(.animation) { timeline in
                let progress = flashProgress(now: timeline.date)
                let scale = HatchReveal.flashScale(progress)
                let opacity = HatchReveal.flashOpacity(progress, peak: peakOpacity)

                ZStack {
                    rays(radius: coverRadius)
                        // 빛줄기는 코어보다 조금 크게 뻗고 천천히 돈다(살아있는 느낌).
                        .scaleEffect(scale * 1.15)
                        .rotationEffect(.degrees(progress * 22))
                        .opacity(opacity * 0.7)

                    core(radius: coverRadius)
                        .scaleEffect(scale)
                        .opacity(opacity)
                }
                .position(center)
            }
        }
        .ignoresSafeArea()
        .blendMode(.plusLighter)   // 빛은 더해진다(아래 픽셀아트를 덮어 지우지 않게)
        .allowsHitTesting(false)
        .onAppear { start = Date() }
    }

    /// 주어진 점에서 사각형의 가장 먼 모서리까지의 거리. 이만큼이면 화면 전체가 덮인다.
    static func radiusCovering(size: CGSize, from point: CGPoint) -> CGFloat {
        let corners = [
            CGPoint(x: 0, y: 0), CGPoint(x: size.width, y: 0),
            CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height),
        ]
        return corners.map { hypot($0.x - point.x, $0.y - point.y) }.max() ?? 0
    }

    /// 가운데 흰 코어 → 앰버 → 투명. 화면을 채우는 본체.
    /// 낙차를 급하게 준 이유: `.plusLighter`로 더해지므로 완만하게 깔면 화면 전체가 백색으로 탄다.
    /// 흰 코어는 알 크기 정도로만 좁게 두고, 나머지는 따뜻한 발광이 구석까지 닿게 한다.
    private func core(radius: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: AppColor.hatchFlashCore, location: 0),
                        .init(color: AppColor.hatchFlashCore.opacity(0.70), location: 0.10),
                        .init(color: AppColor.hatchFlashEdge.opacity(0.55), location: 0.30),
                        .init(color: AppColor.hatchFlashEdge.opacity(0.32), location: 0.60),
                        .init(color: AppColor.hatchFlashEdge.opacity(0.14), location: 0.85),
                        .init(color: AppColor.hatchFlashEdge.opacity(0), location: 1),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: radius
                )
            )
            .frame(width: radius * 2, height: radius * 2)
    }

    private func rays(radius: CGFloat) -> some View {
        RaysShape()
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: AppColor.hatchFlashCore.opacity(0.75), location: 0),
                        .init(color: AppColor.hatchFlashEdge.opacity(0.35), location: 0.5),
                        .init(color: AppColor.hatchFlashEdge.opacity(0), location: 1),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: radius
                )
            )
            .frame(width: radius * 2, height: radius * 2)
    }

    /// 시작 시각 기준 경과 → 섬광 진행도. 아직 시작 전이면 0(아무것도 안 그림).
    private func flashProgress(now: Date) -> Double {
        guard let start else { return 0 }
        return HatchReveal.flashProgress(atAbsolute: now.timeIntervalSince(start))
    }
}

/// 중심에서 뻗는 빛줄기 다발. 길이를 번갈아 다르게 해 규칙적인 바퀴살처럼 안 보이게 한다.
private struct RaysShape: Shape {
    var count: Int = 14
    /// 광선 하나의 반각(전체 원 대비 비율).
    var halfWidth: Double = 0.012

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = min(rect.width, rect.height) / 2
        var path = Path()

        for index in 0..<count {
            let angle = Double(index) / Double(count)
            // 긴 광선과 짧은 광선을 번갈아 — 실제 섬광의 불규칙함.
            let length = maxRadius * (index.isMultiple(of: 2) ? 1.0 : 0.62)
            let inner = maxRadius * 0.04

            let a0 = (angle - halfWidth) * 2 * .pi
            let a1 = (angle + halfWidth) * 2 * .pi
            let tip = angle * 2 * .pi

            path.move(to: point(center, radius: inner, angle: a0))
            path.addLine(to: point(center, radius: length, angle: tip))
            path.addLine(to: point(center, radius: inner, angle: a1))
            path.closeSubpath()
        }
        return path
    }

    private func point(_ center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        CGPoint(x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle)))
    }
}

/// 임팩트 순간 화면을 짧게 흔든다.
/// `Animatable`이라 SwiftUI가 프레임마다 오프셋만 다시 계산한다 — 화면 본문은 다시 그리지 않는다.
/// (TimelineView로 하면 홈 화면 전체가 60fps로 재평가돼 비싸다.)
struct ScreenShakeModifier: ViewModifier, Animatable {
    var progress: Double
    var amplitude: CGFloat = 8

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.offset(HatchReveal.shakeOffset(progress, amplitude: amplitude))
    }
}

extension View {
    /// 부화 임팩트 화면 흔들림. `progress`를 0 → 1로 애니메이션하면 한 번 흔들리고 제자리로 돌아온다.
    func screenShake(progress: Double, amplitude: CGFloat = 8) -> some View {
        modifier(ScreenShakeModifier(progress: progress, amplitude: amplitude))
    }

    /// 이 뷰의 화면상 중심을 부화 섬광의 발광 지점으로 보고한다(알 자리에 붙인다).
    func reportsHatchRevealOrigin() -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: HatchRevealOriginKey.self,
                    value: CGPoint(x: proxy.frame(in: .global).midX,
                                   y: proxy.frame(in: .global).midY)
                )
            }
        }
    }
}

/// 알(=빛이 터져나올 자리)의 화면 좌표를 상위 뷰로 올린다.
/// 알은 화면 정중앙이 아니라 위쪽에 있어서, 이걸 안 넘기면 빛이 엉뚱한 데서 터진다.
struct HatchRevealOriginKey: PreferenceKey {
    static let defaultValue: CGPoint? = nil
    static func reduce(value: inout CGPoint?, nextValue: () -> CGPoint?) {
        value = nextValue() ?? value
    }
}

#Preview {
    ZStack {
        AppColor.pageBackground.ignoresSafeArea()
        EggView(stageIndex: 5, height: 240)
        HatchRevealOverlay()
    }
    .preferredColorScheme(.dark)
}
