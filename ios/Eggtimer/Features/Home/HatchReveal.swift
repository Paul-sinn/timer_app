//
//  HatchReveal.swift
//  Eggtimer
//
//  부화 리빌 연출의 **순수 계산**(뷰 없음 — 유닛 테스트 대상).
//  영상(HatchBurst.mov)이 못 하는 세 가지를 코드로 얹는다:
//    1. 화면 전체를 채우는 섬광 — 영상은 가운데 240pt 네모 안에 갇혀 있다
//    2. 화면 흔들림 — 영상은 자기 사각형 안에서만 움직인다
//    3. 햅틱 — 영상은 손을 못 떨게 한다
//
//  모든 시각은 **영상 재생 시작 = 0초** 기준이며, 값은 영상 프레임을 실측해 맞췄다.
//  (프레임별 알파 bbox·밝기를 재서 껍질이 벌어지는 지점을 찾음 → 1.28초)
//  이 앵커가 틀어지면 손과 눈이 따로 논다 — HatchRevealTests가 고정한다.
//

import CoreGraphics
import Foundation

enum HatchReveal {

    // MARK: - 타임라인 (초, 영상 시작 기준)

    /// 껍질이 벌어지며 폭발이 시작되는 순간. 햅틱 "쾅" · 화면 흔들림 · 섬광이 전부 여기서 출발한다.
    static let impact: Double = 1.28
    /// 금빛 충전이 눈에 띄기 시작하는 지점. 약한 떨림을 여기서부터 깔아 긴장을 쌓는다.
    static let chargeStart: Double = 0.45

    /// 섬광 3단계 길이. 확장 → 유지 → 수축.
    /// 유지가 길면 화면이 하얗게 눌어붙어 눈이 아프고 그림이 다 사라진다 — 짧게 붙잡았다 바로 놓는다.
    static let flashExpand: Double = 0.38
    static let flashHold: Double = 0.14
    static let flashCollapse: Double = 0.55
    static var flashDuration: Double { flashExpand + flashHold + flashCollapse }

    /// 섬광이 완전히 꺼지는 시각.
    static var flashEnd: Double { impact + flashDuration }
    /// 캐릭터가 등장하는 시각. 빛이 아직 남아있을 때 나와야 "빛 속에서 나온다"로 읽힌다.
    static var creatureEntry: Double { impact + flashExpand + flashHold + flashCollapse * 0.45 }
    /// 화면 흔들림 길이(임팩트부터).
    static let shakeDuration: Double = 0.45

    /// 연출 전체 길이. 이 시간이 지나면 홈 화면은 평상 상태로 돌아간다.
    static var total: Double { flashEnd }

    // MARK: - 섬광 구간 경계 (0~1 정규화)

    /// 확장이 끝나는 진행도.
    static var expandFraction: Double { flashExpand / flashDuration }
    /// 유지가 끝나고 수축이 시작되는 진행도.
    static var holdEndFraction: Double { (flashExpand + flashHold) / flashDuration }

    /// 절대 시각(영상 기준)을 섬광 진행도 0~1로 바꾼다.
    static func flashProgress(atAbsolute seconds: Double) -> Double {
        clamp((seconds - impact) / flashDuration)
    }

    // MARK: - 섬광 곡선

    /// 섬광 반경 배율. 0 = 없음, 1 = 화면을 가득 채움.
    /// 확장은 빠르게 튀어나가고(easeOut) 수축은 천천히 빨려들어간다(easeIn) — 폭발의 관성.
    static func flashScale(_ progress: Double) -> Double {
        let p = clamp(progress)
        if p <= expandFraction {
            return easeOut(p / expandFraction)
        }
        if p <= holdEndFraction {
            return 1
        }
        let collapse = (p - holdEndFraction) / (1 - holdEndFraction)
        // 완전히 0까지 줄이지 않고 0.06까지만 — 마지막은 불투명도가 지운다.
        // 끝에서 급격히 점으로 수축하면 캐릭터 뒤에 점이 찍힌 것처럼 보인다.
        return 1 - easeIn(collapse) * 0.94
    }

    /// 섬광 불투명도. 확장 중 급히 차오르고, 유지 구간에서 최고, 수축하며 사라진다.
    /// - Parameter peak: 최고 불투명도. "동작 줄이기"에선 reducedMotionPeakOpacity를 넘긴다.
    static func flashOpacity(_ progress: Double, peak: Double = peakOpacity) -> Double {
        let p = clamp(progress)
        if p <= expandFraction {
            // 확장 초반에 이미 밝아야 "터졌다"로 읽힌다(반경보다 빛이 먼저 온다).
            return easeOut(p / expandFraction) * peak
        }
        if p <= holdEndFraction {
            return peak
        }
        let fade = (p - holdEndFraction) / (1 - holdEndFraction)
        return peak * (1 - easeIn(fade))
    }

