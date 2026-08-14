//
//  HatchBurstView.swift
//  Eggtimer
//
//  부화 순간 연출(알 → 폭발 → 캐릭터 전환의 가운데 토막). 1000줄짜리 HomeView에서 분리했다.
//  검수: DEBUG 빌드의 "10 sec (test)" 집중 시간으로 실제 부화를 태우거나,
//  연출만 반복해 보려면 `SIMCTL_CHILD_HATCH_BURST=1`로 런치한다(HatchBurstPreviewView).
//
//  기본 경로는 HEVC+알파 영상(60fps · 168프레임). 이전에는 PNG 7프레임을 갈아끼웠는데
//  폭발 구간이 초당 8프레임이라 뚝뚝 끊겼다. 영상은 같은 아트를 60fps로 담아 매끄럽다.
//  영상이 번들에 없으면 기존 PNG 시퀀스로 폴백한다(에셋 사고 시 연출이 사라지지 않게).
//

import AVFoundation
import SwiftUI

/// 부화 순간 연출. 기본은 HEVC+알파 영상(60fps · 168프레임 · 2.8초)을 1회 재생하고,
/// 영상이 번들에 없으면 기존 PNG 7프레임 시퀀스로 폴백한다(회귀 안전).
/// 영상·PNG 모두 crack 에셋과 세로 566px 캔버스를 공유해 알 축·바닥선이 안 튄다.
struct HatchBurstView: View {
    var height: CGFloat = 240

    /// 전체 재생 시간(초). triggerHatch가 이 시간 후 캐릭터를 노출한다(영상/PNG 폴백에 따라 달라짐).
    static var totalDuration: Double {
        HatchBurstAsset.isAvailable ? HatchBurstAsset.duration : HatchBurstFrameView.totalDuration
    }

    /// PNG 폴백 경로에서만 의미 있는 사전 로딩 대상.
    static var assetNames: [String] { HatchBurstFrameView.assetNames }

    var body: some View {
        if let player = HatchBurstPlayback.shared.player {
            AlphaVideoLayerView(player: player)
                .aspectRatio(HatchBurstAsset.aspectRatio, contentMode: .fit)
                .frame(height: height)
                .allowsHitTesting(false)
                .onAppear { HatchBurstPlayback.shared.restart() }
                .accessibilityLabel(Text("The egg is hatching"))
        } else {
            HatchBurstFrameView(height: height)
        }
    }
}

/// 부화 영상 재생기(단일 인스턴스). 부화는 드물게 일어나므로 플레이어를 미리 만들어 두고
/// 매번 처음으로 되감아 재생한다 — 그래야 첫 프레임이 검게 깜빡이지 않는다.
/// 영상에 오디오 트랙이 없고 isMuted라 유저가 듣던 음악을 끊지 않는다(AVAudioSession 건드리지 않음).
@MainActor
final class HatchBurstPlayback {
    static let shared = HatchBurstPlayback()

    /// 번들에 영상이 없으면 nil → 호출부가 PNG 시퀀스로 폴백.
    let player: AVPlayer?

    private init() {
        guard let url = HatchBurstAsset.url else {
            player = nil
            return
        }
        let p = AVPlayer(playerItem: AVPlayerItem(asset: AVURLAsset(url: url)))
        p.isMuted = true
        p.actionAtItemEnd = .pause                      // 1회 재생(루프 X) — 끝나면 캐릭터로 전환
        p.automaticallyWaitsToMinimizeStalling = false  // 로컬 파일이라 버퍼링 대기 불필요
        player = p
    }

    /// 디코더·파일 캐시 워밍. 화면 진입 시 한 번 불러 첫 재생 끊김을 없앤다.
    func prepare() {
        player?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// 처음으로 되감아 1회 재생.
    func restart() {
        guard let player else { return }
        Task { @MainActor in
            await player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            player.play()
        }
    }
}

/// 투명 배경 동영상을 그리는 레이어. SwiftUI `VideoPlayer`는 컨트롤과 불투명 배경을 강제로 깔아
/// 알파 합성이 안 되므로 AVPlayerLayer를 직접 쓴다.
private struct AlphaVideoLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.backgroundColor = .clear
        view.isOpaque = false
        let layer = view.playerLayer
        layer.player = player
        layer.videoGravity = .resizeAspect
        layer.isOpaque = false
        // 알파를 보존하는 픽셀 포맷으로 디코딩(기본 포맷은 알파를 버린다).
        layer.pixelBufferAttributes = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {}

    final class PlayerLayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

/// PNG 7프레임 폴백: abouttocrack 유지 → 금빛 충전 2프레임 → 폭발 4프레임.
/// 충전 2프레임(4-2egg·4-3egg)만 부드러운 opacity·scale 보간, 폭발 4프레임은 crossfade 없이 즉시 교체.
private struct HatchBurstFrameView: View {
    /// 한 프레임: 에셋명 · 유지 시간(초) · 금빛 충전 여부(부드러운 보간 대상).
    private struct Frame { let name: String; let duration: Double; let charge: Bool }

