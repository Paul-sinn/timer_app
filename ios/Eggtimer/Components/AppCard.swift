//
//  AppCard.swift
//  Eggtimer
//
//  공용 카드 컨테이너. 배경 cardBackground, 1px border, 모서리 14, 패딩 16.
//  (UI_GUIDE.md 컴포넌트 > 카드)
//

import SwiftUI

struct AppCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                    .stroke(AppColor.border, lineWidth: AppSpacing.borderWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }
}

#Preview {
    ZStack {
        AppColor.pageBackground.ignoresSafeArea()
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.elementTight) {
                Text("Today's focus")
                    .font(AppFont.cardTitle)
                    .foregroundStyle(AppColor.textSecondary)
                Text("1h 24m")
                    .font(AppFont.screenTitle)
                    .foregroundStyle(AppColor.textPrimary)
            }
        }
        .padding(AppSpacing.element)
    }
    .preferredColorScheme(.dark)
}