    /// 섬광 최고 불투명도.
    /// 합성이 `.plusLighter`(빛을 **더한다**)라 체감이 곱절로 세다 — 0.9쯤 주면 화면이 통째로
    /// 백색으로 날아가 픽셀아트가 사라진다(시뮬레이터 실측: 1.4초간 완전 백색).
    /// 가운데만 하얗게 타고 바깥은 따뜻한 발광으로 남는 세기가 이 값이다.
    static let peakOpacity: Double = 0.72

    /// "동작 줄이기"가 켜졌을 때의 최고 불투명도. 화면 가득 번쩍이는 빛은 광과민성 유발 요인이라
    /// 연출을 없애는 대신 **은은한 발광**으로 낮춘다(연출의 의미는 남기고 자극만 줄인다).
    static let reducedMotionPeakOpacity: Double = 0.3

    // MARK: - 화면 흔들림

    /// 임팩트 순간의 화면 오프셋. 감쇠 사인 — 시작·끝 모두 0이라 화면이 어긋난 채 남지 않는다.
    /// x·y 주파수를 다르게 줘서 한 축으로만 흔들리는 기계적인 느낌을 피한다.
    static func shakeOffset(_ progress: Double, amplitude: CGFloat) -> CGSize {
        let p = clamp(progress)
        guard p > 0, p < 1 else { return .zero }
        // 진폭 포락선: 처음이 가장 세고 끝에서 0. (1-p)^2 로 빠르게 잦아든다.
        let envelope = pow(1 - p, 2)
        let x = sin(p * .pi * 2 * 3.5) * envelope
        let y = sin(p * .pi * 2 * 2.5 + 1.1) * envelope
        return CGSize(width: amplitude * CGFloat(x), height: amplitude * CGFloat(y) * 0.7)
    }

    // MARK: - 곡선 유틸

    private static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }
    private static func easeOut(_ t: Double) -> Double { 1 - pow(1 - clamp(t), 3) }
    private static func easeIn(_ t: Double) -> Double { pow(clamp(t), 2) }
}

// MARK: - 햅틱 패턴

/// 부화 햅틱의 **데이터 정의**. CoreHaptics 엔진과 분리해 두면 순서·세기를 테스트할 수 있다.
/// 설계: 충전 구간에 약한 떨림을 깔아 올리다가(긴장) 임팩트에 강한 한 방(해소).
enum HatchHapticPattern {

    struct Event: Equatable {
        /// 영상 시작 기준 시각(초).
        let time: Double
        /// 연속 진동(우우웅)인지 순간 타격(톡)인지.
        let isContinuous: Bool
        /// 세기 0~1.
        let intensity: Float
        /// 날카로움 0~1. 낮으면 뭉툭한 저음, 높으면 딱딱한 타격감.
        let sharpness: Float
        /// 연속 진동 길이(초). 순간 타격은 0.
        let duration: Double
    }

    /// 시간순 정렬 필수(CoreHaptics 요구). 테스트가 정렬·범위·최강점을 고정한다.
    static let events: [Event] = [
        // ── 충전: 약하게 깔리다 임팩트 직전까지 세진다 ──
        .init(time: HatchReveal.chargeStart, isContinuous: true,
              intensity: 0.18, sharpness: 0.15, duration: 0.45),
        .init(time: HatchReveal.chargeStart + 0.45, isContinuous: true,
              intensity: 0.42, sharpness: 0.25, duration: HatchReveal.impact - HatchReveal.chargeStart - 0.45),

        // ── 임팩트: 껍질이 깨지는 순간 ──
        .init(time: HatchReveal.impact, isContinuous: false,
              intensity: 1.0, sharpness: 0.85, duration: 0),
        // 여운으로 깔리는 저음 — 타격 뒤 "쿠우웅"
        .init(time: HatchReveal.impact, isContinuous: true,
              intensity: 0.55, sharpness: 0.1, duration: 0.5),
        // 파편이 튀는 두 번째 작은 타격
        .init(time: HatchReveal.impact + 0.09, isContinuous: false,
              intensity: 0.45, sharpness: 0.6, duration: 0),

        // ── 등장: 캐릭터가 나오는 순간 부드러운 한 번 ──
        .init(time: HatchReveal.creatureEntry, isContinuous: false,
              intensity: 0.6, sharpness: 0.35, duration: 0),
    ]
}
