//
//  HomeView.swift
//  Eggtimer
//
//  홈 탭 화면(중앙 알 + 타이머). step4에서 본문을 채운다.
//  현재는 탭 진입을 확인하기 위한 빈 placeholder.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        ZStack {
            AppColor.pageBackground.ignoresSafeArea()

            VStack(spacing: AppSpacing.elementTight) {
                Text("홈")
                    .font(AppFont.screenTitle)
                    .foregroundStyle(AppColor.textPrimary)
                Text("곧 구현됩니다")
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
