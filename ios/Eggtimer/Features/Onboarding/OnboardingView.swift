//
//  OnboardingView.swift
//  Eggtimer
//
//  첫 실행 온보딩. 앱의 핵심 루프(집중 → 알 부화 → 캐릭터 수집·진화)를 3장으로 소개한다.
//  마지막 장의 "Start하기"를 누르면 onFinish가 호출되고 다시 보이지 않는다(@AppStorage 게이트는 RootView).
//

import SwiftUI

struct OnboardingView: View {
    /// 온보딩 Done 콜백(RootView가 hasSeenOnboarding을 true로 전환).
    var onFinish: () -> Void

    @State private var page = 0

    private struct Page: Identifiable {
        let id = UUID()
        let image: String      // 에셋 이미지명(픽셀 알/캐릭터)
        let systemFallback: String
        let title: LocalizedStringKey
        let body: LocalizedStringKey
    }

    private let pages: [Page] = [
        Page(image: "fullegg", systemFallback: "timer",
             title: "Focus, and your egg grows",
             body: "While the timer runs and you focus,\nyour egg cracks through 6 stages toward hatching."),
        Page(image: "Chicken1", systemFallback: "sparkles",
             title: "Collect the friends you hatch",
             body: "Finish a session and a pixel creature hatches by chance,\nfilling out your collection."),
        Page(image: "WhiteTigerEvolved", systemFallback: "wand.and.stars",
             title: "Keep focusing to evolve",
             body: "Keep focusing alongside a legendary friend\nand it evolves into something even cooler."),
        Page(image: "", systemFallback: "bell.badge.fill",
             title: "We'll tell you when it's time",
             body: "Even if you step away for a bit,\nwe'll notify you at hatch and break time."),
    ]

    var body: some View {
        ZStack {
            AppColor.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, p in
                        pageView(p).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                button
                    .padding(.horizontal, AppSpacing.section)
                    .padding(.bottom, AppSpacing.section)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func pageView(_ p: Page) -> some View {
        VStack(spacing: AppSpacing.section) {
            Spacer()
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [AppColor.eggAccent.opacity(0.25), .clear],
                                         center: .center, startRadius: 4, endRadius: 150))
                    .frame(width: 280, height: 280)
                image(for: p)
            }
            VStack(spacing: AppSpacing.elementTight) {
                Text(p.title)
                    .font(AppFont.screenTitle)
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(p.body)
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, AppSpacing.section)
            Spacer()
            Spacer()
        }
    }

    /// 에셋이 있으면 픽셀 이미지를, 없으면 SF 심볼을 표시(에셋명이 바뀌어도 안전).
    @ViewBuilder
    private func image(for p: Page) -> some View {
        if UIImage(named: p.image) != nil {
            Image(p.image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(height: 160)
        } else {
            Image(systemName: p.systemFallback)
                .font(.system(size: 96))
                .foregroundStyle(AppColor.eggAccent)
        }
    }

    private var isLast: Bool { page == pages.count - 1 }

    private var button: some View {
        VStack(spacing: AppSpacing.elementTight) {
            Button {
                if isLast {
                    // 알림 페이지: 소프트 애스크 → 시스템 권한 프롬프트(미결정 시) 후 온보딩 종료.
                    Task {
                        await FocusNotifier.requestAuthorization()
                        onFinish()
                    }
                } else {
                    withAnimation { page += 1 }
                }
            } label: {
                Text(isLast ? String(localized: "Turn on notifications") : String(localized: "Next"))
                    .font(AppFont.cardTitle.weight(.bold))
                    .foregroundStyle(AppColor.pageBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColor.eggAccent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            // 마지막 페이지에서만 Skip(알림 없이 Start). Settings에서 나중에 켤 수 있음.
            if isLast {
                Button("Maybe later") { onFinish() }
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.textSecondary)
                    .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
