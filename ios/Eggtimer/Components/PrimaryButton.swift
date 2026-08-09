//
//  PrimaryButton.swift
//  Eggtimer
//
//  주 액션 버튼. 채움 흰색 / 텍스트 검정 / 모서리 12.
//  (UI_GUIDE.md 컴포넌트 > 버튼 > Primary, 예: 타이머 Start)
//

import SwiftUI

struct PrimaryButton: View {
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
                .foregroundStyle(AppColor.pageBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.elementTight)
                .background(AppColor.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonCornerRadius))
        }
    }
}

#Preview {
    ZStack {
        AppColor.pageBackground.ignoresSafeArea()
        PrimaryButton("Start timer") {}
            .padding(AppSpacing.element)
    }
    .preferredColorScheme(.dark)
}
