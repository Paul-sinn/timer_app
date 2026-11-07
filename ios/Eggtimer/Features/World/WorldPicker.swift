//
//  WorldPicker.swift
//  Eggtimer
//
//  홈 상단 월드 드롭다운. 고른 월드의 캐릭터만 부화한다(docs/CREATURES.md).
//  - 잠긴(미구매) 월드 → 구매 화면(확률표 포함)
//  - 키우던 알 진행·동료가 있으면 → 경고 후 리셋(도감·통계는 유지). 없으면 바로 전환.
//  알림·시트 수식어는 이 뷰에 붙인다(HomeView.body 수식어 사슬은 타입체커 한계 — CLAUDE.md 2026-10-23).
//

import SwiftUI

struct WorldPicker: View {
    /// 지금 월드(소유 확인을 거친 값).
    @Binding var selection: World
    /// 바꾸면 사라지는 진행(동료·진행 중 세션)이 있는지.
    let switchResets: Bool
    /// 진행 리셋(홈의 "새 알 받기"와 같은 동작).
    let reset: () -> Void

    @Environment(ProAccess.self) private var pro
    @Environment(\.appTheme) private var theme
    /// 경고를 띄운 전환 대상.
    @State private var pendingSwitch: World?
    /// 구매 화면 대상.
    @State private var shopWorld: World?
    /// 구매 화면에서 방금 산 월드. 시트가 완전히 닫힌 뒤 전환을 이어간다(닫히는 중엔 경고를 못 띄운다).
    @State private var justUnlocked: World?

    var body: some View {
        Menu {
            ForEach(World.allCases) { world in
                Button { choose(world) } label: {
                    if world == selection {
                        Label(world.name, systemImage: "checkmark")
                    } else if !pro.owns(world) {
                        Label(world.name, systemImage: "lock.fill")
                    } else {
                        Text(world.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selection.name)
                    .font(.caption.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            // 카드 톤 캡슐(다크 고정) — 옆 "New egg" 버튼과 같은 모양.
            .foregroundStyle(AppColor.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.cardBackground)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(theme.cardBorder, lineWidth: AppSpacing.borderWidth))
        }
        .accessibilityLabel(Text("World: \(selection.name)"))
        .alert(Text("Switch to \(pendingSwitch?.name ?? "") World?"),
               isPresented: Binding(get: { pendingSwitch != nil }, set: { if !$0 { pendingSwitch = nil } })) {
            Button("Switch", role: .destructive) {
                if let target = pendingSwitch {
                    reset()
                    selection = target
                }
                pendingSwitch = nil
            }
            Button("Cancel", role: .cancel) { pendingSwitch = nil }
        } message: {
            Text("Your current egg and friend will reset. Your collection and stats stay.")
        }
        .sheet(item: $shopWorld, onDismiss: {
            if let world = justUnlocked {
                justUnlocked = nil
                choose(world)
            }
        }) { world in
            WorldPackSheet(world: world) { justUnlocked = world }
        }
    }

    private func choose(_ world: World) {
        guard world != selection else { return }
        guard pro.owns(world) else { shopWorld = world; return }
        if switchResets { pendingSwitch = world } else { selection = world }
    }
}
