//
//  EggView.swift
//  Eggtimer
//
//  홈 화면의 주인공 알. 픽셀아트 알 에셋(Egg0~Egg5)을 단계에 맞춰 보여주고,
//  뒤에 따뜻한 골드 글로우를 깐다. 픽셀 선명도를 위해 보간을 끈다(.none).
//  UI_GUIDE 허용 모션인 idle 미세 흔들림(루프)만 둔다.
//

import SwiftUI

struct EggView: View {
    /// 0(온전) ~ 5(부화 직전) 알 이미지 단계.
    let stageIndex: Int
    /// 알 높이 기준 크기(pt).
    var height: CGFloat = 240

    /// idle 흔들림 토글.
    @State private var wobbling = false

    private var assetName: String { "Egg\(min(max(stageIndex, 0), EggState.visualStages - 1))" }

    var body: some View {
        ZStack {
            // 골드 글로우(알 뒤 은은한 빛). UI_GUIDE 안티패턴(네온)과 다른, 단일 따뜻한 광원.
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
                .rotationEffect(.degrees(wobbling ? 1.5 : -1.5), anchor: .bottom)
                .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: wobbling)
        }
        .onAppear { wobbling = true }
        .accessibilityLabel(Text("부화 중인 알, \(stageIndex + 1)단계"))
    }
}

#Preview {
    ZStack {
        AppColor.pageBackground.ignoresSafeArea()
        HStack(spacing: AppSpacing.section) {
            EggView(stageIndex: 0, height: 150)
            EggView(stageIndex: 5, height: 150)
        }
    }
    .preferredColorScheme(.dark)
}
