//
//  SecondaryButton.swift
//  Eggtimer
//
//  보조 액션 버튼. 채움 없음 / 텍스트·보더 중립(textPrimary·border).
//  Primary(흰 채움)와 Danger(빨강) 사이의 비파괴적 보조 선택지(예: 새 알 받기).
//

import SwiftUI

struct SecondaryButton: View {
    private let title: String
    private let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.body.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.elementTight)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.buttonCornerRadius)
                        .stroke(AppColor.border, lineWidth: AppSpacing.borderWidth)
                )
        }
    }
}

#Preview {
    ZStack {
        AppColor.pageBackground.ignoresSafeArea()
        SecondaryButton("새 알 받기") {}
            .padding(AppSpacing.element)
    }
    .preferredColorScheme(.dark)
}
