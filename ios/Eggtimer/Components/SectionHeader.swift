//
//  SectionHeader.swift
//  Eggtimer
//
//  화면 섹션 제목. 좌측 정렬 기본(UI_GUIDE.md 레이아웃).
//  화면 제목 타이포(title2 semibold)를 사용한다.
//

import SwiftUI

struct SectionHeader: View {
    private let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(AppFont.screenTitle)
            .foregroundStyle(AppColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ZStack {
        AppColor.pageBackground.ignoresSafeArea()
        SectionHeader("컬렉션")
            .padding(AppSpacing.element)
    }
    .preferredColorScheme(.dark)
}
