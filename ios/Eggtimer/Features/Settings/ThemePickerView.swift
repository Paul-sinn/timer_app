//
//  ThemePickerView.swift
//  Eggtimer
//
//  배경 테마 선택(SettingsView에서 push). 무료 테마는 즉시 적용, 잠금(Pro) 테마는
//  "출시 예정"으로만 노출(선택 불가). ProAccess가 해제되면(1.1 결제/DEBUG 토글) 잠금 테마도 선택 가능.
//  선택은 @AppStorage(AppTheme.storageKey)에 저장 → ThemedBackground가 전 화면에 즉시 반영.
//

import SwiftUI

struct ThemePickerView: View {
    @Environment(ProAccess.self) private var pro
    @AppStorage(AppTheme.storageKey) private var selectedRaw = AppTheme.nest.rawValue

    private let columns = [GridItem(.flexible(), spacing: AppSpacing.element),
                           GridItem(.flexible(), spacing: AppSpacing.element)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: AppSpacing.element) {
                ForEach(AppTheme.allCases) { theme in
                    card(for: theme)
                }
            }
            .padding(AppSpacing.section)

            #if DEBUG
            debugProToggle
            #endif
        }
        .background(ThemedBackground())
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var selected: AppTheme { AppTheme(rawValue: selectedRaw) ?? .nest }

    /// 선택 가능 여부: 무료거나 Pro 해제 시.
    private func isUnlocked(_ theme: AppTheme) -> Bool { !theme.isPro || pro.isPro }

    @ViewBuilder
    private func card(for theme: AppTheme) -> some View {
        let unlocked = isUnlocked(theme)
        let isSelected = theme == selected

        Button {
            guard unlocked else { return }   // 잠금 테마는 무시(출시 예정)
            selectedRaw = theme.rawValue
        } label: {
            VStack(spacing: AppSpacing.elementTight) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                        .fill(theme.pageBackground)
                        .frame(height: 96)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                                .stroke(isSelected ? AppColor.eggAccent : AppColor.border,
                                        lineWidth: isSelected ? 2 : AppSpacing.borderWidth)
                        )
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppColor.eggAccent)
                    } else if !unlocked {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
                Text(theme.displayName)
                    .font(AppFont.cardTitle)
                    .foregroundStyle(AppColor.textPrimary)
                if !unlocked {
                    Text("Coming soon")
                        .font(AppFont.cardTitle)
                        .foregroundStyle(AppColor.legendary)
                }
            }
            .opacity(unlocked ? 1 : 0.65)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }

    #if DEBUG
    /// 검수용: Pro 잠금 해제 토글(잠금 테마 미리 선택해보기).
    private var debugProToggle: some View {
        Toggle("🛠 Pro unlocked (DEBUG)", isOn: Binding(
            get: { pro.isPro },
            set: { pro.setDebugPro($0) }
        ))
        .tint(AppColor.eggAccent)
        .font(AppFont.body)
        .foregroundStyle(AppColor.textSecondary)
        .padding(.horizontal, AppSpacing.section)
        .padding(.bottom, AppSpacing.section)
    }
    #endif
}

#Preview {
    NavigationStack {
        ThemePickerView()
            .environment(ProAccess())
    }
    .preferredColorScheme(.dark)
}
