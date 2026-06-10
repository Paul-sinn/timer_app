//
//  CollectionView.swift
//  Eggtimer
//
//  컬렉션 탭. 다크+골드 톤. "발견한 친구들 n/12" + 3열 그리드.
//  발견한 생명체는 카드로, 미발견 슬롯은 잠금 실루엣(자물쇠 + ???)으로 표시한다.
//  Phase 0(UI 더미): 데이터는 주입된 [Creature](기본 populated)만 사용한다.
//  검수를 위해 빈 상태(empty)와 채움 상태(populated)를 모두 렌더한다.
//

import SwiftUI

struct CollectionView: View {
    /// 발견한 생명체 목록. 외부 주입(기본값 = populated)으로 검수 가능.
    private let creatures: [Creature]
    /// 전체 도감 슬롯 수(미발견은 잠금 표시).
    private let totalSlots = 12
    @State private var selected: Creature?

    init(creatures: [Creature] = MockData.populated.creatures) {
        self.creatures = creatures
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
            Text("발견한 친구들 \(creatures.count)/\(totalSlots)")
                .font(AppFont.cardTitle)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    // MARK: - 그리드 (발견 + 잠금 슬롯)

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<totalSlots, id: \.self) { i in
                if i < creatures.count {
                    Button { selected = creatures[i] } label: {
                        CreatureSlot(creature: creatures[i])
                    }
                    .buttonStyle(.plain)
                } else {
                    LockedSlot()
                }
            }
        }
    }
}

/// 발견한 생명체 슬롯. 레어 이상은 골드 테두리로 강조.
private struct CreatureSlot: View {
    let creature: Creature

    private var highlighted: Bool { creature.rarity == .epic || creature.rarity == .legendary }

    var body: some View {
        VStack(spacing: 8) {
            CreatureImage(imageName: creature.imageName, rarity: creature.rarity, size: 64)
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

/// 미발견 잠금 슬롯(실루엣 + 자물쇠 + ???).
private struct LockedSlot: View {
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                    .fill(Color.white.opacity(0.03))
                    .frame(width: 64, height: 64)
                Image(systemName: "lock.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AppColor.textDisabled)
            }
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

/// 카드 하단 레어도 점 표시(레어도 등급만큼 골드 점, 나머지는 회색).
private struct RarityDots: View {
    let rarity: Rarity?

    private var filled: Int {
        switch rarity {
        case .common: return 1
        case .rare: return 2
        case .epic: return 3
        case .legendary: return 4
        case nil: return 0
        }
    }

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

/// 셀 탭 시 표시되는 더미 상세 시트(이미지 · 이름 · 레어도 · 부화일).
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
                    Text(creature.rarity.label)
                        .font(AppFont.cardTitle)
                        .foregroundStyle(creature.rarity.color)
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
