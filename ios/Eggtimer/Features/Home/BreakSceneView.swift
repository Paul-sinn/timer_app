//
//  BreakSceneView.swift
//  Eggtimer
//
//  포모도로 휴식 장면 애니메이션. 각 장면 = 2프레임(기본/변형)을 장면별 속도로 부드럽게 반복.
//  프레임은 make_break_assets.py 가 장면별 공통 캔버스에 bottom-center 정렬해 생성 → 프레임 전환 시
//  피사체가 세로로 튀지 않는다(낮잠 방울·스트레칭 팔만 위로 변함). 크로스페이드로 깜빡임 없이 전환.
//

import SwiftUI

/// 휴식 장면.
enum BreakScene: Hashable {
    case coffee   // 연기 피어오름
    case nap      // 코골이 방울 커졌다 작아짐
    case stretch  // 웅크림 → 쭉 펴기 → 유지 → 웅크림

    /// (기본 프레임, 변형 프레임) 에셋명.
    var frames: (base: String, variant: String) {
        switch self {
        case .coffee:  return ("BreakCoffee1", "BreakCoffee2")
        case .nap:     return ("BreakNap1", "BreakNap2")         // 작은 방울 → 큰 방울
        case .stretch: return ("BreakStretch1", "BreakStretch2") // 웅크림 → 쭉
        }
    }
}

/// 휴식 장면 2프레임 크로스페이드 애니메이션. 이미지 비율 유지(scaledToFit).
struct BreakSceneView: View {
    let scene: BreakScene
    /// 0 = 기본 프레임, 1 = 변형 프레임.
    @State private var blend: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let f = scene.frames
        // 진짜 크로스페이드(dissolve): 기본은 fade-out, 변형은 fade-in.
        // 기본이 계속 불투명하면 변형이 그 위에 겹쳐 두 겹으로 보임 → 반드시 base도 (1-blend).
        ZStack {
            Image(f.base).resizable().scaledToFit().opacity(1 - blend)
            Image(f.variant).resizable().scaledToFit().opacity(blend)
        }
        .task(id: scene) { await animate() }
    }

    private func animate() async {
        guard !reduceMotion else { blend = 0; return }
        // 대부분 시간은 한 프레임을 그대로 보여주고(hold), 전환은 짧게 dissolve → 겹침 최소.
        switch scene {
        case .coffee:  await loop(holdBase: 0.5, xfade: 0.9, holdVariant: 0.5)  // 연기 계속 흐름
        case .nap:     await loop(holdBase: 1.5, xfade: 0.6, holdVariant: 1.5)  // 방울 작게 머물다 크게
        case .stretch: await loop(holdBase: 0.8, xfade: 0.7, holdVariant: 1.3)  // 웅크림→펴기→유지
        }
    }

    /// 기본(holdBase 유지) → dissolve(xfade) → 변형(holdVariant 유지) → dissolve → 반복.
    /// 전환 순간만 짧게 겹치고 나머지는 한 장만 보인다.
    private func loop(holdBase: Double, xfade: Double, holdVariant: Double) async {
        while !Task.isCancelled {
            withAnimation(.easeInOut(duration: xfade)) { blend = 1 }
            try? await Task.sleep(for: .seconds(xfade + holdVariant))
            if Task.isCancelled { return }
            withAnimation(.easeInOut(duration: xfade)) { blend = 0 }
            try? await Task.sleep(for: .seconds(xfade + holdBase))
        }
    }
}
