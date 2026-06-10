//
//  EggView.swift
//  Eggtimer
//
//  홈 화면의 주인공인 알. 따뜻한 옐로우(eggAccent) 알 위에 crack 단계만큼
//  균열 획을 겹쳐 그린다. UI_GUIDE 허용 모션인 idle 미세 흔들림(루프)만 둔다.
//  실제 부화 애니메이션/타이머 로직은 Phase 2 범위(여기서는 표시 전용).
//

import SwiftUI

struct EggView: View {
    /// 0부터 시작하는 균열 단계. 단계 수만큼 균열 획이 드러난다.
    let crackStage: Int
    /// 알 한 변(너비) 기준 크기(pt). 높이는 살짝 더 길게 그린다.
    var width: CGFloat = 184

    /// idle 흔들림 토글(onAppear에서 켜서 루프 시작).
    @State private var wobbling = false

    private var height: CGFloat { width * 1.28 }

    var body: some View {
        ZStack {
            // 알 몸체: 위가 좁고 아래가 둥근 타원형.
            Ellipse()
                .fill(AppColor.eggAccent)
                .overlay(
                    // 상단 미세 하이라이트(글로우 아님: 단순 음영 표현).
                    Ellipse()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: width * 0.4, height: height * 0.28)
                        .offset(x: -width * 0.14, y: -height * 0.22)
                        .blendMode(.softLight)
                )
                .overlay(
                    // 균열 획: 다크 라인으로 crack 단계만큼 노출.
                    EggCracks(stage: crackStage)
                        .stroke(
                            AppColor.pageBackground.opacity(0.85),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )
                )
                .clipShape(Ellipse())
        }
        .frame(width: width, height: height)
        .rotationEffect(.degrees(wobbling ? 2 : -2), anchor: .bottom)
        .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: wobbling)
        .onAppear { wobbling = true }
        .accessibilityLabel(Text("부화 중인 알, 균열 \(crackStage)단계"))
    }
}

/// crack 단계 수만큼 균열 지그재그 획을 그리는 Shape.
/// 정점 근처에서 시작해 아래로 갈라지는 형태를 정규화 좌표로 미리 정의한다.
private struct EggCracks: Shape {
    let stage: Int

    /// 알 bounding rect 기준 0...1 정규화 좌표의 균열 목록.
    private static let cracks: [[CGPoint]] = [
        [CGPoint(x: 0.50, y: 0.06), CGPoint(x: 0.44, y: 0.22),
         CGPoint(x: 0.55, y: 0.34), CGPoint(x: 0.47, y: 0.50)],
        [CGPoint(x: 0.50, y: 0.08), CGPoint(x: 0.62, y: 0.20),
         CGPoint(x: 0.52, y: 0.33), CGPoint(x: 0.63, y: 0.46)],
        [CGPoint(x: 0.30, y: 0.30), CGPoint(x: 0.40, y: 0.40),
         CGPoint(x: 0.33, y: 0.52), CGPoint(x: 0.42, y: 0.63)],
        [CGPoint(x: 0.70, y: 0.34), CGPoint(x: 0.60, y: 0.46),
         CGPoint(x: 0.68, y: 0.58), CGPoint(x: 0.58, y: 0.70)]
    ]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard stage > 0 else { return path }
        for crack in EggCracks.cracks.prefix(stage) {
            guard let first = crack.first else { continue }
            path.move(to: scaled(first, in: rect))
            for point in crack.dropFirst() {
                path.addLine(to: scaled(point, in: rect))
            }
        }
        return path
    }

    private func scaled(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + point.x * rect.width,
                y: rect.minY + point.y * rect.height)
    }
}

#Preview {
    ZStack {
        AppColor.pageBackground.ignoresSafeArea()
        HStack(spacing: AppSpacing.section) {
            EggView(crackStage: 0, width: 120)
            EggView(crackStage: 4, width: 120)
        }
    }
    .preferredColorScheme(.dark)
}
