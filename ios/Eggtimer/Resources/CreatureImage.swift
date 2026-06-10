//
//  CreatureImage.swift
//  Eggtimer
//
//  생명체/알 이미지 렌더의 단일 경로. 픽셀아트 에셋을 보간 없이(.none) 선명하게 그린다.
//  - 일반 모드: 실제 캐릭터 에셋을 레어도 색 카드 위에 표시.
//  - 실루엣 모드: 미발견 생명체를 검은 실루엣 + 가운데 "?" 로 표시(픽셀 톤).
//

import SwiftUI

struct CreatureImage: View {
    /// 렌더할 에셋명.
    let imageName: String
    /// 배경/테두리 색을 결정하는 레어도.
    let rarity: Rarity
    /// 렌더 한 변 크기(pt).
    var size: CGFloat = 96
    /// 미발견 실루엣 모드.
    var silhouette: Bool = false

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
                // 캐릭터 윤곽을 검은 실루엣으로 + 가운데 "?"
                Image(imageName)
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
                Image(imageName)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.1)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text(silhouette ? "미발견 생명체" : "\(rarity.label) 생명체 이미지"))
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
