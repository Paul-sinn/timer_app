//
//  WorldPackSheet.swift
//  Eggtimer
//
//  유료 월드(팩) 구매 화면. 구매 **전에** 캐릭터 미리보기 + 확률표를 보여준다(App Review 3.1.1:
//  무작위 아이템은 구매 전 확률 공개). 숫자는 전부 `World`에서 파생 — 화면에 하드코딩하지 않는다.
//  가격은 StoreKit 상품에서 받는다(상품을 못 받으면 구매 버튼 비활성).
//

import SwiftUI
import StoreKit

struct WorldPackSheet: View {
    let world: World
    /// 구매(또는 복원)로 이 월드를 갖게 됐을 때. 호출부가 월드 전환을 이어서 처리한다.
    var onUnlocked: () -> Void = {}

    @Environment(ProAccess.self) private var pro
    @Environment(\.dismiss) private var dismiss
    @State private var product: Product?
    @State private var loading = true
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        ZStack {
            // 구매 시트는 테마와 무관하게 다크 고정(등급색이 밝은 배경에선 안 읽힌다 — 도감 상세 시트와 같은 규칙).
            AppColor.pageBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    titleBlock
                    lineup
                    oddsCard
                    actions
                }
                .padding(AppSpacing.section)
                .readableWidth()
            }
        }
        .presentationDetents([.large])
        .presentationSizing(.form)
        .preferredColorScheme(.dark)
        .environment(\.appTheme, .nest)
        .task { await loadProduct() }
    }

    // MARK: - 제목

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(world.name) World")
                .font(AppFont.screenTitle)
                .foregroundStyle(AppColor.textPrimary)
            Text("\(world.forms.count) new friends · yours forever")
                .font(AppFont.body)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    // MARK: - 캐릭터 미리보기 (등급 오름차순)

    private var lineup: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: AppSpacing.elementTight)],
                  spacing: AppSpacing.elementTight) {
            ForEach(world.forms) { form in
                VStack(spacing: 4) {
                    CreatureImage(imageName: form.imageName, rarity: form.rarity, size: 72)
                    Text(form.name)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColor.textBody)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
                }
            }
        }
    }

    // MARK: - 확률표 (3.1.1)

    private var oddsCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.elementTight) {
                Text("Hatch odds")
                    .font(AppFont.cardTitle)
                    .foregroundStyle(AppColor.textPrimary)
                ForEach(Rarity.allCases) { rarity in
                    let count = world.forms.filter { $0.rarity == rarity }.count
                    if count > 0 {
                        HStack {
                            Text(rarity.label)
                                .foregroundStyle(rarity.color)
                            Text("· \(count)")
                                .foregroundStyle(AppColor.textSecondary)
                            Spacer()
                            Text("\(world.tierWeight(rarity))%")
                                .foregroundStyle(AppColor.textPrimary)
                                .monospacedDigit()
                            Text("(\(Self.percent(world.singleDrawRate(of: rarity))) each)")
                                .foregroundStyle(AppColor.textSecondary)
                                .monospacedDigit()
                        }
                        .font(AppFont.body)
                    }
                }
                Divider().overlay(AppColor.border)
                VStack(alignment: .leading, spacing: 6) {
                    rule("Odds above are for one 25-minute focus. Longer focus rolls up to 4 times and gives you a friend you don't have yet first.")
                    if let cap = world.repeatCap {
                        rule("Until your collection is complete, the same friend appears at most \(cap) times.")
                    }
                    if let guarantee = world.guaranteedCompletionHatches {
                        rule("You'll collect all \(world.forms.count) within \(guarantee) hatches at most.")
                    }
                }
            }
        }
    }

    private func rule(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("•").foregroundStyle(AppColor.eggAccent)
            Text(text)
                .font(.footnote)
                .foregroundStyle(AppColor.textBody)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 12 → "12%", 8.5 → "8.5%".
    static func percent(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1))) + "%"
    }

    // MARK: - 구매 / 복원

    private var actions: some View {
        VStack(spacing: AppSpacing.elementTight) {
            if pro.owns(world) {
                Label("Unlocked", systemImage: "checkmark.seal.fill")
                    .font(AppFont.body.weight(.semibold))
                    .foregroundStyle(AppColor.success)
                    .frame(maxWidth: .infinity)
            } else if let product {
                PrimaryButton("Unlock · \(product.displayPrice)") { Task { await buy() } }
                    .disabled(busy)
            } else {
                Text(loading ? "Loading price…" : "Not available right now. Try again later.")
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(maxWidth: .infinity)
            }
            Button("Restore purchases") { Task { await restore() } }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)
                .disabled(busy)
            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func loadProduct() async {
        product = await pro.product(for: world)
        loading = false
    }

    private func buy() async {
        busy = true
        defer { busy = false }
        do {
            switch try await pro.purchase(world) {
            case .purchased:
                onUnlocked()
                dismiss()
            case .pending:
                message = String(localized: "Waiting for approval. It unlocks automatically once approved.")
            case .cancelled:
                break
            }
        } catch {
            message = String(localized: "Purchase failed. Please try again.")
        }
    }

    private func restore() async {
        busy = true
        defer { busy = false }
        await pro.restore()
        if pro.owns(world) {
            onUnlocked()
            dismiss()
        } else {
            message = String(localized: "No previous purchase found for this Apple ID.")
        }
    }
}

#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        WorldPackSheet(world: .christmas)
            .environment(ProAccess())
    }
}
