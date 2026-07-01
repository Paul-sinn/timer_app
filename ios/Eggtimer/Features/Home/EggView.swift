//
//  EggView.swift
//  Eggtimer
//
//  홈 화면의 주인공 알. 15분마다 crack하는 4단계 픽셀아트(첫 알 → 2egg → 3egg → 4egg)를
//  진행도에 맞춰 보여주고, 뒤에 따뜻한 골드 글로우를 깐다. 픽셀 선명도를 위해 보간을 끈다(.none).
//  살아있는 느낌의 미세 흔들림(루프) + crack(단계 변화) 시 "팍" 튀는 pop 연출.
//  새 에셋(2egg/3egg/4egg)이 아직 없으면 기존 Egg 단계로 폴백한다(개발 중에도 안 깨지게).
//

import SwiftUI

struct EggView: View {
    /// 알 이미지 단계 0 ~ 4(부화 직전). 12.5분마다 한 칸씩 crack(목표 60분 기준 5단계).
    let stageIndex: Int
    /// 알 높이 기준 크기(pt).
    var height: CGFloat = 240

    /// 흔들림 루프 토글.
    @State private var wobbling = false
    /// crack 순간 "팍" 튀는 pop.
    @State private var crackPop = false
    /// 마지막 단계 두근두근(심장박동) 펄스.
    @State private var beat = false

    /// 단계별 알 에셋(무결 → crack 점점 진행 → 부화 직전 황금 균열). 없으면 기존 Egg 에셋으로 폴백.
    private static let primaryNames = ["Egg0", "2egg", "secondcrack_egg", "thirdcrack_egg", "3egg", "4egg", "4-2egg"]
    private static let fallbackNames = ["Egg0", "Egg1", "Egg2", "Egg3", "Egg4", "Egg5", "Egg5"]

    private static var stageCount: Int { primaryNames.count }

    private var clampedStage: Int { min(max(stageIndex, 0), Self.stageCount - 1) }
    /// 부화 임박(마지막 단계) — 두근두근 강조.
    private var isFinalStage: Bool { clampedStage >= Self.stageCount - 1 }

    private var assetName: String {
        let primary = Self.primaryNames[clampedStage]
        if UIImage(named: primary) != nil { return primary }
        return Self.fallbackNames[clampedStage]
    }

    /// 후반 단계일수록 더 크게/빠르게 흔들린다(부화 임박감).
    private var wobbleAmplitude: Double { 1.3 + Double(clampedStage) * 0.55 }
    private var wobblePeriod: Double { max(2.8 - Double(clampedStage) * 0.28, 1.3) }

    var body: some View {
        ZStack {
            // 골드 글로우(알 뒤 은은한 빛). 단일 따뜻한 광원.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppColor.eggAccent.opacity(0.28), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: height * 0.62
                    )
                )
                .frame(width: height * 1.25, height: height * 1.25)

            Image(assetName)
                .interpolation(.none)        // 픽셀아트 선명하게
                .resizable()
                .scaledToFit()
                .frame(height: height)
                .scaleEffect(crackPop ? 1.08 : 1.0)
                .scaleEffect(isFinalStage && beat ? 1.05 : 1.0)   // 부화 임박 두근두근
                .rotationEffect(.degrees(wobbling ? wobbleAmplitude : -wobbleAmplitude), anchor: .bottom)
                .animation(.easeInOut(duration: wobblePeriod).repeatForever(autoreverses: true), value: wobbling)
                .animation(.spring(response: 0.25, dampingFraction: 0.4), value: crackPop)
                .animation(.easeInOut(duration: 0.42).repeatForever(autoreverses: true), value: beat)
        }
        .onAppear { wobbling = true; beat = true }
        .onChange(of: stageIndex) { _, _ in
            // crack(단계 상승) 시 한 번 "팍" 튀어 변화 강조.
            crackPop = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                crackPop = false
            }
        }
        .accessibilityLabel(Text("부화 중인 알, \(clampedStage + 1)단계"))
    }
}

#Preview {
    ZStack {
        AppColor.pageBackground.ignoresSafeArea()
        HStack(spacing: AppSpacing.section) {
            EggView(stageIndex: 0, height: 150)
            EggView(stageIndex: 3, height: 150)
        }
    }
    .preferredColorScheme(.dark)
}
