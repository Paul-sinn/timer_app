//
//  CollectionView.swift
//  Eggtimer
//
//  컬렉션 탭 = 해금 도감. 다크+골드 톤. "Friends discovered n/12" + 3열 그리드.
//  도감 전체 12폼(CreatureForm)을 항상 나열한다.
//  - 발견한 폼: 실제 캐릭터 카드(도달한 최고 진화 단계 아트).
//  - 미발견 폼: 검은 실루엣 + "?" (픽셀 톤).
//  아무 카드나 탭하면 **3단계 진화 스트립** 상세가 열린다 — 도달한 단계는 실제 아트,
//  아직 못 간 단계는 실루엣으로만 보여 Next 진화에 대한 궁금증을 남긴다.
//  모든 카드에 등급 태그(일반=회색 · 레어=파랑 · 전설=금색)를 표시한다.
//  데이터는 주입된 [Creature](기본 populated)에서 발견 폼·도달 단계를 도출한다.
//

import SwiftUI

struct CollectionView: View {
    /// 발견한 생명체 목록. 외부 주입(기본값 = populated)으로 검수 가능.
    private let creatures: [Creature]
    /// 개체별 부화 후 Done한 집중 세션 수(진화 단계 파생). 기본은 0(갓 부화).
    private let completedSessionsSinceHatch: (Creature) -> Int
    @State private var selected: CreatureForm?
    /// 그리드 등장 애니메이션 토글.
    @State private var appeared = false

    /// 도감 전체 폼(변형 단위). 닭은 표정마다 별도 칸으로 수집된다.
    private let allForms = CreatureForm.all

    init(creatures: [Creature] = MockData.populated.creatures,
         completedSessionsSinceHatch: @escaping (Creature) -> Int = { _ in 0 }) {
        self.creatures = creatures
        self.completedSessionsSinceHatch = completedSessionsSinceHatch
    }

    /// 폼(변형 imageName) → 가장 최근 발견 개체(이름·부화일·대사용).
    private var discovered: [String: Creature] {
        var map: [String: Creature] = [:]
        for c in creatures where map[c.imageName] == nil { map[c.imageName] = c }
        return map
    }

    /// 이 폼에서 지금까지 도달한 최고 진화 단계. -1이면 아직 미발견(완전 잠금).
    /// 같은 변형을 여러 번 부화했으면 그중 최고 단계를 기억한다.
    private func reachedStage(_ form: CreatureForm) -> Int {
        creatures
            .filter { $0.imageName == form.imageName }
            .map { $0.evolutionStage(completedSessionsSinceHatch: completedSessionsSinceHatch($0)) }
            .max() ?? -1
    }

    private let columns = [GridItem(.flexible(), spacing: 12),
                           GridItem(.flexible(), spacing: 12),
                           GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            ThemedBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    header
                    if discovered.isEmpty { emptyHint }
                    grid
                }
                .padding(.horizontal, AppSpacing.section)
                .padding(.top, AppSpacing.elementTight)
                .padding(.bottom, AppSpacing.section)
            }
        }
        .sheet(item: $selected) { form in
            FormDetailSheet(form: form,
                            creature: discovered[form.imageName],
                            reachedStage: reachedStage(form))
        }
        .onAppear { withAnimation(.easeOut(duration: 0.4)) { appeared = true } }
    }

    // MARK: - 헤더 (제목 + 발견 진행 바)

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.elementTight) {
            Text("Collection")
                .font(.title.weight(.bold))
                .foregroundStyle(AppColor.textPrimary)
            HStack {
                Text("Friends discovered")
                    .font(AppFont.cardTitle)
                    .foregroundStyle(AppColor.textSecondary)
                Spacer()
                Text("\(discovered.count)/\(allForms.count)")
                    .font(AppFont.cardTitle.weight(.bold))
                    .foregroundStyle(AppColor.eggAccent)
            }
            DiscoveryBar(fraction: allForms.isEmpty ? 0 : Double(discovered.count) / Double(allForms.count))
        }
    }

    // MARK: - 빈 상태 안내 (부화 0마리)

    /// 발견 0일 때 헤더와 실루엣 도감 사이에 표시하는 온보딩 배너.
    private var emptyHint: some View {
        AppCard {
            VStack(spacing: AppSpacing.elementTight) {
                Text("🥚")
                    .font(.system(size: 40))
                Text("No friends hatched yet")
                    .font(AppFont.cardTitle.weight(.bold))
                    .foregroundStyle(AppColor.textPrimary)
                Text("Focus to hatch your first egg")
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.elementTight)
        }
    }

    // MARK: - 그리드 (발견 + 미발견 실루엣)

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(allForms.enumerated()), id: \.element.id) { index, form in
                Button { selected = form } label: {
                    CollectionCard(form: form,
                                   creature: discovered[form.imageName],
                                   reachedStage: reachedStage(form))
                }
                .buttonStyle(.plain)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.85)
                .animation(.spring(response: 0.45, dampingFraction: 0.8).delay(Double(index) * 0.04), value: appeared)
            }
        }
    }
}

