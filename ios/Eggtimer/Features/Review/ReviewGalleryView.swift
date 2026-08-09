//
//  ReviewGalleryView.swift
//  Eggtimer
//
//  Screen Review Gallery(개발/검수 전용). 데이터·로그인 없이 모든 화면과 모든 상태
//  (빈/채움)를 한 곳에서 점프해 점검한다. 앞 step들이 만든 init 주입을 활용해
//  각 화면을 지정한 더미 상태로 강제로 띄운다.
//  실제 사용자 플로우(RootView 4탭)는 그대로 두고, 여기는 별도 진입점일 뿐이다.
//  #if DEBUG 가드로 릴리스 빌드에는 노출되지 않는다.
//

#if DEBUG
import SwiftUI

struct ReviewGalleryView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Home") {
                    GalleryLink(title: "초기 상태") {
                        HomeView(session: .preview(progress: 0))
                    }
                    GalleryLink(title: "부화 임박 상태") {
                        HomeView(session: .preview(progress: 0.95))
                    }
                }

                Section("Collection") {
                    GalleryLink(title: "populated") {
                        CollectionView(creatures: MockData.populated.creatures)
                    }
                    GalleryLink(title: "empty") {
                        CollectionView(creatures: MockData.empty.creatures)
                    }
                }

                Section("Progress") {
                    GalleryLink(title: "populated") {
                        ProgressScreen(sessions: MockData.sampleResults)
                    }
                    GalleryLink(title: "empty") {
                        ProgressScreen(sessions: [])
                    }
                }

                Section("MyPage") {
                    GalleryLink(title: "로그인 전(더미 유저)") {
                        MyPageView(user: MockData.populated, auth: AuthService())
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColor.pageBackground.ignoresSafeArea())
            .navigationTitle("Screen Review Gallery")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .tint(AppColor.eggAccent)
        .preferredColorScheme(.dark)
    }
}

/// 갤러리 행: 탭하면 지정한 더미 상태의 화면으로 push한다.
private struct GalleryLink<Destination: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
                .preferredColorScheme(.dark)
        } label: {
            Text(title)
                .font(AppFont.body)
                .foregroundStyle(AppColor.textPrimary)
        }
        .listRowBackground(AppColor.cardBackground)
    }
}

#Preview {
    ReviewGalleryView()
}
#endif
