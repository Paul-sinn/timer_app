//
//  MyPageView.swift
//  Eggtimer
//
//  마이페이지 탭 화면(프로필/계정/설정). step7에서 본문을 채운다.
//  현재는 탭 진입을 확인하기 위한 빈 placeholder.
//

import SwiftUI

struct MyPageView: View {
    var body: some View {
        ZStack {
            AppColor.pageBackground.ignoresSafeArea()

            VStack(spacing: AppSpacing.elementTight) {
                Text("마이")
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
    MyPageView()
        .preferredColorScheme(.dark)
}
