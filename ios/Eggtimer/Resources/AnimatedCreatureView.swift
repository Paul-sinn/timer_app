//
//  AnimatedCreatureView.swift
//  Eggtimer
//
//  캐릭터의 idle/action 2프레임을 번갈아 그리는 재사용 컴포넌트.
//  홈(동료)·컬렉션(상세)·부화 시트가 전부 이걸 쓰고, 에셋명은 CreatureArt만 안다.
//
//  프레임 교체는 `.task` 안의 루프(`Task.sleep`)로 idle↔action `@State`를 토글한다.
//   → `.task(id:)`를 (base·stage·재생여부·scenePhase)로 키잉하므로, 뷰가 재생성되거나
//     단계가 바뀌거나 백그라운드로 가면 SwiftUI가 이전 task를 자동 Cancel한다
//     (타이머 중복 생성·누수 없음). 백그라운드/Reduce Motion은 shouldAnimate에서 차단.
//   ※ 이전엔 TimelineView + timeIntervalSinceReferenceDate 기반 커스텀 스케줄을 썼는데,
//     2026년엔 그 절댓값이 ~8e8이라 period로 나눈 소수부의 double 정밀도(ULP≈2.4e-7)가
//     부족해 캐릭터·위상에 따라 프레임이 한쪽에 갇혔다. 작은 초 단위만 다루는 sleep 루프로 교체.
//
//  프레임 교체에는 어떤 암시적 애니메이션도 걸지 않는다(`.transaction { $0.animation = nil }`).
//  부모(홈 진화 연출 등)의 애니메이션 트랜잭션이 흘러들어와 두 프레임이 크로스페이드로
//  겹쳐 보이면 픽셀아트가 뭉개지기 때문. 움직임은 프레임 교체 + 1~3pt 정수 오프셋으로만 만든다.
//

import SwiftUI

struct AnimatedCreatureView: View {
    /// 변형 에셋명(예: "ChickenBro"). 애니메이션 세트가 없으면 이 이름 그대로 한 장을 그린다.
    let base: String
    /// 게임 진화 단계(0…`Creature.maxEvolutionStage`).
    var stage: Int = 0
    /// false면 idle 프레임으로 고정(컬렉션 그리드처럼 조용해야 하는 자리).
    var animated: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var frame: CreatureMotionFrame = .idle

    private var timing: CreatureMotionTiming { CreatureArt.timing(base: base, stage: stage) }

    /// 이 단계에서 실제로 그릴 두 프레임의 에셋명. 한 장이라도 번들에 없으면 nil →
    /// 기존 단일 이미지(`base`)로 폴백해 화면이 비지 않게 한다.
    /// (세트 유무를 매번 따로 묻지 않도록 해석 결과를 한 번에 만든다.)
    private var resolvedFrames: (idle: String, action: String)? {
        guard let idle = CreatureArt.animatedAssetName(base: base, stage: stage, frame: .idle),
              let action = CreatureArt.animatedAssetName(base: base, stage: stage, frame: .action),
              UIImage(named: idle) != nil, UIImage(named: action) != nil
        else { return nil }
        return (idle, action)
    }

    /// Reduce Motion·백그라운드·`animated == false`·세트 없음이면 움직이지 않는다.
    private var shouldAnimate: Bool {
        animated && !reduceMotion && scenePhase == .active && resolvedFrames != nil
    }

    var body: some View {
        let frames = resolvedFrames
        let name = frames.map { frame == .action ? $0.action : $0.idle } ?? base

        Image(name)
            .interpolation(.none)          // 픽셀아트 선명하게(업스케일 시 뭉개짐 방지)
            .resizable()
            .scaledToFit()                 // 가로·세로 강제 늘림 금지
            .offset(y: frame == .action ? -timing.lift : 0)
            .transaction { $0.animation = nil }   // 프레임 전환은 항상 즉시(크로스페이드 금지)
            // 키가 바뀌면(단계·재생여부·앱 상태) 이전 루프는 Cancel되고 새로 Start된다.
            .task(id: "\(base)|\(stage)|\(shouldAnimate)|\(scenePhase)") {
                await runMotionLoop()
            }
    }

    /// idle을 길게, action을 짧게 번갈아 토글. Cancel되면 루프 종료(뷰 소멸·단계 변경·백그라운드).
    private func runMotionLoop() async {
        guard shouldAnimate else { frame = .idle; return }
        frame = .idle

        // 같은 화면의 여러 캐릭터가 한 박자로 움직이지 않게 Start 위상을 살짝 어긋나게 한다.
        let stagger = CreatureArt.phaseOffset(base: base, stage: stage) * timing.period
        if await sleep(seconds: stagger) == false { return }

        while !Task.isCancelled {
            frame = .idle
            if await sleep(seconds: timing.idle) == false { return }
            frame = .action
            if await sleep(seconds: timing.action) == false { return }
        }
    }

    /// Cancel를 존중하는 sleep. Cancel 시 false를 돌려 루프를 끊는다.
    private func sleep(seconds: Double) async -> Bool {
        guard seconds > 0 else { return true }
        do {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return true
        } catch {
            return false
        }
    }
}

#if DEBUG
#Preview("모션 - 헬창닭 3단계") {
    ZStack {
        AppColor.pageBackground.ignoresSafeArea()
        AnimatedCreatureView(base: "ChickenBro", stage: 3)
            .frame(height: 240)
    }
    .preferredColorScheme(.dark)
}
#endif
