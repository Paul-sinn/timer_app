//
//  CreatureImage.swift
//  Eggtimer
//
//  생명체/알 이미지 렌더의 단일 경로. 픽셀아트 에셋을 보간 없이(.none) 선명하게 그린다.
//  - 일반 모드: 실제 캐릭터 에셋을 레어도 색 카드 위에 표시.
//  - 실루엣 모드: Undiscovered creature를 검은 실루엣 + 가운데 "?" 로 표시(픽셀 톤).
//

import SwiftUI

struct CreatureImage: View {
    /// 렌더할 에셋명.
    let imageName: String
    /// 배경/테두리 색을 결정하는 레어도.
    let rarity: Rarity
    /// 렌더 한 변 크기(pt).
    var size: CGFloat = 96
    /// 진화 단계(0…`Creature.maxEvolutionStage`). 단계 아트/실루엣 선택에 쓰인다.
    var stage: Int = 0
    /// 미발견 실루엣 모드.
    var silhouette: Bool = false
    /// idle/action 모션 재생 여부. 조용해야 하는 자리(컬렉션 그리드)는 기본값 false로 둔다.
    var animated: Bool = false

    /// 실루엣에 쓸 에셋명. 단계 아트가 있으면 그 단계 idle, 없으면 기존 단일 이미지.
    private var silhouetteAssetName: String {
        CreatureArt.animatedAssetName(base: imageName, stage: stage, frame: .idle) ?? imageName
    }

    var body: some View {
        ZStack {
            // 카드 배경(실루엣일 때는 거의 비어 보이는 어두운 톤).
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(silhouette ? Color.white.opacity(0.03) : rarity.color.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                        .stroke(silhouette ? AppColor.border : rarity.color.opacity(0.45),
                                lineWidth: AppSpacing.borderWidth)
                )

            if silhouette {
                // 캐릭터 윤곽을 검은 실루엣으로 + 가운데 "?".
                // 단계 아트가 있으면 그 단계 실루엣(진화할수록 윤곽이 커져 궁금증 자극).
                Image(silhouetteAssetName)
                    .interpolation(.none)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(Color.black.opacity(0.78))
                    .padding(size * 0.14)
                Text("?")
                    .font(.system(size: size * 0.34, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColor.textSecondary)
            } else {
                // 3단계 아트를 가진 닭 변형이면 단계별 이미지 + idle/action 모션,
                // 그 외 종은 AnimatedCreatureView가 기존 단일 이미지로 폴백한다.
                AnimatedCreatureView(base: imageName, stage: stage, animated: animated)
                    .padding(size * 0.1)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text(silhouette ? String(localized: "Undiscovered creature") : String(localized: "\(rarity.label) creature image")))
    }
}

#Preview {
    ZStack {
        AppColor.pageBackground.ignoresSafeArea()
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: AppSpacing.element)],
                  spacing: AppSpacing.element) {
            ForEach(CreatureSpecies.allCases) { species in
                CreatureImage(imageName: species.silhouetteImageName, rarity: species.rarity)
            }
            ForEach(CreatureSpecies.allCases) { species in
                CreatureImage(imageName: species.silhouetteImageName, rarity: species.rarity, silhouette: true)
            }
        }
        .padding(AppSpacing.element)
    }
    .preferredColorScheme(.dark)
}