/// 발견 진행 바. 채워진 비율만큼 골드 그라데이션.
private struct DiscoveryBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(AppColor.border)
                Capsule()
                    .fill(LinearGradient(colors: [AppColor.eggAccent.opacity(0.7), AppColor.eggAccent],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: 6)
    }
}

/// 도감 카드. 발견 폼이면 도달 최고 단계 아트, 미발견이면 실루엣. 하단에 등급 태그.
private struct CollectionCard: View {
    let form: CreatureForm
    /// 발견 개체(이름 표시용). nil이면 미발견.
    let creature: Creature?
    /// 도달한 최고 진화 단계(-1 = 미발견).
    let reachedStage: Int

    private var rarity: Rarity { form.rarity }
    private var isDiscovered: Bool { creature != nil }
    /// 발견 + 레어 이상이면 등급색으로 테두리·글로우 강조.
    private var emphasized: Bool { isDiscovered && rarity >= .rare }

    var body: some View {
        VStack(spacing: 8) {
            if let creature {
                // 그리드는 정적 idle 프레임(산만함 방지) — 도달 단계 아트를 반영한다.
                CreatureImage(imageName: creature.displayImageName(stage: reachedStage),
                              rarity: rarity, size: 64, stage: reachedStage)
            } else {
                CreatureImage(imageName: form.imageName, rarity: rarity, size: 64, silhouette: true)
            }
            Text(isDiscovered ? form.name : "???")
                .font(.caption2)
                .foregroundStyle(isDiscovered ? AppColor.textBody : AppColor.textDisabled)
                .lineLimit(1)
            RarityTag(rarity: rarity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.elementTight)
        .background(AppColor.cardBackground.opacity(isDiscovered ? 1 : 0.5))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .stroke(emphasized ? rarity.color : AppColor.border,
                        lineWidth: emphasized ? 1.5 : AppSpacing.borderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: emphasized ? rarity.color.opacity(0.35) : .clear, radius: 8)
    }
}

/// 등급 텍스트 태그. 일반=회색 · 고급=초록 · 레어=파랑 · 전설=금색(Rarity.color).
private struct RarityTag: View {
    let rarity: Rarity

    var body: some View {
        Text(rarity.label)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(rarity.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(rarity.color.opacity(0.14))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(rarity.color.opacity(0.5), lineWidth: 1))
    }
}

/// 카드 탭 시 상세 시트. 3단계 진화 스트립 + 이름 + 등급 태그 + 진행 안내.
/// 도달한 단계는 실제 아트(최고 단계는 모션), 아직 못 간 단계는 실루엣으로 궁금증을 남긴다.
private struct FormDetailSheet: View {
    let form: CreatureForm
    /// 발견 개체(이름·부화일·대사용). nil이면 완전 미발견.
    let creature: Creature?
    /// 도달한 최고 진화 단계(-1 = 미발견).
    let reachedStage: Int
    @State private var quote: String?

