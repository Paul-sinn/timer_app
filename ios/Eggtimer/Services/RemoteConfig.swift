//
//  RemoteConfig.swift
//  Eggtimer
//
//  원격 기능 플래그(킬스위치). 앱 업데이트 없이 서버에서 기능을 끈다.
//
//  왜 필요한가: DB가 과부하로 흔들려도 클라이언트 동기화를 멈출 방법이 앱 업데이트뿐이었다.
//  심사 1~2일 + 배포 + 유저 업데이트를 기다리는 동안 서버는 계속 맞는다.
//  이제 public.app_config 의 sync_enabled 를 false 로 바꾸면 클라이언트가 원격 통신을 멈춘다.
//  앱은 로컬 SwiftData(단일 소스)로 정상 동작하고, 못 올린 항목은 스위치를 다시 켠 뒤
//  syncOnLogin() 의 합집합 머지가 그대로 올린다 — 데이터 손실 경로가 아니다.
//
//  판정 규칙(순수 로직 → RemoteConfigTests 가 검증):
//   - fail-open: 한 번도 못 받아봤는데 조회까지 실패하면 "켜짐"으로 둔다.
//     일시적 네트워크 장애가 전 유저의 동기화를 끊는 건 킬스위치보다 큰 사고다.
//   - 다만 이전에 "꺼짐"을 받은 적이 있으면 유지한다. 조회 실패로 킬스위치가 저절로 풀리면 안 된다.
//

import Foundation
import OSLog
import Supabase

// MARK: - 서버 행

/// public.app_config 한 행. value 는 jsonb 라 어떤 타입이든 올 수 있다.
nonisolated struct AppConfigRow: Decodable, Sendable, Equatable {
    let key: String
    /// value 를 Bool 로 읽은 결과. bool이 아니면 nil.
    let boolValue: Bool?

    enum CodingKeys: String, CodingKey {
        case key
        case value
    }

    init(key: String, boolValue: Bool?) {
        self.key = key
        self.boolValue = boolValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        // 미래에 문자열·숫자·객체 플래그가 추가돼도 전체 조회가 깨지면 안 된다.
        // bool로 못 읽히면 조용히 nil 로 두고 무시한다.
        boolValue = try? container.decode(Bool.self, forKey: .value)
    }
}

// MARK: - 플래그

/// 앱이 실제로 참조하는 플래그 묶음. 캐시 직렬화 대상이라 Codable.
nonisolated struct RemoteConfigFlags: Codable, Sendable, Equatable {
    /// 원격 동기화 허용 여부. 기본은 켜짐(fail-open).
    var isSyncEnabled: Bool

    static let syncEnabledKey = "sync_enabled"

    /// 서버에서 아무것도 못 받았을 때 쓰는 값.
    static let `default` = RemoteConfigFlags(isSyncEnabled: true)

    /// 서버 행 → 플래그. 모르는 키와 타입이 안 맞는 값은 무시하고 기본값을 유지한다.
    static func from(rows: [AppConfigRow]) -> RemoteConfigFlags {
        var flags = RemoteConfigFlags.default
        for row in rows where row.key == syncEnabledKey {
            if let value = row.boolValue { flags.isSyncEnabled = value }
        }
        return flags
    }

    /// 이번 조회 결과와 마지막으로 저장된 값으로 실제 적용할 플래그를 정한다.
    /// - Parameters:
    ///   - fetched: 이번 조회 결과(실패했으면 nil).
    ///   - cached: 직전에 성공적으로 받아 저장해 둔 값(없으면 nil).
    static func resolve(fetched: RemoteConfigFlags?, cached: RemoteConfigFlags?) -> RemoteConfigFlags {
        fetched ?? cached ?? .default
    }
}

// MARK: - 조회

/// app_config 조회 전용. 네트워크 레이어라 MainActor 에 묶지 않는다.
nonisolated struct RemoteConfigService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    /// 플래그 전체를 한 번에 읽는다. 행이 몇 개 없는 테이블이라 페이지네이션이 필요 없다.
    func fetchFlags() async throws -> RemoteConfigFlags {
        let rows: [AppConfigRow] = try await client.from("app_config")
            .select("key,value")
            .execute()
            .value
        return RemoteConfigFlags.from(rows: rows)
    }
}

// MARK: - 앱 전역 상태

/// 현재 적용 중인 플래그. 뷰가 관찰할 수 있게 @Observable.
@Observable
@MainActor
final class RemoteConfig {
    /// 지금 적용 중인 플래그.
    private(set) var flags: RemoteConfigFlags

    /// 원격 동기화가 허용되는지. 호출부는 이 값만 보면 된다.
    var isSyncEnabled: Bool { flags.isSyncEnabled }

    @ObservationIgnored private let service: RemoteConfigService
    @ObservationIgnored private let defaults: UserDefaults

    private static let cacheKey = "remoteConfig.flags"
    private static let log = Logger(subsystem: "com.paulsin.hatchly", category: "config")

    init(service: RemoteConfigService = RemoteConfigService(),
         defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
        // 앱을 켜자마자 직전 값으로 시작한다 — 조회 전에도 킬스위치가 유효해야 한다.
        self.flags = Self.loadCached(from: defaults) ?? .default
    }

    /// 서버에서 플래그를 다시 읽어 적용한다. 실패해도 throw 하지 않는다
    /// (설정 조회 실패가 동기화 흐름 자체를 막으면 안 된다).
    func refresh() async {
        let fetched = try? await service.fetchFlags()
        let cached = Self.loadCached(from: defaults)
        let resolved = RemoteConfigFlags.resolve(fetched: fetched, cached: cached)

        if let fetched {
            save(fetched)
        } else {
            Self.log.notice("remote config fetch failed; keeping \(resolved.isSyncEnabled ? "enabled" : "disabled", privacy: .public)")
        }

        if resolved != flags {
            Self.log.notice("remote config changed: syncEnabled=\(resolved.isSyncEnabled, privacy: .public)")
        }
        flags = resolved
    }

    // MARK: 캐시

    private static func loadCached(from defaults: UserDefaults) -> RemoteConfigFlags? {
        guard let data = defaults.data(forKey: cacheKey) else { return nil }
        // 캐시가 깨져 있어도 앱이 죽으면 안 된다 — nil 로 떨어뜨리고 기본값을 쓴다.
        return try? JSONDecoder().decode(RemoteConfigFlags.self, from: data)
    }

    private func save(_ flags: RemoteConfigFlags) {
        guard let data = try? JSONEncoder().encode(flags) else { return }
        defaults.set(data, forKey: Self.cacheKey)
    }
}
