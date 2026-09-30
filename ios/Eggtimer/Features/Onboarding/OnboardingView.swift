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
    /// 창 전체 크기(안전영역 포함). 큰 아이패드 창에서 일러스트를 키우는 데 쓴다.
    @State private var windowSize: CGSize = .zero
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var artScale: CGFloat {
        OnboardingLayout.artScale(width: windowSize.width, height: windowSize.height)
    }

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
                .onGeometryChange(for: CGSize.self) { $0.size } action: { windowSize = $0 }

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, p in
                        pageView(p).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                button
                    .readableWidth()
                    .padding(.horizontal, AppSpacing.section)
                    .padding(.bottom, AppSpacing.section)
            }
        }
        .preferredColorScheme(.dark)
    }

    /// 일러스트 크기. `scale`은 큰 아이패드 창에서만 1보다 크다(아이폰은 항상 1).
    private struct ArtSize {
        let glow: CGFloat
        let image: CGFloat
        let scale: CGFloat

        static func regular(scale: CGFloat = 1) -> ArtSize {
            ArtSize(glow: 280 * scale, image: 160 * scale, scale: scale)
        }
        /// 창이 낮을 때(가로 모드·Split View·큰 글씨) 쓰는 축소판.
        static let compact = ArtSize(glow: 180, image: 104, scale: 1)
    }

    /// 창 높이에 맞는 첫 배치를 고른다: 확대(큰 아이패드) → 기본(아이폰 기존 모습) → 축소 → 스크롤.
    /// 어떤 높이에서도 제목·본문이 잘리지 않는다. 버튼은 페이지 밖(아래 고정)이라 항상 보인다.
    private func pageView(_ p: Page) -> some View {
        ViewThatFits(in: .vertical) {
            if artScale > 1 {
                spacedPage(p, art: .regular(scale: artScale))
            }
            spacedPage(p, art: .regular())
            spacedPage(p, art: .compact)
            ScrollView {
                pageContent(p, art: .compact)
                    .padding(.top, AppSpacing.section)
                    // 페이지 점(인디케이터)이 본문 끝을 가리지 않게 여유를 둔다.
                    .padding(.bottom, AppSpacing.sectionLoose * 2)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    /// 위 1 : 아래 2 여백으로 콘텐츠를 살짝 위에 띄운다(기존 배치 그대로).
    private func spacedPage(_ p: Page, art: ArtSize) -> some View {
        VStack(spacing: AppSpacing.section) {
            Spacer()
            pageContent(p, art: art)
            Spacer()
            Spacer()
        }
    }

    private func pageContent(_ p: Page, art: ArtSize) -> some View {
        VStack(spacing: AppSpacing.section) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [AppColor.eggAccent.opacity(0.25), .clear],
                                         center: .center, startRadius: 4, endRadius: art.glow / 2 + 10))
                    .frame(width: art.glow, height: art.glow)
                image(for: p, height: art.image)
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
            // 일러스트를 키운 만큼 글씨도 1~2단계 키운다(AppFont의 텍스트 스타일이 따라 커진다).
            .dynamicTypeSize(OnboardingLayout.textSize(dynamicTypeSize, scale: art.scale))
            .readableWidth()
            .padding(.horizontal, AppSpacing.section)
        }
    }

    /// 에셋이 있으면 픽셀 이미지를, 없으면 SF 심볼을 표시(에셋명이 바뀌어도 안전).
    @ViewBuilder
    private func image(for p: Page, height: CGFloat) -> some View {
        if UIImage(named: p.image) != nil {
            Image(p.image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(height: height)
        } else {
            Image(systemName: p.systemFallback)
                .font(.system(size: height * 0.6))
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

/// 온보딩 확대 규칙(순수 로직, OnboardingLayoutTests가 검증).
enum OnboardingLayout {
    /// 가장 넓은 아이폰 폭(Pro Max 440). 이 폭 이하 창은 배율이 1을 넘지 않는다 → 아이폰은 항상 1.
    static let baselineWidth: CGFloat = 440
    /// 기준 아이폰 높이.
    static let baselineHeight: CGFloat = 852
    static let maxScale: CGFloat = 1.6

    /// 창 전체 크기 대비 일러스트 배율. 1...maxScale.
    static func artScale(width: CGFloat, height: CGFloat) -> CGFloat {
        guard width > 0, height > 0 else { return 1 }
        let raw = min(width / baselineWidth, height / baselineHeight)
        return min(max(raw, 1), maxScale)
    }

    /// 배율에 맞춘 글씨 크기. 1.2배 이상 한 단계, 1.5배 이상 두 단계 키운다.
    /// 표준 최대(xxxLarge)를 넘기지 않고, 접근성 크기를 쓰는 사용자는 그대로 둔다.
    static func textSize(_ current: DynamicTypeSize, scale: CGFloat) -> DynamicTypeSize {
        guard !current.isAccessibilitySize else { return current }
        let steps = scale >= 1.5 ? 2 : (scale >= 1.2 ? 1 : 0)
        let all = DynamicTypeSize.allCases
        guard steps > 0,
              let index = all.firstIndex(of: current),
              let cap = all.firstIndex(of: .xxxLarge) else { return current }
        return all[min(index + steps, cap)]
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
