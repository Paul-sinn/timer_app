//
//  MyPageView.swift
//  Eggtimer
//
//  마이페이지 탭 화면(프로필/Account/Settings). UI_GUIDE: 카드/리스트, 좌측 정렬 기본.
//  Phase 0(UI 더미): 로그인은 UI 껍데기만 만든다(ADR-002/007). 실제 인증
//  (Sign in with Apple/Google/Supabase)은 Phase 2에서 연동하며 여기서는 호출하지 않는다.
//  로그인 게이트 없이 이 화면이 바로 보이고, Settings 토글은 로컬 @State로만 동작한다.
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

    // Settings 토글은 홈 기어 → SettingsView(Settings 시트)로 이관. MyPage는 프로필+Account만.

    /// Sign in with Apple 요청에 실은 원본 nonce(콜백에서 Supabase 검증에 재사용).
    @State private var appleNonce: String?
    /// 로그인/Delete 진행 중 표시.
    @State private var isWorking = false
    /// 에러 알림 문구(nil = 미표시).
    @State private var errorMessage: String?
    /// Delete account OK 알림 표시.
    @State private var showDeleteConfirm = false

    /// 실제 누적 부화 수(주입). nil이면 더미(user.creatures.count) 사용.
    private let hatchedCount: Int?

    /// 집중 이력 스토어(DEBUG 시드 데모용). 릴리스 UI에선 미사용.
    private let history: FocusHistoryStore?

    init(user: AppSnapshot = MockData.populated,
         hatchedCount: Int? = nil,
         auth: AuthService,
         sync: SyncCoordinator? = nil,
         history: FocusHistoryStore? = nil) {
        self.user = user
        self.hatchedCount = hatchedCount
        self.auth = auth
        self.sync = sync
        self.history = history
    }

    var body: some View {
        ZStack {
            ThemedBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    Text("MyPage")
                        .font(.title.weight(.bold))
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    profileHeader

                    accountSection

                    #if DEBUG
                    debugSection
                    #endif
                }
                .padding(.horizontal, AppSpacing.section)
                .padding(.vertical, AppSpacing.section)
            }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Delete account?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deleteAccount() }
        } message: {
            Text("Your account and the focus history and creatures saved in the cloud will be permanently deleted. Local data on this device remains.")
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
                    Text("Joined · May 1, 2026")
                        .font(AppFont.cardTitle)
                        .foregroundStyle(AppColor.textSecondary)
                    Text("\(hatchedCount ?? user.creatures.count) hatched")
                        .font(AppFont.cardTitle)
                        .foregroundStyle(AppColor.eggAccent)
                }

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Account 섹션 (로그인 상태에 따라 분기)

    @ViewBuilder
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.elementTight) {
            Text("Account")
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
        Text("Sign in to back up your focus history and creatures to the cloud and continue on your other devices.")
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
            AuthButton(title: "Continue with Google", symbol: "g.circle", style: .outline) {
                signInWithGoogle()
            }
            .disabled(isWorking)
        }
        #endif

        if isWorking {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 4)
        }
    }

    /// 로그인됨: 동기화 상태 + Sign out + Delete account(심사 요건).
    @ViewBuilder
    private var signedInView: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.element) {
                Label {
                    Text(sync?.isSyncing == true ? String(localized: "Syncing…") : String(localized: "Cross-device sync on"))
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.textPrimary)
                } icon: {
                    Image(systemName: "checkmark.icloud")
                        .foregroundStyle(AppColor.eggAccent)
                }

                SettingDivider()

                Button { signOut() } label: {
                    Text("Sign out")
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(isWorking)

                SettingDivider()

                Button { showDeleteConfirm = true } label: {
                    Text("Delete account")
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
                errorMessage = String(localized: "Couldn't read your Apple sign-in. Please try again.")
                return
            }
            performSignIn { try await auth.signInWithApple(idToken: idToken, nonce: nonce) }
        case .failure(let error):
            // 사용자가 Cancel(ASAuthorizationError.canceled)한 경우는 조용히 무시.
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = String(localized: "Apple sign-in failed: \(error.localizedDescription)")
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
                errorMessage = String(localized: "Sign-in failed: \(error.localizedDescription)")
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
                errorMessage = String(localized: "Couldn't delete account: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - 개발자 (DEBUG 전용 · 릴리스 빌드엔 없음)

    #if DEBUG
    /// 강제 부화로 선택된 종(nil = Normal odds). UI 갱신용 로컬 미러.
    @State private var debugForced: CreatureSpecies?
    /// 강제 draw 횟수(nil = Actual focus length). UI 갱신용 로컬 미러.
    @State private var debugDraws: Int?
    /// 데모 시드 완료 피드백.
    @State private var seedDone = false

    /// 확률이 낮은 종(전설 등)을 검수하려고 Next 부화를 특정 종으로 고정한다.
    /// 정상으로 되돌릴 때까지 유지된다.
    private var debugSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.elementTight) {
            Text("Developer (DEBUG)")
                .font(AppFont.cardTitle)
                .foregroundStyle(AppColor.textSecondary)

            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.element) {
                    Text("Force hatch")
                        .font(AppFont.body.weight(.semibold))
                        .foregroundStyle(AppColor.textPrimary)
                    Text(debugForced.map { "Now: \($0.name) · \($0.rarity.label)" }
                         ?? String(localized: "Now: normal odds"))
                        .font(AppFont.cardTitle)
                        .foregroundStyle(AppColor.eggAccent)
                    Text("Every hatch is this species until you switch back.")
                        .font(AppFont.cardTitle)
                        .foregroundStyle(AppColor.textSecondary)

                    SettingDivider()

                    debugForceButton(nil, title: String(localized: "Normal odds"))
                    ForEach(CreatureSpecies.allCases) { sp in
                        debugForceButton(sp, title: "\(sp.name) · \(sp.rarity.label)")
                    }
                }
            }

            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.element) {
                    Text("Force hatch draws (best-of-N)")
                        .font(AppFont.body.weight(.semibold))
                        .foregroundStyle(AppColor.textPrimary)
                    Text(debugDraws.map { "Now: \($0)× draws" }
                         ?? String(localized: "Now: actual focus length"))
                        .font(AppFont.cardTitle)
                        .foregroundStyle(AppColor.eggAccent)
                    Text("Rolls the tier this many times and keeps the best. Test odds without the long focus.")
                        .font(AppFont.cardTitle)
                        .foregroundStyle(AppColor.textSecondary)

                    SettingDivider()

                    debugDrawsButton(nil, title: String(localized: "Actual focus length"))
                    ForEach([2, 3, 4], id: \.self) { n in
                        debugDrawsButton(n, title: "\(n)× draw")
                    }
                }
            }

            if let history {
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.element) {
                        Text("Seed demo stats (screenshots)")
                            .font(AppFont.body.weight(.semibold))
                            .foregroundStyle(AppColor.textPrimary)
                        Text(seedDone ? "Seeded ✓ — open Progress" : "Replaces focus history with ~30 days of sessions (streak 14+). Sessions only; collection untouched.")
                            .font(AppFont.cardTitle)
                            .foregroundStyle(seedDone ? AppColor.success : AppColor.textSecondary)

                        SettingDivider()

                        Button {
                            history.debugReplaceAll(DemoSeed.sessions())
                            seedDone = true
                        } label: {
                            Text("Seed now")
                                .font(AppFont.body.weight(.semibold))
                                .foregroundStyle(AppColor.eggAccent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onAppear {
            debugForced = DebugHatch.forcedSpecies
            debugDraws = DebugHatch.forcedDraws
        }
    }

    private func debugDrawsButton(_ draws: Int?, title: String) -> some View {
        Button {
            DebugHatch.forcedDraws = draws
            debugDraws = draws
        } label: {
            HStack {
                Text(title)
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.textPrimary)
                Spacer()
                if debugDraws == draws {
                    Image(systemName: "checkmark").foregroundStyle(AppColor.eggAccent)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func debugForceButton(_ species: CreatureSpecies?, title: String) -> some View {
        Button {
            DebugHatch.forcedSpecies = species
            debugForced = species
        } label: {
            HStack {
                Text(title)
                    .font(AppFont.body)
                    .foregroundStyle(species?.rarity.color ?? AppColor.textPrimary)
                Spacer()
                if debugForced == species {
                    Image(systemName: "checkmark").foregroundStyle(AppColor.eggAccent)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    #endif

}

/// 소셜 로그인 버튼(UI 껍데기). light=흰 채움/검정, outline=보더만.
/// 실제 인증 호출은 하지 않으며 action은 주입된 클로저(현재 print/TODO)만 실행한다.
private struct AuthButton: View {
    enum Style { case light, outline }

    let title: LocalizedStringKey
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

#Preview("로그인 전") {
    MyPageView(user: MockData.populated, auth: AuthService())
        .preferredColorScheme(.dark)
}

#Preview("새 사용자") {
    MyPageView(user: MockData.empty, auth: AuthService())
        .preferredColorScheme(.dark)
}
