//
//  HatchBurstAssetTests.swift
//  EggtimerTests
//
//  부화 버스트 영상 에셋 회귀 검증. 이 연출은 "번들에 파일이 들어갔는가"와
//  "알파 채널이 살아있는가" 두 가지가 깨지기 쉬운데, 둘 다 실행해봐야만 보이는 문제라
//  여기서 미리 잡는다(알파가 빠지면 앱 배경 위에 불투명 사각형이 그대로 보인다).
//

import AVFoundation
import Foundation
import Testing
@testable import Eggtimer

struct HatchBurstAssetTests {

    @Test func videoIsBundled() {
        // 파일시스템 동기화 그룹이 .mov를 리소스로 실제 포함했는지(빌드 설정 회귀 방지).
        #expect(HatchBurstAsset.url != nil, "HatchBurst.mov가 앱 번들에 없다")
        #expect(HatchBurstAsset.isAvailable)
    }

    @Test func videoTrackContainsAlpha() async throws {
        // 알파가 빠진 채로 재인코딩되면 배경이 사각형으로 보인다 → 가장 중요한 회귀 가드.
        let url = try #require(HatchBurstAsset.url)
        let track = try #require(try await AVURLAsset(url: url).loadTracks(withMediaType: .video).first)
        let formats = try await track.load(.formatDescriptions)
        let hasAlpha = formats.contains { format in
            let ext = CMFormatDescriptionGetExtensions(format) as? [String: Any] ?? [:]
            return (ext["ContainsAlphaChannel"] as? Bool) == true
                || (ext["ContainsAlphaChannel"] as? NSNumber)?.boolValue == true
        }
        #expect(hasAlpha, "영상에 알파 채널이 없다 — 배경이 불투명 사각형으로 보인다")
    }

    @Test func declaredDurationMatchesFile() async throws {
        // triggerHatch가 이 길이만큼 기다렸다 캐릭터를 노출한다. 어긋나면 연출이 잘리거나 뜬다.
        let url = try #require(HatchBurstAsset.url)
        let actual = try await CMTimeGetSeconds(AVURLAsset(url: url).load(.duration))
        #expect(abs(actual - HatchBurstAsset.duration) < 0.05,
                "선언 길이 \(HatchBurstAsset.duration)s vs 실제 \(actual)s")
    }

    @Test func declaredPixelSizeMatchesFile() async throws {
        // 세로 566px가 crack PNG와 같아야 알 크기·바닥선이 전환 시 안 튄다.
        let url = try #require(HatchBurstAsset.url)
        let track = try #require(try await AVURLAsset(url: url).loadTracks(withMediaType: .video).first)
        let size = try await track.load(.naturalSize)
        #expect(abs(size.width - HatchBurstAsset.pixelSize.width) < 1)
        #expect(abs(size.height - HatchBurstAsset.pixelSize.height) < 1)
        #expect(abs(HatchBurstAsset.aspectRatio - 606.0 / 566.0) < 0.001)
    }

    @Test func transparentPixelsArePremultiplied() async throws {
        // 실제로 물렸던 버그: colorkey가 알파만 0으로 만들고 RGB에 원본 배경색(#25232A)을 남겼는데
        // 파일은 PremultipliedAlpha로 태깅돼, CoreAnimation이 `src + (1-a)*dst`로 합성하면서
        // 투명 영역마다 그 색이 **더해져** 앱 배경 위에 회색 판이 보였다.
        // 완전 투명(alpha==0) 픽셀의 RGB가 0이어야 그런 덧칠이 안 생긴다.
        let url = try #require(HatchBurstAsset.url)
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let image = try await generator.image(at: CMTime(seconds: 1.5, preferredTimescale: 600)).image

        #expect(image.alphaInfo == .premultipliedFirst || image.alphaInfo == .premultipliedLast,
                "알파가 premultiplied로 디코딩되지 않았다: \(image.alphaInfo)")

        let data = try #require(image.dataProvider?.data as Data?)
        let bytesPerPixel = image.bitsPerPixel / 8
        try #require(bytesPerPixel == 4)

        // 프레임 네 귀퉁이는 어떤 장면에서도 파편이 닿지 않는 완전 투명 영역이다.
        // 채널 순서(ARGB/BGRA)는 플랫폼마다 다르지만 완전 투명 픽셀은 알파까지 0이라
        // "4바이트 전부 작다"로 검사하면 순서를 몰라도 된다.
        // 임계값 8: HEVC 양자화 노이즈는 1~2까지 뜨지만, 이 버그가 났을 땐 37~42가 남았다.
        let noiseFloor: UInt8 = 8
        let corners = [(4, 4), (image.width - 5, 4), (4, image.height - 5), (image.width - 5, image.height - 5)]
        for (x, y) in corners {
            let offset = y * image.bytesPerRow + x * bytesPerPixel
            let pixel = Array(data[offset..<(offset + 4)])
            #expect(pixel.allSatisfy { $0 <= noiseFloor },
                    "(\(x),\(y)) 투명 픽셀에 색이 남아있다: \(pixel) — premultiply 필터 누락")
        }
    }

    @Test func canvasHeightMatchesCrackFrames() {
        // crack PNG 캔버스(590×566)와 세로가 같은지 — 같은 .frame(height:)에서 알 크기 동일.
        #expect(HatchBurstAsset.pixelSize.height == 566)
    }
}
