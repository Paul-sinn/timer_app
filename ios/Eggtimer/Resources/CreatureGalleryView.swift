//
//  CreatureGalleryView.swift
//  Eggtimer
//
//  캐릭터 아트 검수용 갤러리. **DEBUG 빌드에만 존재**하고 프로덕션 UI 어디에서도 진입할 수 없다
//  (릴리스 빌드에는 타입 자체가 컴파일되지 않는다). Xcode Preview로만 연다.
//
//  한눈에 OK하는 것:
//   - 닭 5종 × 진화 1·2·3단계
//   - 각 단계의 idle/action 모션(재생) + 낱장 비교(정지)
//   - 게임 진화 단계(0…3) → 아트 단계(1…3) 대응
//   - 작은 화면/큰 화면에서 잘림·UI 침범 여부(아래 #Preview 3종)
//

#if DEBUG
import SwiftUI

struct CreatureGalleryView: View {
    @State private var playing = true
    @State private var cardHeight: CGFloat = 96   // 5종이 한 화면에 들어오는 크기

    private let bases = CreatureArt.animatedBases

    var body: some View {
        ZStack {
            AppColor.pageBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    controls

                    section("진화 단계별 모션 (재생)") {
                        ForEach(bases, id: \.self) { base in
                            characterRow(base)
                        }
                    }

                    section("프레임 낱장 (idle / action 정지 비교)") {
                        ForEach(bases, id: \.self) { base in
                            framesRow(base)
                        }
                    }

                    section("게임 진화 단계 → 아트 단계 대응") {
                        stageMappingRow
                    }
                }
                .padding(AppSpacing.element)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 컨트롤

    private var controls: some View {
        VStack(alignment: .leading, spacing: AppSpacing.elementTight) {
            Toggle("모션 재생", isOn: $playing)
                .font(AppFont.body)
                .foregroundStyle(AppColor.textBody)
            HStack {
                Text("Size \(Int(cardHeight))pt")
                    .font(.caption)
                    .foregroundStyle(AppColor.textSecondary)
                Slider(value: $cardHeight, in: 56...240)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    // MARK: - 행

    /// 한 캐릭터의 1·2·3단계를 모션으로 재생.
    private func characterRow(_ base: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(base).font(.caption.weight(.semibold)).foregroundStyle(AppColor.textSecondary)
            HStack(alignment: .bottom, spacing: AppSpacing.elementTight) {
                ForEach(1...CreatureArt.artStageCount, id: \.self) { art in
                    VStack(spacing: 4) {
                        // 아트 단계 n 을 실제로 보여주는 게임 단계를 골라 넘긴다.
                        AnimatedCreatureView(base: base,
                                             stage: evolutionStage(showingArt: art),
                                             animated: playing)
                            .frame(height: cardHeight)
                            .frame(maxWidth: .infinity)
                            .background(AppColor.cardBackground.opacity(0.4))
                        Text("stage \(art)").font(.caption2).foregroundStyle(AppColor.textDisabled)
                    }
                }
            }
        }
    }

    /// idle/action 낱장을 나란히 — 두 장이 같은 자리·같은 크기인지 눈으로 OK.
    private func framesRow(_ base: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(base).font(.caption.weight(.semibold)).foregroundStyle(AppColor.textSecondary)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(1...CreatureArt.artStageCount, id: \.self) { art in
                    ForEach(CreatureMotionFrame.allCases, id: \.self) { frame in
                        VStack(spacing: 4) {
                            stillFrame(base: base, art: art, frame: frame)
                                .frame(height: cardHeight * 0.72)
                                .frame(maxWidth: .infinity)
                            Text("s\(art) \(frame.rawValue)")
                                .font(.system(size: 9)).foregroundStyle(AppColor.textDisabled)
                        }
                    }
                }
            }
        }
    }

    /// 모션 없이 특정 프레임 한 장만.
    @ViewBuilder
    private func stillFrame(base: String, art: Int, frame: CreatureMotionFrame) -> some View {
        let stage = evolutionStage(showingArt: art)
        if let name = CreatureArt.animatedAssetName(base: base, stage: stage, frame: frame) {
            Image(name).interpolation(.none).resizable().scaledToFit()
        } else {
            Image(base).interpolation(.none).resizable().scaledToFit()
        }
    }

    private var stageMappingRow: some View {
        HStack(spacing: AppSpacing.elementTight) {
            ForEach(0...Creature.maxEvolutionStage, id: \.self) { stage in
                VStack(spacing: 4) {
                    AnimatedCreatureView(base: "ChickenBro", stage: stage, animated: playing)
                        .frame(height: cardHeight)
                        .frame(maxWidth: .infinity)
                        .background(AppColor.cardBackground.opacity(0.4))
                    Text("Evolve \(stage) → art \(CreatureArt.artStage(forEvolutionStage: stage))")
                        .font(.system(size: 9)).foregroundStyle(AppColor.textDisabled)
                }
            }
        }
    }

    // MARK: - 도우미

    /// 아트 단계 n을 화면에 띄우는 대표 게임 진화 단계.
    private func evolutionStage(showingArt art: Int) -> Int {
        (0...Creature.maxEvolutionStage)
            .first { CreatureArt.artStage(forEvolutionStage: $0) == art } ?? 0
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.elementTight) {
            Text(title).font(AppFont.cardTitle).foregroundStyle(AppColor.textPrimary)
            content()
        }
    }
}

#Preview("갤러리 - 기본") {
    CreatureGalleryView()
}

#Preview("갤러리 - 작은 화면(320pt)") {
    CreatureGalleryView().frame(width: 320)
}

#Preview("갤러리 - 큰 화면(440pt)") {
    CreatureGalleryView().frame(width: 440)
}
#endif
