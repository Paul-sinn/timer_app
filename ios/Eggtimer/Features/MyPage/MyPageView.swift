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
import AuthenticationServices

struct MyPageView: View {
    /// 프로필/통계에 쓰는 더미 유저 상태. 외부 주입(기본값 = populated)으로 검수 가능.
    private let user: AppSnapshot

    /// 로그인 세션 상태(@Observable — body에서 접근 시 변화 추적).
    private let auth: AuthService
    /// 로그인↔로컬 동기화. nil이면 프리뷰(동기화 없음).
    private let sync: SyncCoordinator?

    // 설정 토글은 로컬 상태만(영속/시스템 연동 없음).
    @State private var notificationsOn = true
    @State private var soundOn = true
    /// 화면 꺼짐 방지(Feature 7). 세션 중 ScreenAwake가 이 값을 참조한다.
    @AppStorage(ScreenAwake.settingKey) private var keepScreenAwake = true

    /// Sign in with Apple 요청에 실은 원본 nonce(콜백에서 Supabase 검증에 재사용).
    @State private var appleNonce: String?
    /// 로그인/삭제 진행 중 표시.
    @State private var isWorking = false
    /// 에러 알림 문구(nil = 미표시).
    @State private var errorMessage: String?
    /// 계정 삭제 확인 알림 표시.
    @State private var showDeleteConfirm = false

    #if DEBUG
    /// 화면 검수 갤러리(개발 전용) 표시 여부.
    @State private var showReviewGallery = false
    #endif

    /// 실제 누적 부화 수(주입). nil이면 더미(user.creatures.count) 사용.
    private let hatchedCount: Int?

    init(user: AppSnapshot = MockData.populated,
         hatchedCount: Int? = nil,
         auth: AuthService,
         sync: SyncCoordinator? = nil) {
        self.user = user
        self.hatchedCount = hatchedCount
        self.auth = auth
        self.sync = sync
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
        .alert("문제가 발생했어요", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("계정을 삭제할까요?", isPresented: $showDeleteConfirm) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) { deleteAccount() }
        } message: {
            Text("계정과 클라우드에 저장된 집중 기록·생명체가 영구 삭제됩니다. 이 기기의 로컬 데이터는 남아요.")
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
                    Text("누적 부화 \(hatchedCount ?? user.creatures.count)마리")
                        .font(AppFont.cardTitle)
                        .foregroundStyle(AppColor.eggAccent)
                }

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - 계정 섹션 (로그인 상태에 따라 분기)

    @ViewBuilder
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.elementTight) {
            Text("계정")
                .font(AppFont.cardTitle)
                .foregroundStyle(AppColor.textSecondary)

            if auth.isAuthenticated {
                signedInView
            } else {
                signedOutView
            }
        }
    }

    /// 비로그인: Apple/Google 로그인 버튼. 로그인하면 기기 간 동기화가 켜진다는 안내.
    @ViewBuilder
    private var signedOutView: some View {
        Text("로그인하면 집중 기록과 생명체가 클라우드에 백업되어 다른 기기에서도 이어집니다.")
            .font(AppFont.cardTitle)
            .foregroundStyle(AppColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

        SignInWithAppleButton(.continue) { request in
            let nonce = AppleSignInNonce.random()
            appleNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleSignInNonce.sha256(nonce)
        } onCompletion: { result in
            handleApple(result)
        }
        .signInWithAppleButtonStyle(.white)
        .frame(height: 48)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonCornerRadius))
        .disabled(isWorking)

        #if canImport(GoogleSignIn)
        if GoogleAuth.isConfigured {
            AuthButton(title: "Google로 계속하기", symbol: "g.circle", style: .outline) {
                signInWithGoogle()
            }
            .disabled(isWorking)
        }
        #endif

        if isWorking {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 4)
        }
    }

    /// 로그인됨: 동기화 상태 + 로그아웃 + 계정 삭제(심사 요건).
    @ViewBuilder
    private var signedInView: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.element) {
                Label {
                    Text(sync?.isSyncing == true ? "동기화 중…" : "기기 간 동기화 켜짐")
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.textPrimary)
                } icon: {
                    Image(systemName: "checkmark.icloud")
                        .foregroundStyle(AppColor.eggAccent)
                }

                SettingDivider()

                Button { signOut() } label: {
                    Text("로그아웃")
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(isWorking)

                SettingDivider()

                Button { showDeleteConfirm = true } label: {
                    Text("계정 삭제")
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(isWorking)
            }
        }
    }

    // MARK: - 인증 액션

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = appleNonce
            else {
                errorMessage = "Apple 로그인 정보를 읽지 못했어요. 다시 시도해 주세요."
                return
            }
            performSignIn { try await auth.signInWithApple(idToken: idToken, nonce: nonce) }
        case .failure(let error):
            // 사용자가 취소(ASAuthorizationError.canceled)한 경우는 조용히 무시.
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = "Apple 로그인에 실패했어요: \(error.localizedDescription)"
            }
        }
    }

    #if canImport(GoogleSignIn)
    private func signInWithGoogle() {
        performSignIn {
            let idToken = try await GoogleAuth.signIn()
            try await auth.signInWithGoogle(idToken: idToken)
        }
    }
    #endif

    /// 로그인 작업 공통 래퍼: 진행표시 → 성공 시 로그인 머지 동기화.
    private func performSignIn(_ work: @escaping () async throws -> Void) {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await work()
                await sync?.syncOnLogin()
            } catch {
                errorMessage = "로그인에 실패했어요: \(error.localizedDescription)"
            }
        }
    }

    private func signOut() {
        isWorking = true
        Task {
            defer { isWorking = false }
            await sync?.signOut()
        }
    }

    private func deleteAccount() {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await sync?.deleteAccount()
            } catch {
                errorMessage = "계정 삭제에 실패했어요: \(error.localizedDescription)"
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
                    SettingInfoRow(title: "버전", systemImage: "info.circle", value: "1.0")
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
    MyPageView(user: MockData.populated, auth: AuthService())
        .preferredColorScheme(.dark)
}

#Preview("새 사용자") {
    MyPageView(user: MockData.empty, auth: AuthService())
        .preferredColorScheme(.dark)
}
