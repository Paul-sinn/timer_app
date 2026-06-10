//
//  CollectionView.swift
//  Eggtimer
//
//  컬렉션 탭 화면(지금까지 부화한 생명체 그리드). UI_GUIDE: 카드/그리드, 좌측 정렬 기본,
//  레어 이상은 강조. Phase 0(UI 더미): 데이터는 주입된 [Creature](기본 populated)만 사용한다.
//  검수를 위해 빈 상태(empty)와 채움 상태(populated)를 모두 렌더한다.
//

import SwiftUI

struct CollectionView: View {
    /// 그리드에 그릴 생명체 목록. 외부 주입(기본값 = populated)으로 검수 가능.
    private let creatures: [Creature]
    /// 상세 시트로 띄울 선택된 생명체.
    @State private var selected: Creature?

    init(creatures: [Creature] = MockData.populated.creatures) {
        self.creatures = creatures
    }

    private let columns = [
        GridItem(.adaptive(minimum: 110), spacing: AppSpacing.element)
    ]

    var body: some View {
        ZStack {
            AppColor.pageBackground.ignoresSafeArea()

            if creatures.isEmpty {
                emptyState
            } else {
                grid
            }
        }
        .sheet(item: $selected) { creature in
            CreatureDetailSheet(creature: creature)
        }
    }

    // MARK: - 그리드

    private var grid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                SectionHeader("컬렉션")

                LazyVGrid(columns: columns, spacing: AppSpacing.element) {
                    ForEach(creatures) { creature in
                        Button {
                            selected = creature
                        } label: {
                            CreatureCell(creature: creature)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.section)
            .padding(.vertical, AppSpacing.section)
        }
    }

    // MARK: - 빈 상태

    private var emptyState: some View {
        VStack(spacing: AppSpacing.element) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(AppColor.textDisabled)
            Text("아직 부화한 생명체가 없어요")
                .font(AppFont.body)
                .foregroundStyle(AppColor.textBody)
            Text("집중을 시작해 첫 알을 부화시켜 보세요")
                .font(AppFont.cardTitle)
                .foregroundStyle(AppColor.textSecondary)
        }
        .padding(AppSpacing.section)
    }
}

/// 생명체 한 마리를 표시하는 그리드 셀(이미지 + 이름 + 레어도 배지).
private struct CreatureCell: View {
    let creature: Creature

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.elementTight) {
                CreatureImage(imageName: creature.imageName, rarity: creature.rarity, size: 96)
                    .frame(maxWidth: .infinity)

                Text(creature.name)
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)

                RarityBadge(rarity: creature.rarity)
            }
        }
    }
}

/// 레어도 배지. AppColor 토큰만 사용(레어도별 색). 레어 이상은 색으로 자연스럽게 강조된다.
private struct RarityBadge: View {
    let rarity: Rarity

    var body: some View {
        Text(rarity.label)
            .font(AppFont.cardTitle)
            .foregroundStyle(rarity.color)
            .padding(.horizontal, AppSpacing.elementTight)
            .padding(.vertical, 4)
            .background(rarity.color.opacity(0.18))
            .overlay(
                Capsule().stroke(rarity.color.opacity(0.5), lineWidth: AppSpacing.borderWidth)
            )
            .clipShape(Capsule())
    }
}

/// 셀 탭 시 표시되는 더미 상세 시트(이름·레어도·부화일).
private struct CreatureDetailSheet: View {
    let creature: Creature

    private var hatchedText: String {
        creature.hatchedAt.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        ZStack {
            AppColor.pageBackground.ignoresSafeArea()

            VStack(spacing: AppSpacing.section) {
                CreatureImage(imageName: creature.imageName, rarity: creature.rarity, size: 160)

                VStack(spacing: AppSpacing.elementTight) {
                    Text(creature.name)
                        .font(AppFont.screenTitle)
                        .foregroundStyle(AppColor.textPrimary)
                    RarityBadge(rarity: creature.rarity)
                    Text("부화일 · \(hatchedText)")
                        .font(AppFont.body)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            .padding(AppSpacing.section)
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
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
