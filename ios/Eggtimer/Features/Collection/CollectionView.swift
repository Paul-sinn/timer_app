//
//  CollectionView.swift
//  Eggtimer
//
//  컬렉션 탭 화면(부화한 생명체 그리드). step5에서 본문을 채운다.
//  현재는 탭 진입을 확인하기 위한 빈 placeholder.
//

import SwiftUI

struct CollectionView: View {
    var body: some View {
        ZStack {
            AppColor.pageBackground.ignoresSafeArea()

            VStack(spacing: AppSpacing.elementTight) {
                Text("컬렉션")
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
    CollectionView()
        .preferredColorScheme(.dark)
}
