//
//  HatchBurstAsset.swift
//  Eggtimer
//
//  부화 버스트 영상(HEVC + 알파 채널) 에셋 기술자. 뷰에서 파일명·규격을 하드코딩하지 않게
//  단일 출처로 모아두고, 번들 포함 여부·알파 유지 여부를 유닛 테스트로 회귀 검증한다.
//
//  왜 GIF가 아니라 HEVC+알파인가: 앱 배경 위에 합성해야 하므로 투명도가 필수인데,
//  iOS가 네이티브로 재생하는 투명 동영상 포맷이 HEVC 알파(hvc1)다. 알파가 빠지면
//  배경이 불투명 사각형으로 보이므로 `videoTrackContainsAlpha` 테스트가 이를 막는다.
//
//  소스: images/eggs 원본과 동일 좌표계(942×1672)에서 crop=606:566:167:672 로 잘라낸 뒤
//  단색 배경(#25232A)을 키잉해 알파로 바꿨다. 세로 566px는 기존 crack PNG(590×566)와 같아
//  `.frame(height:)`가 같으면 알 크기·바닥선이 PNG 시퀀스와 정확히 일치한다.
//

import AVFoundation
import Foundation

enum HatchBurstAsset {
    static let resourceName = "HatchBurst"
    static let resourceExtension = "mov"

    /// 영상 캔버스(px). 세로는 crack PNG(590×566)와 동일 — 전환 시 알이 안 튄다.
    static let pixelSize = CGSize(width: 606, height: 566)

    /// 재생 길이(초). 실제 파일 길이와 어긋나면 테스트가 잡는다(연출 종료 → 캐릭터 등장 타이밍의 기준).
    static let duration: Double = 2.8

    /// 레이아웃용 가로세로비.
    static var aspectRatio: CGFloat { pixelSize.width / pixelSize.height }

    /// 번들 안 영상 URL. 없으면 nil → 호출부가 기존 PNG 시퀀스로 폴백한다.
    static var url: URL? {
        Bundle.main.url(forResource: resourceName, withExtension: resourceExtension)
    }

    static var isAvailable: Bool { url != nil }
}
