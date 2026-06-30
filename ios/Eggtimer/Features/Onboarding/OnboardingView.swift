//
//  OnboardingView.swift
//  Eggtimer
//
//  첫 실행 온보딩. 앱의 핵심 루프(집중 → 알 부화 → 캐릭터 수집·진화)를 3장으로 소개한다.
//  마지막 장의 "시작하기"를 누르면 onFinish가 호출되고 다시 보이지 않는다(@AppStorage 게이트는 RootView).
//

import SwiftUI

struct OnboardingView: View {
    /// 온보딩 완료 콜백(RootView가 hasSeenOnboarding을 true로 전환).
    var onFinish: () -> Void

    @State private var page = 0

    private struct Page: Identifiable {
        let id = UUID()
        let image: String      // 에셋 이미지명(픽셀 알/캐릭터)
        let systemFallback: String
        let title: String
        let body: String
    }

    private let pages: [Page] = [
        Page(image: "Egg0", systemFallback: "timer",
             title: "집중하면 알이 자라요",
             body: "타이머를 켜고 집중하는 동안\n알이 6단계로 부화에 가까워져요."),
        Page(image: "Chicken1", systemFallback: "sparkles",
             title: "부화한 친구를 모아요",
             body: "집중을 끝내면 확률에 따라\n다양한 픽셀 생명체가 태어나 도감에 쌓여요."),
        Page(image: "WhiteTigerEvolved", systemFallback: "wand.and.stars",
             title: "이어서 집중하면 진화해요",
             body: "전설 친구는 부화 후에도 함께\n집중을 이어가면 더 멋지게 진화해요."),
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
        Button {
            if isLast {
                onFinish()
            } else {
                withAnimation { page += 1 }
            }
        } label: {
            Text(isLast ? "시작하기" : "다음")
                .font(AppFont.cardTitle.weight(.bold))
                .foregroundStyle(AppColor.pageBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColor.eggAccent)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
