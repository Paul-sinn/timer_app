//
//  BatteryMonitor.swift
//  Eggtimer
//
//  충전 상태 감지(A+ 기믹). 충전기를 꽂으면 집중 중 알이 "찌릿"하며 부화가 살짝 가속된다.
//  UIDevice 배터리 모니터링 — 별도 권한/엔타이틀먼트 불필요. 시뮬레이터는 항상 unplugged(실기기 검증).
//

import UIKit

@Observable
@MainActor
final class BatteryMonitor {
    /// Charging(케이블 연결)인지. 충전 Done(.full)도 연결 상태로 본다.
    private(set) var isCharging: Bool = false

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        update()
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.update() }
        }
    }

    private func update() {
        switch UIDevice.current.batteryState {
        case .charging, .full: isCharging = true
        default:               isCharging = false
        }
    }
}
