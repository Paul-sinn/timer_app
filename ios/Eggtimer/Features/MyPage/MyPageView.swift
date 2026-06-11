//
//  MyPageView.swift
//  Eggtimer
//
//  마이페이지 탭 화면(프로필/계정/설정). UI_GUIDE: 카드/리스트, 좌측 정렬 기본.
//  Phase 0(UI 더미): 로그인은 UI 껍데기만 만든다(ADR-002/007). 실제 인증
//  (Sign in with Apple/Google/Supabase)은 Phase 2에서 연동하며 여기서는 호출하지 않는다.
//  로그인 게이트 없이 이 화면이 바로 보이고, 설정 토글은 로컬 @State로만 동작한다.
//  검수를 위해 더미 유저(AppSnapshot)를 주입 가능하게 한다(기본 = populated).
//

import SwiftUI

struct MyPageView: View {
    /// 프로필/통계에 쓰는 더미 유저 상태. 외부 주입(기본값 = populated)으로 검수 가능.
    private let user: AppSnapshot

    // 설정 토글은 로컬 상태만(영속/시스템 연동 없음).
    @State private var notificationsOn = true
    @State private var soundOn = true
    /// 화면 꺼짐 방지(Feature 7). 세션 중 ScreenAwake가 이 값을 참조한다.
    @AppStorage(ScreenAwake.settingKey) private var keepScreenAwake = true

    #if DEBUG
    /// 화면 검수 갤러리(개발 전용) 표시 여부.
    @State private var showReviewGallery = false
    #endif

    init(user: AppSnapshot = MockData.populated) {
        self.user = user
    }

    var body: some View {
        ZStack {
            AppColor.pageBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    Text("MyPage")
                        .font(.title.weight(.bold))
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    profileHeader

                    accountSection

                    settingsSection
                }
                .padding(.horizontal, AppSpacing.section)
                .padding(.vertical, AppSpacing.section)
            }
        }
    }

    // MARK: - 프로필 헤더(아바타 + 이름 + 더미 부가정보)

    private var profileHeader: some View {
        AppCard {
            HStack(spacing: AppSpacing.element) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(AppColor.eggAccent)

                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
                        .font(AppFont.screenTitle)
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(1)
                    Text("가입일 · 2026.05.01")
                        .font(AppFont.cardTitle)
                        .foregroundStyle(AppColor.textSecondary)
                    Text("누적 부화 \(user.creatures.count)마리")
                        .font(AppFont.cardTitle)
                        .foregroundStyle(AppColor.eggAccent)
                }

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - 계정 섹션(로그인 전 가정 · UI 껍데기만)

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.elementTight) {
            Text("계정")
                .font(AppFont.cardTitle)
                .foregroundStyle(AppColor.textSecondary)

            // 실제 인증 연동은 Phase 2(ADR-007). 여기서는 액션을 호출하지 않는다.
            AuthButton(title: "Apple로 계속하기", symbol: "applelogo", style: .light) {
                // TODO: Phase 2 auth — Sign in with Apple
                print("Apple 로그인 (Phase 2 예정)")
            }
            AuthButton(title: "Google로 계속하기", symbol: "g.circle", style: .outline) {
                // TODO: Phase 2 auth — Sign in with Google
                print("Google 로그인 (Phase 2 예정)")
            }
        }
    }

    // MARK: - 설정 섹션(로컬 @State 토글 + 고정 안내 + 정보)

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.elementTight) {
            Text("설정")
                .font(AppFont.cardTitle)
                .foregroundStyle(AppColor.textSecondary)

            AppCard {
                VStack(spacing: AppSpacing.element) {
                    SettingToggleRow(title: "알림", systemImage: "bell", isOn: $notificationsOn)
                    SettingDivider()
                    SettingToggleRow(title: "사운드", systemImage: "speaker.wave.2", isOn: $soundOn)
                    SettingDivider()
                    SettingToggleRow(title: "화면 꺼짐 방지", systemImage: "sun.max", isOn: $keepScreenAwake)
                    SettingDivider()
                    SettingInfoRow(title: "다크모드", systemImage: "moon", value: "고정")
                    SettingDivider()
                    SettingInfoRow(title: "버전", systemImage: "info.circle", value: "0.1.0")
                    #if DEBUG
                    SettingDivider()
                    Button {
                        showReviewGallery = true
                    } label: {
                        SettingInfoRow(title: "🛠 화면 검수 갤러리(DEBUG)", systemImage: "wrench.and.screwdriver", value: "")
                    }
                    .buttonStyle(.plain)
                    #endif
                }
            }
        }
        #if DEBUG
        .fullScreenCover(isPresented: $showReviewGallery) {
            ReviewGalleryView()
        }
        #endif
    }
}

/// 소셜 로그인 버튼(UI 껍데기). light=흰 채움/검정, outline=보더만.
/// 실제 인증 호출은 하지 않으며 action은 주입된 클로저(현재 print/TODO)만 실행한다.
private struct AuthButton: View {
    enum Style { case light, outline }

    let title: String
    let symbol: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.elementTight) {
                Image(systemName: symbol)
                Text(title)
                    .font(AppFont.body.weight(.semibold))
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.elementTight)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.buttonCornerRadius)
                    .stroke(borderColor, lineWidth: AppSpacing.borderWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonCornerRadius))
        }
    }

    private var foreground: Color {
        style == .light ? AppColor.pageBackground : AppColor.textPrimary
    }
    private var background: Color {
        style == .light ? AppColor.textPrimary : AppColor.cardBackground
    }
    private var borderColor: Color {
        style == .light ? .clear : AppColor.border
    }
}

/// 설정 토글 행. isOn은 화면 로컬 @State에 바인딩(영속/시스템 연동 없음).
private struct SettingToggleRow: View {
    let title: String
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
private struct SettingInfoRow: View {
    let title: String
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

/// 설정 행 사이 구분선.
private struct SettingDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppColor.border)
            .frame(height: AppSpacing.borderWidth)
    }
}

#Preview("로그인 전") {
    MyPageView(user: MockData.populated)
        .preferredColorScheme(.dark)
}

#Preview("새 사용자") {
    MyPageView(user: MockData.empty)
        .preferredColorScheme(.dark)
}
