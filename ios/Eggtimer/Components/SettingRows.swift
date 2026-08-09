//
//  SettingRows.swift
//  Eggtimer
//
//  Settings 화면 공용 행 컴포넌트(SettingsView·MyPage 등에서 재사용).
//  (원래 MyPageView 내부 private 구조체였으나 Settings 시트와 공유하려 추출)
//

import SwiftUI

/// Settings 토글 행.
struct SettingToggleRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Label {
                Text(title)
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.textPrimary)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .tint(AppColor.eggAccent)
    }
}

/// 토글이 아닌 정보/고정 안내 행(우측에 값만 표시).
struct SettingInfoRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    let value: String

    var body: some View {
        HStack {
            Label {
                Text(title)
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.textPrimary)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(AppColor.textSecondary)
            }
            Spacer(minLength: 0)
            Text(value)
                .font(AppFont.body)
                .foregroundStyle(AppColor.textSecondary)
        }
    }
}

/// Settings 행 사이 구분선.
struct SettingDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppColor.border)
            .frame(height: AppSpacing.borderWidth)
    }
}
