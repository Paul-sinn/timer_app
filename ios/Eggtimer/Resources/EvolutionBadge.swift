//
//  EvolutionBadge.swift
//  Eggtimer
//
//  생명체 진화 단계 배지. 전용 진화 아트가 아직 없는 단계도 "진화한 느낌"을 주기 위해
//  단계 점(pip) + 라벨로 진행도를 보여준다. 최종 단계면 골드 "최종 진화" 강조.
//  홈(동료)·컬렉션(슬롯/상세) 공용.
//

import SwiftUI

struct EvolutionBadge: View {
    /// 현재 진화 단계(0…Creature.maxEvolutionStage).
    let stage: Int
    /// 컴팩트(컬렉션 셀)면 라벨 없이 점만.
    var compact: Bool = false

    private var maxStage: Int { Creature.maxEvolutionStage }
    private var isFinal: Bool { stage >= maxStage }

    var body: some View {
        if compact {
            pips
        } else {
            HStack(spacing: 6) {
                pips
                Text(isFinal ? "최종 진화 ✨" : "진화 \(stage)/\(maxStage)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isFinal ? AppColor.eggAccent : AppColor.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(AppColor.cardBackground)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isFinal ? AppColor.eggAccent : AppColor.border,
                                      lineWidth: AppSpacing.borderWidth))
        }
    }

    /// 단계만큼 채워진 점(채운 점=골드, 빈 점=테두리색).
    private var pips: some View {
        HStack(spacing: 3) {
            ForEach(0..<maxStage, id: \.self) { i in
                Circle()
                    .fill(i < stage ? AppColor.eggAccent : AppColor.border)
                    .frame(width: compact ? 5 : 6, height: compact ? 5 : 6)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        EvolutionBadge(stage: 0)
        EvolutionBadge(stage: 1)
        EvolutionBadge(stage: 2)
        EvolutionBadge(stage: 3)
        EvolutionBadge(stage: 2, compact: true)
    }
    .padding()
    .background(AppColor.pageBackground)
    .preferredColorScheme(.dark)
}