    // README 권장 타이밍. abouttocrack 0.30s 유지 → 충전(0.60/0.50) → 폭발(0.13/0.11/0.10/0.16).
    private static let sequence: [Frame] = [
        Frame(name: "abouttocrack_egg", duration: 0.30, charge: false),  // 벌어지기 직전 유지
        Frame(name: "4-2egg",           duration: 0.60, charge: true),   // 약한 금빛 충전
        Frame(name: "4-3egg",           duration: 0.50, charge: true),   // 강한 금빛 충전
        Frame(name: "4-4egg",           duration: 0.13, charge: false),  // 윗껍질 첫 파열
        Frame(name: "4-5eggopacity",    duration: 0.11, charge: false),  // 폭발 가속
        Frame(name: "4-6oppacity",      duration: 0.10, charge: false),  // 폭발 정점
        Frame(name: "4-7eggoppacity",   duration: 0.16, charge: false),  // 파편 확산·전환
    ]

    /// 전체 재생 시간(초). triggerHatch가 이 시간 후 몬스터를 노출한다.
    static var totalDuration: Double { sequence.reduce(0) { $0 + $1.duration } }

    /// 첫 재생 버벅임 방지용 사전 로딩 대상.
    static var assetNames: [String] { sequence.map(\.name) }

    var height: CGFloat = 240
    @State private var idx = 0
    @State private var chargePulse = false

    private var hasFrames: Bool { UIImage(named: Self.sequence[0].name) != nil }

    var body: some View {
        let frame = Self.sequence[min(idx, Self.sequence.count - 1)]
        Group {
            if hasFrames {
                Image(frame.name)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(height: height)
                    // 충전 프레임만 살짝 커지며 밝아진다. 폭발 프레임은 값 고정(즉시 교체).
                    .scaleEffect(frame.charge && chargePulse ? 1.04 : 1.0)
                    .opacity(frame.charge && !chargePulse ? 0.9 : 1.0)
            } else if UIImage(named: "borneffect") != nil {
                Image("borneffect")
                    .interpolation(.none).resizable().scaledToFit().frame(height: height)
            }
        }
        .onAppear {
            guard hasFrames else { return }
            Task { @MainActor in
                for (i, f) in Self.sequence.enumerated() {
                    if f.charge {
                        chargePulse = false
                        withAnimation(.easeInOut(duration: f.duration * 0.9)) {
                            idx = i
                            chargePulse = true
                        }
                    } else {
                        // 폭발·유지 프레임: 애니메이션 없이 즉시 교체.
                        var tx = Transaction(); tx.disablesAnimations = true
                        withTransaction(tx) { idx = i }
                    }
                    try? await Task.sleep(for: .seconds(f.duration))
                }
            }
        }
    }
}


#if DEBUG
/// 부화 리빌 검수 화면. CREATURE_GALLERY와 같은 방식의 DEBUG 전용 환경변수 훅이라
/// 프로덕션 UI에는 어떤 진입 버튼도 생기지 않는다(릴리스 빌드엔 이 코드 자체가 없다).
///   SIMCTL_CHILD_HATCH_BURST=1 xcrun simctl launch <device> com.paulsin.hatchly
///
/// 영상 + 화면 섬광 + 화면 흔들림을 **홈 화면과 같은 타이밍으로** 반복 재생한다.
/// 세션을 완주하지 않고도 연출 전체를 볼 수 있어야 아트·타이밍을 손볼 수 있다.
struct HatchBurstPreviewView: View {
    /// 재생을 처음부터 다시 트리거하는 키. 값이 바뀌면 뷰가 재생성되며 onAppear가 다시 돈다.
    @State private var take = 0
    @State private var showVideo = true
    @State private var showFlash = true
    @State private var shakeProgress: Double = 0
    @State private var revealOrigin: CGPoint?

    var body: some View {
        ZStack {
            ThemedBackground()
            VStack(spacing: AppSpacing.section) {
                Text(HatchBurstAsset.isAvailable ? "HEVC+alpha video" : "PNG fallback")
                    .font(AppFont.cardTitle)
                    .foregroundStyle(AppColor.textSecondary)
                // 영상이 내려간 뒤엔 알을 놓아 "빛 속에서 무언가 드러난다"를 확인한다.
                Group {
                    if showVideo {
                        HatchBurstView().id(take)
                    } else {
                        EggView(stageIndex: 0, height: 240)
                    }
                }
                .reportsHatchRevealOrigin()
                Text("take \(take)")
                    .font(AppFont.cardTitle)
                    .foregroundStyle(AppColor.textSecondary)
            }
            .screenShake(progress: shakeProgress)
        }
        .onPreferenceChange(HatchRevealOriginKey.self) { revealOrigin = $0 }
        .overlay { if showFlash { HatchRevealOverlay(origin: revealOrigin).id(take) } }
        .task {
            // 스크린샷 검수용 무한 반복. 홈 화면 triggerHatch와 같은 순서·간격.
            while !Task.isCancelled {
                showVideo = true
                showFlash = true
                try? await Task.sleep(for: .seconds(HatchReveal.impact))
                shakeProgress = 0
                withAnimation(.linear(duration: HatchReveal.shakeDuration)) { shakeProgress = 1 }
                try? await Task.sleep(for: .seconds(HatchReveal.creatureEntry - HatchReveal.impact))
                showVideo = false
                try? await Task.sleep(for: .seconds(HatchReveal.flashEnd - HatchReveal.creatureEntry))
                showFlash = false
                try? await Task.sleep(for: .seconds(0.8))
                take += 1
            }
        }
    }
}
#endif
