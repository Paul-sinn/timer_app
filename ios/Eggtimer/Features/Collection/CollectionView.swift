//
//  CollectionView.swift
//  Eggtimer
//
//  컬렉션 탭. 다크+골드 톤. "발견한 친구들 n/7" + 3열 그리드.
//  도감 전체 7종(CreatureSpecies)을 항상 나열한다.
//  - 발견한 종: 실제 캐릭터 카드(진화 종은 진화 이미지).
//  - 미발견 종: 검은 실루엣 + "?" (픽셀 톤).
//  데이터는 주입된 [Creature](기본 populated)에서 발견 종을 도출한다.
//

import SwiftUI

struct CollectionView: View {
    /// 발견한 생명체 목록. 외부 주입(기본값 = populated)으로 검수 가능.
    private let creatures: [Creature]
    /// 개체별 부화 후 완료한 집중 세션 수(진화 단계 파생). 기본은 0(갓 부화).
    private let completedSessionsSinceHatch: (Creature) -> Int
    @State private var selected: Creature?
    /// 그리드 등장 애니메이션 토글.
    @State private var appeared = false

    /// 도감 전체 폼(변형 단위). 닭은 표정마다 별도 칸으로 수집된다.
    private let allForms = CreatureForm.all

    init(creatures: [Creature] = MockData.populated.creatures,
         completedSessionsSinceHatch: @escaping (Creature) -> Int = { _ in 0 }) {
        self.creatures = creatures
        self.completedSessionsSinceHatch = completedSessionsSinceHatch
    }

    /// 폼(변형 imageName) → 가장 최근 발견 개체.
    private var discovered: [String: Creature] {
        var map: [String: Creature] = [:]
        for c in creatures where map[c.imageName] == nil { map[c.imageName] = c }
        return map
    }

    private let columns = [GridItem(.flexible(), spacing: 12),
                           GridItem(.flexible(), spacing: 12),
                           GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            AppColor.pageBackground.ignoresSafeArea()

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
        .sheet(item: $selected) { c in
            CreatureDetailSheet(creature: c,
                                stage: c.evolutionStage(completedSessionsSinceHatch: completedSessionsSinceHatch(c)))
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
                Text("발견한 친구들")
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
                Text("아직 부화한 친구가 없어요")
                    .font(AppFont.cardTitle.weight(.bold))
                    .foregroundStyle(AppColor.textPrimary)
                Text("집중하면 알이 부화해요")
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
                Group {
                    if let creature = discovered[form.imageName] {
                        Button { selected = creature } label: {
                            CreatureSlot(creature: creature,
                                         stage: creature.evolutionStage(completedSessionsSinceHatch: completedSessionsSinceHatch(creature)))
                        }
                        .buttonStyle(.plain)
                    } else {
                        LockedSlot(form: form)
                    }
                }
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

/// 발견한 생명체 슬롯. 등급색 글로우 + 레어 이상 테두리 강조.
private struct CreatureSlot: View {
    let creature: Creature
    /// 진화 단계(0…max).
    var stage: Int = 0

    private var rarity: Rarity { creature.rarity }
    /// 레어 이상이면 등급색으로 테두리·글로우 강조.
    private var emphasized: Bool { rarity >= .rare }

    var body: some View {
        VStack(spacing: 8) {
            CreatureImage(imageName: creature.displayImageName(stage: stage), rarity: rarity, size: 64)
            Text(creature.name)
                .font(.caption2)
                .foregroundStyle(AppColor.textBody)
                .lineLimit(1)
            if stage > 0 {
                EvolutionBadge(stage: stage, compact: true)
            } else {
                RarityDots(rarity: rarity)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.elementTight)
        .background(AppColor.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .stroke(emphasized ? rarity.color : AppColor.border,
                        lineWidth: emphasized ? 1.5 : AppSpacing.borderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: emphasized ? rarity.color.opacity(0.35) : .clear, radius: 8)
    }
}

/// 미발견 슬롯(검은 실루엣 + "?").
private struct LockedSlot: View {
    let form: CreatureForm

    var body: some View {
        VStack(spacing: 8) {
            CreatureImage(imageName: form.imageName,
                          rarity: form.rarity, size: 64, silhouette: true)
            Text("???")
                .font(.caption2)
                .foregroundStyle(AppColor.textDisabled)
            RarityDots(rarity: nil)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.elementTight)
        .background(AppColor.cardBackground.opacity(0.5))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .stroke(AppColor.border, lineWidth: AppSpacing.borderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }
}

/// 카드 하단 레어도 점 표시(등급만큼 골드 점, 나머지는 회색).
private struct RarityDots: View {
    let rarity: Rarity?

    private var filled: Int { rarity?.dots ?? 0 }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(i < filled ? AppColor.eggAccent : AppColor.border)
                    .frame(width: 4, height: 4)
            }
        }
    }
}

/// 셀 탭 시 표시되는 상세 시트(이미지 · 이름 · 레어도 · 부화일 · 진화 여부).
private struct CreatureDetailSheet: View {
    let creature: Creature
    /// 진화 단계(0…max).
    var stage: Int = 0
    /// 이 개체의 성격 대사 한 줄(시트 표시 동안 고정).
    @State private var quote: String?

    private var hatchedText: String {
        creature.hatchedAt.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        ZStack {
            AppColor.pageBackground.ignoresSafeArea()
            VStack(spacing: AppSpacing.section) {
                CreatureImage(imageName: creature.displayImageName(stage: stage), rarity: creature.rarity, size: 160)
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
                    Text(creature.name)
                        .font(AppFont.screenTitle)
                        .foregroundStyle(AppColor.textPrimary)
                    Text(creature.rarity.label)
                        .font(AppFont.cardTitle)
                        .foregroundStyle(creature.rarity.color)
                    EvolutionBadge(stage: stage)
                    if !creature.isFinalEvolved(stage: stage) {
                        Text("이어서 집중하면 진화해요")
                            .font(AppFont.body)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    Text("부화일 · \(hatchedText)")
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            .padding(AppSpacing.section)
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
        .onAppear {
            quote = DialogueCatalog.greetingLines(for: creature.personality).randomElement()?.text
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
