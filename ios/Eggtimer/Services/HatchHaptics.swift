//
//  HatchHaptics.swift
//  Eggtimer
//
//  부화 순간 햅틱(진동) 재생기. 화면이 터질 때 손도 같이 터져야 "진짜 터졌다"로 느껴진다.
//
//  기존엔 `.sensoryFeedback(trigger: hatchling?.id)` 한 방뿐이었는데, 그건 **캐릭터가 등장하는
//  시점**에 울려서 폭발 순간과 어긋났다. 여기선 CoreHaptics로 충전 → 임팩트 → 등장의
//  세 박자를 영상 프레임에 맞춰 재생한다(패턴 정의는 HatchHapticPattern, 시각은 HatchReveal).
//
//  CoreHaptics를 쓰는 이유: UIFeedbackGenerator는 "톡" 한 번만 가능해서 세기를 점점 올리는
//  충전 구간을 만들 수 없다.
//
//  햅틱 하드웨어가 없으면(시뮬레이터·구형 기기) 조용히 아무것도 안 한다 — 화면 연출은 그대로 돈다.
//

import CoreHaptics
import Foundation

@MainActor
final class HatchHaptics {
    static let shared = HatchHaptics()

    /// 엔진 생성은 비용이 있어 한 번 만들어 재사용한다. 미지원 기기에선 계속 nil.
    private var engine: CHHapticEngine?
    /// 패턴은 매번 만들 필요가 없어 캐시한다.
    private var player: CHHapticPatternPlayer?

    private var isSupported: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    private init() {}

    /// 화면 진입 시 미리 엔진을 세워둔다. 부화 순간에 처음 만들면 첫 진동이 늦게 온다.
    func prepare() {
        guard isSupported, engine == nil else { return }
        do {
            let engine = try CHHapticEngine()
            // 앱이 백그라운드에 갔다 오거나 통화 등으로 엔진이 멈추면 다시 세운다.
            engine.stoppedHandler = { _ in }
            engine.resetHandler = { [weak engine] in try? engine?.start() }
            try engine.start()
            self.engine = engine
            self.player = try engine.makePlayer(with: Self.pattern())
        } catch {
            // 햅틱은 있으면 좋은 것이지 필수가 아니다. 실패해도 연출을 막지 않는다.
            engine = nil
            player = nil
        }
    }

    /// 부화 패턴을 처음부터 재생. 영상 재생과 같은 순간에 부르면 박자가 맞는다.
    /// - Parameter enabled: Settings의 진동 스위치. 꺼져 있으면 아무것도 안 한다.
    func play(enabled: Bool) {
        guard enabled, isSupported else { return }
        prepare()   // 아직 안 세워졌으면 지금 세운다
        guard let engine, let player else { return }
        do {
            try engine.start()          // 유휴 상태로 내려가 있었을 수 있다
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // 재생 실패는 무시 — 진동만 없고 화면 연출은 정상 진행.
        }
    }

    /// HatchHapticPattern(순수 데이터)을 CoreHaptics 패턴으로 옮긴다.
    private static func pattern() throws -> CHHapticPattern {
        let events = HatchHapticPattern.events.map { event in
            CHHapticEvent(
                eventType: event.isContinuous ? .hapticContinuous : .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: event.intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: event.sharpness),
                ],
                relativeTime: event.time,
                duration: event.duration
            )
        }
        return try CHHapticPattern(events: events, parameters: [])
    }
}
