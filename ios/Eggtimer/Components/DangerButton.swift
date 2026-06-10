//
//  DangerButton.swift
//  Eggtimer
//
//  위험/중단 액션 버튼. 채움 없음 / 텍스트·보더 danger.
//  (UI_GUIDE.md 컴포넌트 > 버튼 > Danger, 예: 세션 중단)
//

import SwiftUI

struct DangerButton: View {
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
                .foregroundStyle(AppColor.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.elementTight)
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
        DangerButton("세션 중단") {}
            .padding(AppSpacing.element)
    }
    .preferredColorScheme(.dark)
}
