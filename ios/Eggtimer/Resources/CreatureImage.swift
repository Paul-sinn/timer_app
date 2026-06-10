//
//  CreatureImage.swift
//  Eggtimer
//
//  캐릭터 이미지 placeholder (ADR-006: 정식 에셋 전까지 mock으로 자리 확보).
//  모든 생명체/알 이미지 렌더는 이 View 한 곳만 거친다 → 추후 한 곳에서 실제 에셋 교체.
//  지금은 SF Symbol + 레어도 색 배경으로 placeholder를 그린다.
//

import SwiftUI

struct CreatureImage: View {
    /// 추후 실제 에셋명으로 교체될 placeholder 키.
    let imageName: String
    /// 배경/심볼 색을 결정하는 레어도.
    let rarity: Rarity
    /// 렌더 한 변 크기(pt).
    var size: CGFloat = 96

    /// imageName을 안정적인 SF Symbol로 매핑(에셋 부재 시 placeholder 심볼).
    private var symbolName: String {
        let symbols = [
            "hare.fill", "tortoise.fill", "bird.fill",
            "ant.fill", "ladybug.fill", "fish.fill", "pawprint.fill"
        ]
        let index = abs(imageName.hashValue) % symbols.count
        return symbols[index]
    }

    var body: some View {
        RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
            .fill(rarity.color.opacity(0.18))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                    .stroke(rarity.color.opacity(0.5), lineWidth: AppSpacing.borderWidth)
            )
            .overlay(
                Image(systemName: symbolName)
                    .font(.system(size: size * 0.4, weight: .regular))
                    .foregroundStyle(rarity.color)
            )
            .frame(width: size, height: size)
            .accessibilityLabel(Text("\(rarity.label) 생명체 이미지"))
    }
}

#Preview {
    ZStack {
        AppColor.pageBackground.ignoresSafeArea()
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: AppSpacing.element)],
                  spacing: AppSpacing.element) {
            ForEach(Rarity.allCases) { rarity in
                CreatureImage(imageName: "creature_\(rarity.rawValue)", rarity: rarity)
            }
        }
        .padding(AppSpacing.element)
    }
    .preferredColorScheme(.dark)
}
