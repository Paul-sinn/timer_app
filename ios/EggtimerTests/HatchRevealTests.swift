//
//  HatchRevealTests.swift
//  EggtimerTests
//
//  부화 리빌 연출의 타이밍·곡선 검증. 연출은 눈으로 봐야 아는 부분이 많지만,
//  "언제 무엇이 일어나는가"와 "곡선이 0에서 시작해 0으로 끝나는가"는 순수 계산이라
//  여기서 잡는다. 곡선이 끝에서 0으로 안 떨어지면 섬광이 화면에 눌어붙는다.
//

import CoreGraphics
import Foundation
import Testing
@testable import Eggtimer

struct HatchRevealTests {

    // MARK: - 타임라인 순서

    @Test func timelineIsOrderedAndAnchoredToTheVideo() {
        // 임팩트는 영상에서 껍질이 깨지는 1.28초에 맞춘다(프레임 실측).
        // 이 값이 흔들리면 햅틱·흔들림·섬광이 그림과 따로 논다.
        #expect(HatchReveal.impact == 1.28)
        #expect(HatchReveal.impact < HatchReveal.creatureEntry)
        #expect(HatchReveal.creatureEntry < HatchReveal.flashEnd)
        // 임팩트는 영상 길이 안에서 일어나야 한다(영상이 끝난 뒤 터지면 안 됨).
        #expect(HatchReveal.impact < HatchBurstAsset.duration)
    }

    @Test func creatureEmergesWhileTheFlashIsStillFading() {
        // 캐릭터는 빛이 완전히 사라지기 전에 등장해야 "빛 속에서 나온다"로 읽힌다.
        // 빛이 다 꺼진 뒤 등장하면 두 연출이 끊겨 보인다.
        let p = HatchReveal.flashProgress(atAbsolute: HatchReveal.creatureEntry)
        #expect(p > 0.5 && p < 1.0)
        #expect(HatchReveal.flashOpacity(p) > 0.05, "등장 시점에 빛이 이미 다 꺼졌다")
    }

    @Test func totalDurationCoversTheWholeSequence() {
        #expect(HatchReveal.total >= HatchReveal.flashEnd)
        #expect(HatchReveal.total >= HatchReveal.creatureEntry)
    }

    // MARK: - 섬광 곡선 (확장 → 유지 → 수축)

    @Test func flashStartsAndEndsAtNothing() {
        // 양 끝이 0이어야 켜질 때/꺼질 때 화면에 판이 튀지 않는다.
        #expect(HatchReveal.flashScale(0) == 0)
        #expect(HatchReveal.flashOpacity(0) == 0)
        #expect(HatchReveal.flashOpacity(1) == 0)
    }

    @Test func flashExpandsToCoverTheScreenThenCollapses() {
        // 메이플식 리빌: 화면을 꽉 채웠다가(=배율 1) 사그라든다.
        let peak = HatchReveal.flashScale(HatchReveal.expandFraction)
        #expect(abs(peak - 1) < 0.001, "확장이 끝나면 화면을 가득 채워야 한다")

        // 확장 구간은 단조 증가.
        var previous = -1.0
        for step in 0...20 {
            let p = HatchReveal.expandFraction * Double(step) / 20
            let value = HatchReveal.flashScale(p)
            #expect(value >= previous, "확장 중에 줄어들었다 p=\(p)")
            previous = value
        }
        // 수축 구간은 단조 감소.
        previous = .infinity
        for step in 0...20 {
            let p = HatchReveal.holdEndFraction + (1 - HatchReveal.holdEndFraction) * Double(step) / 20
            let value = HatchReveal.flashScale(p)
            #expect(value <= previous, "수축 중에 커졌다 p=\(p)")
            previous = value
        }
    }

    @Test func flashHoldsWhileFullyOpen() {
        // 유지 구간에선 배율이 1 근처로 머문다(꽉 찬 화면을 잠깐 붙잡아 임팩트를 준다).
        for step in 0...10 {
            let p = HatchReveal.expandFraction
                + (HatchReveal.holdEndFraction - HatchReveal.expandFraction) * Double(step) / 10
            #expect(HatchReveal.flashScale(p) > 0.95)
        }
    }

    @Test func flashOpacityNeverExceedsOne() {
        for step in 0...100 {
            let value = HatchReveal.flashOpacity(Double(step) / 100)
            #expect(value >= 0 && value <= 1, "불투명도가 범위를 벗어났다: \(value)")
        }
    }

