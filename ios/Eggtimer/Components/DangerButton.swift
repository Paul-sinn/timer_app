//
//  DangerButton.swift
//  Eggtimer
//
//  위험/Stop 액션 버튼. 채움 없음 / 텍스트·보더 danger.
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
