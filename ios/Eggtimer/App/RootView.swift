//
//  RootView.swift
//  Eggtimer
//
//  앱 루트 화면. step3에서 TabView(Home/Collection/Progress/MyPage)로 교체된다.
//  현재는 다크 배경 위에 앱 이름만 보여주는 임시 플레이스홀더.
//

import SwiftUI

struct RootView: View {
    var body: some View {
        ZStack {
            Color(red: 0.039, green: 0.039, blue: 0.039) // #0A0A0A 페이지 배경
                .ignoresSafeArea()

            Text("Eggtimer")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}
