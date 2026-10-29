//
//  Creature.swift
//  Eggtimer
//
//  부화한 생명체 인스턴스. 순수 Swift 값 타입(struct). SwiftData 미사용(Phase 0).
//  종(CreatureSpecies)에서 이름·등급을 파생하고, 부화 시점에 확정된 이미지 변형을 보관한다.
//  모든 종은 부화(0단계) 후 "Keep focusing" 1세션 Done마다 한 단계씩 진화하고,
//  maxEvolutionStage에 도달하면 최종 진화한다. 전용 진화 아트(백호·피닉스)는 최종 단계에서
//  이미지가 바뀌고, 그 외 종은 같은 아트 + 글로우·배지 연출로 단계를 표현한다.
//

import Foundation

struct Creature: Identifiable, Hashable {
    let id: UUID
    /// 종(이름·등급·이미지 풀의 출처).
    let species: CreatureSpecies
    /// 부화 시점에 확정된 기본 이미지 변형(빨간 토종닭은 표정 랜덤 고정).
    let imageName: String
    let hatchedAt: Date

    /// 최종 진화까지의 진화 횟수. 부화(0단계) 후 이만큼 진화하면 최종 진화.
    /// 3상태 진화: 0=갓 부화 → 1=진화 → 2=최종. 진화 1회마다 아트가 실제로 바뀌어 보상감을 준다.
    static let maxEvolutionStage = 2

    init(
        id: UUID = UUID(),
        species: CreatureSpecies,
        imageName: String? = nil,
        hatchedAt: Date
    ) {
        self.id = id
        self.species = species
        if let imageName {
            self.imageName = imageName
        } else {
            var generator = SystemRandomNumberGenerator()
            self.imageName = species.randomVariant(using: &generator)
        }
        self.hatchedAt = hatchedAt
    }

    var name: String { species.variantName(imageName: imageName) }
    var rarity: Rarity { species.rarity }
    /// 대사 성격(종 + 부화 시 확정 이미지 변형에서 파생).
    var personality: CreaturePersonality { species.personality(imageName: imageName) }

    /// 전용 최종 진화 아트를 가진 종인지(현재 백호·피닉스만). 그 외 종은 같은 아트 + 연출/배지로 단계 표현.
    var hasFinalArt: Bool { species.evolvedImageName != nil }

    /// 진화 단계(0=갓 부화 … maxEvolutionStage=최종). 부화 후 Done한 집중 세션 수로 파생.
    func evolutionStage(completedSessionsSinceHatch n: Int) -> Int {
        max(0, min(n, Creature.maxEvolutionStage))
    }

    /// 최종 진화 도달 여부.
    func isFinalEvolved(stage: Int) -> Bool { stage >= Creature.maxEvolutionStage }

    /// 화면에 그릴 이미지 에셋명. 최종 단계 + 전용 진화 아트 보유 종이면 진화 이미지,
    /// 그 외엔 기본 이미지(단계는 글로우·배지 연출로 표현).
    func displayImageName(stage: Int) -> String {
        if isFinalEvolved(stage: stage), let evolved = species.evolvedImageName { return evolved }
        return imageName
    }

    // MARK: - 부화

    /// 확률표에 따라 한 종을 뽑아 새 생명체를 부화시킨다.
    /// `draws`(집중 길이 보상, FocusReward)만큼 등급을 굴려 최고 등급을 채택한다(best-of-N). 기본 1.
    /// 그 뒤 등급업(`CreatureSpecies.upgradePercent`)을 굴린다. `upgraded`는 연출용(저장 안 함).
    static func hatch(draws: Int = 1, at date: Date = Date()) -> (creature: Creature, upgraded: Bool) {
        var generator = SystemRandomNumberGenerator()
        #if DEBUG
        // 개발자 강제 부화(마이페이지). 확률·draw를 무시하고 지정 종으로 부화한다. 릴리스엔 없음.
        if let forced = DebugHatch.forcedSpecies {
            let creature = Creature(species: forced, imageName: forced.randomVariant(using: &generator), hatchedAt: date)
            return (creature, DebugHatch.forceUpgrade)   // 종 고정 + 등급업 연출만 확인
        }
        // 강제 draw(best-of-N 검수용)·강제 등급업. Settings 시 실제 값 대신 이 값으로 굴린다. 릴리스엔 없음.
        return hatch(draws: DebugHatch.effectiveDraws(for: draws),
                     upgradePercent: DebugHatch.forceUpgrade ? 100 : CreatureSpecies.upgradePercent,
                     at: date, using: &generator)
        #else
        return hatch(draws: draws, at: date, using: &generator)
        #endif
    }

    /// 테스트 가능한 주입형 RNG 부화.
    static func hatch<G: RandomNumberGenerator>(
        draws: Int = 1, upgradePercent: Int = CreatureSpecies.upgradePercent,
        at date: Date = Date(), using generator: inout G
    ) -> (creature: Creature, upgraded: Bool) {
        let roll = CreatureSpecies.rollForHatch(draws: draws, upgradePercent: upgradePercent, using: &generator)
        let image = roll.species.randomVariant(using: &generator)
        return (Creature(species: roll.species, imageName: image, hatchedAt: date), roll.upgraded)
    }
}

#if DEBUG
/// DEBUG 전용 Force hatch. 마이페이지 개발자 섹션에서 종을 고르면 Next 부화부터 그 종만 나온다
/// (확률이 낮은 전설 등을 검수용으로 OK). UserDefaults에만 저장돼 릴리스 빌드엔 존재하지 않는다.
enum DebugHatch {
    private static let key = "debug.forcedHatchSpecies"
    private static let drawsKey = "debug.forcedDraws"

    /// 강제할 종. nil이면 Normal odds.
    static var forcedSpecies: CreatureSpecies? {
        get { UserDefaults.standard.string(forKey: key).flatMap { CreatureSpecies(rawValue: $0) } }
        set { UserDefaults.standard.setValue(newValue?.rawValue, forKey: key) }
    }

    /// 실제로 굴릴 draw 수. `Creature.hatch`와 부화 로그가 **같은 값**을 보도록 단일 출처로 둔다
    /// (따로 계산하면 로그가 거짓말을 하게 된다).
    static func effectiveDraws(for draws: Int) -> Int { forcedDraws ?? draws }

    /// 강제 등급업(연출 검수용). true면 전설만 빼고 매번 한 단계 오르고 "한 번 더 떨림"이 나온다.
    static var forceUpgrade: Bool {
        get { UserDefaults.standard.bool(forKey: upgradeKey) }
        set { UserDefaults.standard.set(newValue, forKey: upgradeKey) }
    }
    private static let upgradeKey = "debug.forceUpgrade"

    /// 강제 draw 횟수(best-of-N 검수용). nil이면 Actual focus length(FocusReward)로 계산한 draw 사용.
    static var forcedDraws: Int? {
        get {
            let v = UserDefaults.standard.integer(forKey: drawsKey)
            return v > 0 ? v : nil
        }
        set {
            if let newValue { UserDefaults.standard.set(newValue, forKey: drawsKey) }
            else { UserDefaults.standard.removeObject(forKey: drawsKey) }
        }
    }
}
#endif
