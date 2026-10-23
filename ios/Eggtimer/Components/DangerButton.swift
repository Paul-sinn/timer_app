//
//  DangerButton.swift
//  Eggtimer
//
//  위험/Stop 액션 버튼. 카드색 채움 / 텍스트·보더 danger.
//  (채움은 밝은 파스텔 배경 위에서도 글자가 읽히게 — 배경 테마와 무관하게 다크 버튼)
//  (UI_GUIDE.md 컴포넌트 > 버튼 > Danger, 예: 세션 Stop)
//

import SwiftUI

struct DangerButton: View {
    private let title: LocalizedStringKey
    private let action: () -> Void

    init(_ title: LocalizedStringKey, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.body.weight(.semibold))
                .foregroundStyle(AppColor.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.elementTight)
                .background(AppColor.cardBackground,
                            in: RoundedRectangle(cornerRadius: AppSpacing.buttonCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.buttonCornerRadius)
                        .stroke(AppColor.danger, lineWidth: AppSpacing.borderWidth)
                )
        }
    }
}

#Preview {
    ZStack {
        AppColor.pageBackground.ignoresSafeArea()
        DangerButton("Stop session") {}
            .padding(AppSpacing.element)
    }
    .preferredColorScheme(.dark)
}
