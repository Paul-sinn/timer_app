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
    @AppStorage(AppTheme.storageKey) private var selectedRaw = AppTheme.defaultTheme.rawValue

    private let columns = [GridItem(.flexible(), spacing: AppSpacing.element),
                           GridItem(.flexible(), spacing: AppSpacing.element)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: AppSpacing.element) {
                ForEach(AppTheme.allCases) { theme in
                    card(for: theme)
                }
            }
            .readableWidth()
            .padding(AppSpacing.section)

            #if DEBUG
            debugProToggle
            #endif
        }
        .background(ThemedBackground())
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var selected: AppTheme { AppTheme(rawValue: selectedRaw) ?? AppTheme.defaultTheme }

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
                ThemeSwatch(theme: theme, isSelected: isSelected, isLocked: !unlocked)
                    .frame(height: 96)
                Text(theme.displayName)
                    .font(AppFont.cardTitle)
                    .foregroundStyle(selected.onPagePrimary)   // 이름은 현재 적용된 배경 위에 놓인다
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
        .foregroundStyle(selected.onPageSecondary)
        .readableWidth()
        .padding(.horizontal, AppSpacing.section)
        .padding(.bottom, AppSpacing.section)
    }
    #endif
}

/// 테마 썸네일(그림 미리보기 + 선택 테두리·체크). 크기는 호출부의 frame이 정한다.
struct ThemeSwatch: View {
    /// 지금 적용된 테마. 선택 테두리는 썸네일 바깥, 즉 현재 배경 위에 놓이므로 그 위에서 읽히는 강조색을 쓴다.
    @Environment(\.appTheme) private var current
    let theme: AppTheme
    var isSelected = false
    var isLocked = false

    var body: some View {
        ZStack {
            ThemedBackground()
                .environment(\.appTheme, theme)   // 이 썸네일만 해당 테마로 미리보기
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                        .stroke(isSelected ? current.onPageAccent : AppColor.border,
                                lineWidth: isSelected ? 2 : AppSpacing.borderWidth)
                )
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppColor.eggAccent)
            } else if isLocked {
                Image(systemName: "lock.fill")
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
    }
}

/// 홈 우상단 붓 버튼으로 여는 빠른 배경 선택. 탭하면 바로 적용 → 뒤의 홈 화면이 그 자리에서 바뀐다(세션 중에도).
/// 아이패드는 버튼에 붙은 팝오버, 아이폰(좁은 창)은 내용 높이에 맞춘 낮은 시트로 뜬다.
struct ThemeQuickPicker: View {
    @Environment(\.appTheme) private var theme
    @AppStorage(AppTheme.storageKey) private var selectedRaw = AppTheme.defaultTheme.rawValue
    /// 시트 높이 = 내용 높이(글자 크기 설정이 커져도 안 잘리게 실측).
    @State private var contentHeight: CGFloat = 360

    private static let tileSize: CGFloat = 96
    private let columns = Array(repeating: GridItem(.fixed(tileSize), spacing: AppSpacing.element), count: 3)

    var body: some View {
        VStack(spacing: AppSpacing.element) {
            Text("Theme")
                .font(AppFont.cardTitle)
                .foregroundStyle(theme.onPageSecondary)
            LazyVGrid(columns: columns, spacing: AppSpacing.element) {
                // shortcut: 잠금(Pro) 테마는 빼고 무료만 보여준다. 잠금 테마가 생기면 여기도 "출시 예정" 표시를 넣을 것.
                ForEach(AppTheme.free) { option in
                    Button { selectedRaw = option.rawValue } label: {
                        VStack(spacing: 6) {
                            ThemeSwatch(theme: option, isSelected: option == theme)
                                .frame(width: Self.tileSize, height: Self.tileSize)
                            Text(option.displayName)
                                .font(AppFont.cardTitle)
                                .foregroundStyle(theme.onPagePrimary)   // 이름은 현재 배경색 위에 놓인다
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(option == theme ? .isSelected : [])
                }
            }
        }
        .padding(AppSpacing.section)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.visible)
        .presentationBackground(theme.pageBackground)
    }
}

#Preview {
    NavigationStack {
        ThemePickerView()
            .environment(ProAccess())
    }
    .preferredColorScheme(.dark)
}
