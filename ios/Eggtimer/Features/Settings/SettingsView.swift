//
//  SettingsView.swift
//  Eggtimer
//
//  홈 우상단 기어에서 여는 앱 Settings 시트. 알림·효과음·진동·화면 꺼짐 방지 토글과
//  버전 정보를 담는다. 값은 @AppStorage(AppSettings 키)로 영속되며 HomeView가 같은
//  키를 읽어 실제 동작(알림 예약·시스템 사운드·햅틱)을 게이트한다.
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppSettings.notificationsKey) private var notificationsOn = AppSettings.defaultOn
    @AppStorage(AppSettings.soundKey) private var soundOn = AppSettings.defaultOn
    @AppStorage(AppSettings.hapticsKey) private var hapticsOn = AppSettings.defaultOn
    /// 화면 꺼짐 방지(Feature 7). 세션 중 ScreenAwake가 참조.
    @AppStorage(ScreenAwake.settingKey) private var keepScreenAwake = true

    /// 알림이 시스템에서 거부돼 켤 수 없을 때 안내 알럿.
    @State private var showDeniedAlert = false

    #if DEBUG
    @State private var showReviewGallery = false
    #endif

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground()

                ScrollView {
                    AppCard {
                        VStack(spacing: AppSpacing.element) {
                            SettingToggleRow(title: "Notifications", systemImage: "bell", isOn: $notificationsOn)
                            SettingDivider()
                            SettingToggleRow(title: "Sound", systemImage: "speaker.wave.2", isOn: $soundOn)
                            SettingDivider()
                            SettingToggleRow(title: "Haptics", systemImage: "iphone.radiowaves.left.and.right", isOn: $hapticsOn)
                            SettingDivider()
                            SettingToggleRow(title: "Keep screen on", systemImage: "sun.max", isOn: $keepScreenAwake)
                            SettingDivider()
                            NavigationLink {
                                ThemePickerView()
                            } label: {
                                HStack {
                                    SettingInfoRow(title: "Theme", systemImage: "paintbrush.pointed", value: "")
                                    Image(systemName: "chevron.right")
                                        .font(.footnote)
                                        .foregroundStyle(AppColor.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                            SettingDivider()
                            SettingInfoRow(title: "Version", systemImage: "info.circle", value: appVersion)
                            #if DEBUG
                            SettingDivider()
                            Button {
                                showReviewGallery = true
                            } label: {
                                SettingInfoRow(title: "🛠 Screen Review Gallery(DEBUG)", systemImage: "wrench.and.screwdriver", value: "")
                            }
                            .buttonStyle(.plain)
                            #endif
                        }
                    }
                    .padding(.horizontal, AppSpacing.section)
                    .padding(.vertical, AppSpacing.section)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppColor.eggAccent)
                }
            }
            .onChange(of: notificationsOn) { _, on in
                guard on else { FocusNotifier.cancel(); return }   // 끄면 예약 Cancel
                // 켤 때: 미결정→시스템 프롬프트, 이미 거부됨→Settings 앱 안내(재프롬프트 불가).
                Task {
                    switch await FocusNotifier.authorizationStatus() {
                    case .notDetermined: await FocusNotifier.requestAuthorization()
                    case .denied:        showDeniedAlert = true
                    default:             break
                    }
                }
            }
            .alert("Notifications are off", isPresented: $showDeniedAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Allow notifications in iOS Settings › Notifications.")
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
        .environment(ProAccess())   // ThemePicker(하위) 네비게이션용
        .preferredColorScheme(.dark)
}