    @Test func reducedMotionKeepsTheEffectButTamesTheGlare() {
        // 연출을 없애지 않고 자극만 낮춘다 — 보이긴 해야 부화한 걸 안다.
        #expect(HatchReveal.reducedMotionPeakOpacity > 0)
        #expect(HatchReveal.reducedMotionPeakOpacity < HatchReveal.peakOpacity / 2)

        let peak = HatchReveal.expandFraction
        let normal = HatchReveal.flashOpacity(peak)
        let reduced = HatchReveal.flashOpacity(peak, peak: HatchReveal.reducedMotionPeakOpacity)
        #expect(reduced < normal)
        #expect(reduced > 0)
    }

    // MARK: - 화면 덮기

    @Test func flashRadiusCoversScreenFromAnyOrigin() {
        // 알은 화면 정중앙이 아니라 위쪽에 있다. 어디서 터지든 네 모서리까지 닿아야
        // "화면을 가득 채운다"가 성립한다(안 닿으면 구석에 어두운 부분이 남는다).
        let screen = CGSize(width: 402, height: 874)
        for origin in [CGPoint(x: 201, y: 437), CGPoint(x: 201, y: 300), CGPoint(x: 0, y: 0)] {
            let radius = HatchRevealOverlay.radiusCovering(size: screen, from: origin)
            for corner in [CGPoint(x: 0, y: 0), CGPoint(x: 402, y: 0),
                           CGPoint(x: 0, y: 874), CGPoint(x: 402, y: 874)] {
                let distance = hypot(corner.x - origin.x, corner.y - origin.y)
                #expect(radius >= distance - 0.001,
                        "origin \(origin)에서 모서리 \(corner)까지 안 닿는다")
            }
        }
    }

    // MARK: - 화면 흔들림

    @Test func shakeStartsAndEndsAtRest() {
        // 끝에서 0이 아니면 화면이 어긋난 채로 남는다.
        #expect(HatchReveal.shakeOffset(0, amplitude: 8) == .zero)
        #expect(HatchReveal.shakeOffset(1, amplitude: 8) == .zero)
    }

    @Test func shakeDecaysAndStaysWithinAmplitude() {
        var maxEarly = 0.0
        var maxLate = 0.0
        for step in 0...100 {
            let p = Double(step) / 100
            let offset = HatchReveal.shakeOffset(p, amplitude: 8)
            let magnitude = max(abs(offset.width), abs(offset.height))
            #expect(magnitude <= 8.0001, "진폭을 넘었다: \(magnitude)")
            if p < 0.3 { maxEarly = max(maxEarly, magnitude) }
            if p > 0.7 { maxLate = max(maxLate, magnitude) }
        }
        #expect(maxEarly > maxLate, "흔들림이 감쇠하지 않는다")
        #expect(maxEarly > 1, "흔들림이 너무 약해 안 보인다")
    }

    // MARK: - 햅틱 패턴

    @Test func hapticPatternBuildsThenHits() {
        let events = HatchHapticPattern.events
        #expect(!events.isEmpty)
        // 시간순 정렬(CoreHaptics가 요구).
        #expect(events == events.sorted { $0.time < $1.time })
        // 가장 센 이벤트가 임팩트 순간이어야 한다 — 그래야 그림과 손이 같이 터진다.
        let strongest = try? #require(events.max { $0.intensity < $1.intensity })
        #expect(abs((strongest?.time ?? -1) - HatchReveal.impact) < 0.02)
    }

    @Test func hapticEventsAreValidForCoreHaptics() {
        for event in HatchHapticPattern.events {
            #expect(event.intensity >= 0 && event.intensity <= 1, "세기 범위 초과: \(event)")
            #expect(event.sharpness >= 0 && event.sharpness <= 1, "날카로움 범위 초과: \(event)")
            #expect(event.time >= 0)
            #expect(event.time <= HatchReveal.total)
            if event.isContinuous {
                #expect(event.duration > 0, "연속 이벤트에 길이가 없다: \(event)")
                #expect(event.time + event.duration <= HatchReveal.total + 0.01)
            }
        }
    }

    @Test func hapticBuildupPrecedesTheImpact() {
        // 임팩트 전에 약한 떨림이 깔려야 "쌓였다 터진다"로 느껴진다.
        let buildup = HatchHapticPattern.events.filter { $0.time < HatchReveal.impact }
        #expect(!buildup.isEmpty, "충전 구간 햅틱이 없다")
        let impactEvent = HatchHapticPattern.events.first { abs($0.time - HatchReveal.impact) < 0.02 }
        let impactIntensity = try? #require(impactEvent?.intensity)
        for event in buildup {
            #expect(event.intensity < (impactIntensity ?? 1), "충전이 임팩트보다 세다: \(event)")
        }
    }
}
