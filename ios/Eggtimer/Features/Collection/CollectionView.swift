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
    @State private var selected: Creature?

    /// 도감 전체 종(등급 오름차순으로 표시).
    private let allSpecies = CreatureSpecies.allCases.sorted {
        $0.rarity != $1.rarity ? $0.rarity < $1.rarity : $0.weight > $1.weight
    }

    init(creatures: [Creature] = MockData.populated.creatures) {
        self.creatures = creatures
    }

    /// 종 → 가장 최근 발견 개체.
    private var discovered: [CreatureSpecies: Creature] {
        var map: [CreatureSpecies: Creature] = [:]
        for c in creatures where map[c.species] == nil { map[c.species] = c }
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
                    grid
                }
                .padding(.horizontal, AppSpacing.section)
                .padding(.top, AppSpacing.elementTight)
                .padding(.bottom, AppSpacing.section)
            }
        }
        .sheet(item: $selected) { CreatureDetailSheet(creature: $0) }
    }

    // MARK: - 헤더

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Collection")
                .font(.title.weight(.bold))
                .foregroundStyle(AppColor.textPrimary)
            Text("발견한 친구들 \(discovered.count)/\(allSpecies.count)")
                .font(AppFont.cardTitle)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    // MARK: - 그리드 (발견 + 미발견 실루엣)

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(allSpecies) { species in
                if let creature = discovered[species] {
                    Button { selected = creature } label: {
                        CreatureSlot(creature: creature)
                    }
                    .buttonStyle(.plain)
                } else {
                    LockedSlot(species: species)
                }
            }
        }
    }
}

/// 발견한 생명체 슬롯. 전설은 골드 테두리로 강조.
private struct CreatureSlot: View {
    let creature: Creature

    private var highlighted: Bool { creature.rarity == .legendary }

    var body: some View {
        VStack(spacing: 8) {
            CreatureImage(imageName: creature.displayImageName, rarity: creature.rarity, size: 64)
            Text(creature.name)
                .font(.caption2)
                .foregroundStyle(AppColor.textBody)
                .lineLimit(1)
            RarityDots(rarity: creature.rarity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.elementTight)
        .background(AppColor.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .stroke(highlighted ? AppColor.eggAccent : AppColor.border,
                        lineWidth: highlighted ? 1.5 : AppSpacing.borderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }
}

/// 미발견 슬롯(검은 실루엣 + "?").
private struct LockedSlot: View {
    let species: CreatureSpecies

    var body: some View {
        VStack(spacing: 8) {
            CreatureImage(imageName: species.silhouetteImageName,
                          rarity: species.rarity, size: 64, silhouette: true)
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
    /// 이 개체의 성격 대사 한 줄(시트 표시 동안 고정).
    @State private var quote: String?

    private var hatchedText: String {
        creature.hatchedAt.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        ZStack {
            AppColor.pageBackground.ignoresSafeArea()
            VStack(spacing: AppSpacing.section) {
                CreatureImage(imageName: creature.displayImageName, rarity: creature.rarity, size: 160)
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
                    if creature.isEvolved {
                        Text("진화 완료 ✨")
                            .font(AppFont.cardTitle)
                            .foregroundStyle(AppColor.eggAccent)
                    } else if creature.canEvolve {
                        Text("20분 집중하면 진화해요")
                            .font(AppFont.cardTitle)
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
