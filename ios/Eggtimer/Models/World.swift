//
//  World.swift
//  Eggtimer
//
//  월드(팩) = 캐릭터 목록 + 등급 확률 + 추첨 규칙 + 판매 상품의 단일 출처. 기획: docs/CREATURES.md.
//  다음 팩은 case 하나와 아래 숫자만 채우면 된다 — 팩 이름으로 분기하는 코드를 화면에 쓰지 말 것.
//  선택한 월드는 UserDefaults(`selectedWorld`)에만 저장한다 → SwiftData 스키마 변경 없음.
//

import Foundation

enum World: String, CaseIterable, Identifiable, Sendable {
    case classic      // 기본 7종(무료)
    case christmas    // 크리스마스 10종(유료, 평생 소장)

    var id: String { rawValue }

    var name: String {
        switch self {
        case .classic:   return String(localized: "Classic")
        case .christmas: return String(localized: "Christmas")
        }
    }

    /// 이 월드에서 부화하는 종. `CreatureSpecies` 선언 순서(= 등급 오름차순)를 따른다.
    var species: [CreatureSpecies] { CreatureSpecies.allCases.filter { $0.world == self } }

    /// 도감 칸(종 × 이미지 변형).
    var forms: [CreatureForm] {
        species.flatMap { sp in sp.imageVariants.map { CreatureForm(species: sp, imageName: $0) } }
    }

    /// 등급 확률(%). 월드마다 합 100.
    func tierWeight(_ rarity: Rarity) -> Int {
        switch self {
        case .classic:
            return rarity.tierWeight
        case .christmas:
            switch rarity {
            case .common:    return 48
            case .uncommon:  return 30
            case .rare:      return 16
            case .legendary: return 6
            }
        }
    }

    /// 아직 못 모은 칸이 남아 있는 동안, 같은 칸이 나올 수 있는 최대 횟수. nil = 제한 없음.
    var repeatCap: Int? {
        switch self {
        case .classic:   return nil   // 기존 규칙 그대로(로드맵 K=5는 1.1 별도 작업)
        case .christmas: return 3
        }
    }

    /// 여러 번 굴린 결과 중 아직 없는 칸을 등급보다 먼저 고른다(흔함이 귀해지는 역전 방지).
    var prefersUndiscovered: Bool {
        switch self {
        case .classic:   return false
        case .christmas: return true
        }
    }

    /// 앱 안 결제 상품 ID(비소모성). nil = 무료. **App Store Connect에 같은 ID로 등록해야 한다.**
    var productID: String? {
        switch self {
        case .classic:   return nil
        case .christmas: return "com.paulsin.hatchly.world.christmas"
        }
    }

    /// 천장이 있으면 운이 가장 나빠도 이 횟수 안에 도감이 완성된다: 천장 × (칸 − 1) + 1.
    var guaranteedCompletionHatches: Int? {
        repeatCap.map { $0 * (forms.count - 1) + 1 }
    }

    /// 뽑기 1번일 때 해당 등급 칸 하나가 나올 확률(%). 등급 안 비중이 같을 때의 확률 안내용.
    func singleDrawRate(of rarity: Rarity) -> Double {
        let inTier = forms.filter { $0.rarity == rarity }.count
        return inTier == 0 ? 0 : Double(tierWeight(rarity)) / Double(inTier)
    }

    /// 저장된 선택값 → 실제로 쓸 월드. 모르는 값이거나 소유하지 않았으면(환불 등) 기본 월드.
    static func resolved(_ raw: String, owns: (World) -> Bool) -> World {
        guard let world = World(rawValue: raw), owns(world) else { return .classic }
        return world
    }

    /// 이번 부화에 나올 수 있는 칸. 도감 미완성이면 천장에 닿은 칸을 뺀다(천장 ≥ 1이라 미보유 칸은 항상 남는다).
    func drawableForms(counts: [String: Int]) -> [CreatureForm] {
        let all = forms
        guard let cap = repeatCap,
              all.contains(where: { counts[$0.imageName, default: 0] == 0 }) else { return all }
        return all.filter { counts[$0.imageName, default: 0] < cap }
    }
}
