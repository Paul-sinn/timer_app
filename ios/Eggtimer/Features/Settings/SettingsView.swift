//
//  SettingsView.swift
//  Eggtimer
//
//  홈 우상단 기어에서 여는 앱 설정 시트. 알림·효과음·진동·화면 꺼짐 방지 토글과
//  버전 정보를 담는다. 값은 @AppStorage(AppSettings 키)로 영속되며 HomeView가 같은
//  키를 읽어 실제 동작(알림 예약·시스템 사운드·햅틱)을 게이트한다.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppSettings.notificationsKey) private var notificationsOn = AppSettings.defaultOn
    @AppStorage(AppSettings.soundKey) private var soundOn = AppSettings.defaultOn
    @AppStorage(AppSettings.hapticsKey) private var hapticsOn = AppSettings.defaultOn
    /// 화면 꺼짐 방지(Feature 7). 세션 중 ScreenAwake가 참조.
    @AppStorage(ScreenAwake.settingKey) private var keepScreenAwake = true

    #if DEBUG
    @State private var showReviewGallery = false
    #endif

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.pageBackground.ignoresSafeArea()

                ScrollView {
                    AppCard {
                        VStack(spacing: AppSpacing.element) {
                            SettingToggleRow(title: "알림", systemImage: "bell", isOn: $notificationsOn)
                            SettingDivider()
                            SettingToggleRow(title: "효과음", systemImage: "speaker.wave.2", isOn: $soundOn)
                            SettingDivider()
                            SettingToggleRow(title: "진동", systemImage: "iphone.radiowaves.left.and.right", isOn: $hapticsOn)
                            SettingDivider()
                            SettingToggleRow(title: "화면 꺼짐 방지", systemImage: "sun.max", isOn: $keepScreenAwake)
                            SettingDivider()
                            SettingInfoRow(title: "버전", systemImage: "info.circle", value: appVersion)
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
                    .padding(.horizontal, AppSpacing.section)
                    .padding(.vertical, AppSpacing.section)
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                        .foregroundStyle(AppColor.eggAccent)
                }
            }
            .onChange(of: notificationsOn) { _, on in
                // 켜면 권한 요청(미결정 시), 끄면 예약된 알림 취소.
                if on {
                    Task { await FocusNotifier.requestAuthorization() }
                } else {
                    FocusNotifier.cancel()
                }
            }
            #if DEBUG
            .fullScreenCover(isPresented: $showReviewGallery) {
                ReviewGalleryView()
            }
            #endif
        }
    }

    /// 번들 버전(CFBundleShortVersionString). 없으면 "1.0".
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
