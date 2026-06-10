//
//  ProgressScreen.swift
//  Eggtimer
//
//  기록(Progress) 탭 화면(누적 집중 시간/세션 통계). step6에서 본문을 채운다.
//  SwiftUI 내장 `ProgressView`와의 이름 충돌을 피하기 위해 타입명은 `ProgressScreen`.
//  현재는 탭 진입을 확인하기 위한 빈 placeholder.
//

import SwiftUI

struct ProgressScreen: View {
    var body: some View {
        ZStack {
            AppColor.pageBackground.ignoresSafeArea()

            VStack(spacing: AppSpacing.elementTight) {
                Text("기록")
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
    ProgressScreen()
        .preferredColorScheme(.dark)
}
