//
//  FocusNotifier.swift
//  Eggtimer
//
//  로컬 알림(Local Notification) 헬퍼. 집중 타이머는 타임스탬프 기반이라 앱이 백그라운드여도
//  계속 흘러간다 → 화면 밖에서 부화/휴식 시점이 와도 사용자가 알 수 없다.
//  그래서 백그라운드 진입 시 "다음 전환(부화/휴식 종료)까지 남은 실시간"에 1회 알림을 예약하고,
//  포그라운드 복귀·일시정지·중단·완료 시 예약을 취소한다.
//

import Foundation
import UserNotifications

/// 집중 세션 로컬 알림(부화/휴식 종료). 상태 없는 정적 유틸.
enum FocusNotifier {
    /// 예약 식별자(단일 — 항상 1건만 유지).
    private static let identifier = "focus_next_event"

    /// 현재 알림 권한 상태(설정 토글의 거부 안내 분기용).
    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// 알림 권한 요청(미결정일 때만 시스템 프롬프트). 첫 집중 시작 시 호출.
    static func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// `after`초 뒤에 알림 1건 예약(기존 예약은 대체). 권한 미허용이면 무시된다.
    /// - Parameters:
    ///   - title/body: 알림 문구.
    ///   - after: 남은 실시간(초). 0 이하면 예약하지 않는다.
    static func schedule(title: String, body: String, after seconds: Int) {
        guard seconds > 0 else { return }
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    /// 예약된 집중 알림 취소(포그라운드 복귀·일시정지·중단·완료 시).
    static func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