    private var isDiscovered: Bool { creature != nil }
    private var isComplete: Bool { reachedStage >= Creature.maxEvolutionStage }

    var body: some View {
        ZStack {
            ThemedBackground()
            VStack(spacing: AppSpacing.section) {
                EvolutionStageStrip(form: form, creature: creature, reachedStage: reachedStage)

                if let quote {
                    Text("“\(quote)”")
                        .font(AppFont.cardTitle)
                        .foregroundStyle(AppColor.textBody)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.element)
                        .padding(.vertical, 8)
                        .background(AppColor.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                        .overlay(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                            .stroke(AppColor.border, lineWidth: AppSpacing.borderWidth))
                }

                VStack(spacing: AppSpacing.elementTight) {
                    Text(isDiscovered ? form.name : "???")
                        .font(AppFont.screenTitle)
                        .foregroundStyle(AppColor.textPrimary)
                    RarityTag(rarity: form.rarity)

                    if !isDiscovered {
                        Text("You haven't met this friend yet")
                            .font(AppFont.body)
                            .foregroundStyle(AppColor.textSecondary)
                        Text("Focus to hatch an egg and meet them")
                            .font(AppFont.body)
                            .foregroundStyle(AppColor.textSecondary)
                    } else if !isComplete {
                        Text("Keep focusing to evolve to the next stage")
                            .font(AppFont.body)
                            .foregroundStyle(AppColor.textSecondary)
                    } else {
                        Text("Fully evolved ✨")
                            .font(AppFont.body)
                            .foregroundStyle(AppColor.eggAccent)
                    }

                    if let creature {
                        Text("Hatched · \(creature.hatchedAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(AppFont.body)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
            }
            .padding(AppSpacing.section)
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
        .onAppear {
            if let creature {
                quote = DialogueCatalog.greetingLines(for: creature.personality).randomElement()?.text
            }
        }
    }
}

/// 3단계 진화 가로 스트립. 도달 단계는 실제 아트(최고 단계만 모션), 미도달은 실루엣.
private struct EvolutionStageStrip: View {
    let form: CreatureForm
    let creature: Creature?
    let reachedStage: Int

    /// 단계 라벨(0=갓 부화 … max=최종 진화).
    private func label(_ stage: Int) -> String {
        if stage == 0 { return String(localized: "Just hatched") }
        if stage == Creature.maxEvolutionStage { return String(localized: "Final form") }
        return String(localized: "Stage \(stage)")
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: AppSpacing.elementTight) {
            ForEach(0...Creature.maxEvolutionStage, id: \.self) { stage in
                VStack(spacing: 6) {
                    cell(stage)
                    Text(label(stage))
                        .font(.caption2.weight(stage == reachedStage ? .bold : .regular))
                        .foregroundStyle(stage <= reachedStage ? AppColor.textBody : AppColor.textDisabled)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// 한 단계 셀. 도달했으면 아트(최고 단계만 애니메이션), 아니면 그 단계 실루엣.
    @ViewBuilder
    private func cell(_ stage: Int) -> some View {
        if stage <= reachedStage, let creature {
            CreatureImage(imageName: creature.displayImageName(stage: stage),
                          rarity: form.rarity, size: 88, stage: stage,
                          animated: stage == reachedStage)
        } else {
            CreatureImage(imageName: form.imageName, rarity: form.rarity,
                          size: 88, stage: stage, silhouette: true)
        }
    }
}

#Preview("populated") {
    CollectionView(creatures: MockData.populated.creatures)
        .preferredColorScheme(.dark)
}

#Preview("empty") {
    CollectionView(creatures: MockData.empty.creatures)
        .preferredColorScheme(.dark)
}
