//
//  HatchResultSheet.swift
//  Eggtimer
//
//  알이 부화했을 때 새로 얻은 생명체를 보여주는 결과 시트.
//  확률표에 따라 뽑힌 종을 등급 색과 함께 축하 톤으로 표시한다.
//

import SwiftUI

struct HatchResultSheet: View {
    let creature: Creature
    @State private var appeared = false

    var body: some View {
        ZStack {
            AppColor.pageBackground.ignoresSafeArea()

            VStack(spacing: AppSpacing.section) {
                Text("새로운 친구가 부화했어요!")
                    .font(AppFont.cardTitle)
                    .foregroundStyle(AppColor.textSecondary)

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [creature.rarity.color.opacity(0.35), .clear],
                                center: .center, startRadius: 6, endRadius: 150
                            )
                        )
                        .frame(width: 280, height: 280)
                    CreatureImage(imageName: creature.displayImageName(stage: 0), rarity: creature.rarity, size: 180)
                        .scaleEffect(appeared ? 1 : 0.6)
                        .animation(.spring(response: 0.5, dampingFraction: 0.55), value: appeared)
                }

                VStack(spacing: AppSpacing.elementTight) {
                    Text(creature.name)
                        .font(AppFont.screenTitle)
                        .foregroundStyle(AppColor.textPrimary)
                    Text(creature.rarity.label)
                        .font(AppFont.cardTitle)
                        .foregroundStyle(creature.rarity.color)
                    if creature.hasFinalArt {
                        Text("이어서 집중하면 진화해요 ✨")
                            .font(AppFont.body)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }

                Text("컬렉션에 추가되었어요")
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.textSecondary)
            }
            .padding(AppSpacing.section)
        }
        .onAppear { appeared = true }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }
}

#Preview("일반") {
    HatchResultSheet(creature: Creature(species: .chicken, imageName: "ChickenBro", hatchedAt: .now))
        .preferredColorScheme(.dark)
}

#Preview("전설") {
    HatchResultSheet(creature: Creature(species: .phoenix, hatchedAt: .now))
        .preferredColorScheme(.dark)
}
