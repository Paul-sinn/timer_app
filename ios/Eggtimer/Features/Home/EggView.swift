//
//  EggView.swift
//  Eggtimer
//
//  홈 화면의 주인공 알. 진행도에 맞춰 crack 6단계(fullegg → … → abouttocrack)를 순차 표시하고,
//  뒤에 따뜻한 골드 글로우를 깐다. 픽셀 선명도를 위해 보간을 끈다(.none).
//  살아있는 느낌의 미세 흔들림(루프) + crack(단계 변화) 시 "팍" 튀는 pop 연출.
//  6장 모두 부화 버스트와 동일한 공통 캔버스라 crack↔burst 전환 시 알 축·바닥선이 안 튄다.
//

import SwiftUI

struct EggView: View {
    /// 알 이미지 단계 0 ~ 5(부화 직전). 진행도 6분할(EggState.visualStages).
    let stageIndex: Int
    /// 알 높이 기준 크기(pt).
    var height: CGFloat = 240

    /// 흔들림 루프 토글.
    @State private var wobbling = false
    /// crack 순간 "팍" 튀는 pop.
    @State private var crackPop = false
    /// 마지막 단계 두근두근(심장박동) 펄스.
    @State private var beat = false

    /// crack 6단계 에셋(무결 → 금 확장 → 벌어지기 직전). README 순서 그대로.
    private static let crackNames = [
        "fullegg", "firstcrack_egg", "secondcrack_egg",
        "thirdcrack_egg", "fourthcrack_egg", "abouttocrack_egg",
    ]

    private static var stageCount: Int { crackNames.count }

    private var clampedStage: Int { min(max(stageIndex, 0), Self.stageCount - 1) }
    /// 부화 임박(마지막 단계) — 두근두근 강조.
    private var isFinalStage: Bool { clampedStage >= Self.stageCount - 1 }

    private var assetName: String { Self.crackNames[clampedStage] }

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
        .accessibilityLabel(Text("Hatching egg · stage \(clampedStage + 1)"))
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
