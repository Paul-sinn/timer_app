//
//  RemoteConfigTests.swift
//  EggtimerTests
//
//  킬스위치(원격 기능 플래그)의 순수 판정 로직 검증.
//  네트워크·SupabaseClient는 테스트하지 않는다(프로젝트 규칙: 순수 로직만 유닛 테스트).
//
//  이 테스트가 지키는 핵심 성질 두 가지:
//   1) 조회 실패가 동기화를 끊으면 안 된다(fail-open). 일시적 네트워크 장애로
//      전 유저의 동기화가 멎으면 킬스위치보다 큰 사고다.
//   2) 그렇다고 조회 실패로 킬스위치가 저절로 풀려서도 안 된다.
//      한 번 "꺼짐"을 받았으면 그 값을 유지해야 한다.
//

import Foundation
import Testing
@testable import Eggtimer

// MARK: - 서버 행 → 플래그 변환

@Suite("RemoteConfigFlags.from(rows:)")
struct RemoteConfigFlagsParsingTests {

    @Test("행이 없으면 기본값(동기화 켜짐)")
    func emptyRowsFallBackToDefault() {
        #expect(RemoteConfigFlags.from(rows: []) == .default)
        #expect(RemoteConfigFlags.default.isSyncEnabled)
    }

    @Test("sync_enabled=false 를 읽는다")
    func readsDisabledFlag() {
        let rows = [AppConfigRow(key: RemoteConfigFlags.syncEnabledKey, boolValue: false)]
        #expect(RemoteConfigFlags.from(rows: rows).isSyncEnabled == false)
    }

    @Test("sync_enabled=true 를 읽는다")
    func readsEnabledFlag() {
        let rows = [AppConfigRow(key: RemoteConfigFlags.syncEnabledKey, boolValue: true)]
        #expect(RemoteConfigFlags.from(rows: rows).isSyncEnabled)
    }

    @Test("모르는 키는 무시하고 기존 플래그를 유지한다")
    func unknownKeysAreIgnored() {
        let rows = [
            AppConfigRow(key: "some_future_flag", boolValue: false),
            AppConfigRow(key: RemoteConfigFlags.syncEnabledKey, boolValue: false),
        ]
        // 모르는 키가 sync_enabled 를 덮어쓰지 않는다.
        #expect(RemoteConfigFlags.from(rows: rows).isSyncEnabled == false)

        let onlyUnknown = [AppConfigRow(key: "some_future_flag", boolValue: false)]
        #expect(RemoteConfigFlags.from(rows: onlyUnknown).isSyncEnabled)
    }

    @Test("bool로 못 읽히는 값은 무시한다 — 오타 하나가 동기화를 끊으면 안 된다")
    func nonBooleanValueIsIgnored() {
        let rows = [AppConfigRow(key: RemoteConfigFlags.syncEnabledKey, boolValue: nil)]
        #expect(RemoteConfigFlags.from(rows: rows).isSyncEnabled)
    }
}

// MARK: - 조회 결과 + 캐시 → 실제 적용값

@Suite("RemoteConfigFlags.resolve(fetched:cached:)")
struct RemoteConfigFlagsResolveTests {

    @Test("조회 성공하면 그 값을 쓴다")
    func fetchedWins() {
        let off = RemoteConfigFlags(isSyncEnabled: false)
        let on = RemoteConfigFlags(isSyncEnabled: true)
        #expect(RemoteConfigFlags.resolve(fetched: off, cached: on) == off)
        #expect(RemoteConfigFlags.resolve(fetched: on, cached: off) == on)
    }

    @Test("한 번도 못 받아봤고 조회도 실패하면 켜진 상태로 둔다(fail-open)")
    func failsOpenWithoutCache() {
        #expect(RemoteConfigFlags.resolve(fetched: nil, cached: nil).isSyncEnabled)
    }

    @Test("조회 실패해도 캐시된 '꺼짐'은 유지된다 — 킬스위치가 저절로 풀리면 안 된다")
    func cachedDisabledSurvivesFetchFailure() {
        let off = RemoteConfigFlags(isSyncEnabled: false)
        #expect(RemoteConfigFlags.resolve(fetched: nil, cached: off).isSyncEnabled == false)
    }

    @Test("서버가 다시 켜면 캐시된 '꺼짐'을 덮어쓴다")
    func serverCanReEnable() {
        let off = RemoteConfigFlags(isSyncEnabled: false)
        let on = RemoteConfigFlags(isSyncEnabled: true)
        #expect(RemoteConfigFlags.resolve(fetched: on, cached: off).isSyncEnabled)
    }

    @Test("조회 실패 + 캐시가 '켜짐'이면 켜진 채로 둔다")
    func cachedEnabledStaysEnabled() {
        let on = RemoteConfigFlags(isSyncEnabled: true)
        #expect(RemoteConfigFlags.resolve(fetched: nil, cached: on).isSyncEnabled)
    }
}

// MARK: - 캐시 왕복

@Suite("RemoteConfigFlags 캐시 직렬화")
struct RemoteConfigFlagsCodingTests {

    @Test("저장했다 읽으면 같은 값이다")
    func roundTripsThroughCache() throws {
        for original in [RemoteConfigFlags(isSyncEnabled: true),
                         RemoteConfigFlags(isSyncEnabled: false)] {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(RemoteConfigFlags.self, from: data)
            #expect(decoded == original)
        }
    }

    @Test("깨진 캐시 데이터는 nil로 떨어진다(앱이 죽지 않는다)")
    func corruptCacheDecodesToNil() {
        let garbage = Data("not json".utf8)
        #expect((try? JSONDecoder().decode(RemoteConfigFlags.self, from: garbage)) == nil)
    }
}

// MARK: - 서버 행 디코딩

@Suite("AppConfigRow 디코딩")
struct AppConfigRowDecodingTests {

    private func decode(_ json: String) throws -> AppConfigRow {
        try JSONDecoder().decode(AppConfigRow.self, from: Data(json.utf8))
    }

    @Test("jsonb true/false 를 Bool로 읽는다")
    func decodesBooleanValue() throws {
        #expect(try decode(#"{"key":"sync_enabled","value":true}"#).boolValue == true)
        #expect(try decode(#"{"key":"sync_enabled","value":false}"#).boolValue == false)
    }

    @Test("bool이 아닌 jsonb는 boolValue=nil 이지만 디코딩 자체는 성공한다")
    func nonBooleanValueDoesNotBreakDecoding() throws {
        // 미래에 문자열·숫자·객체 플래그가 추가돼도 전체 조회가 깨지면 안 된다.
        for raw in [#""hello""#, "42", #"{"a":1}"#, "null"] {
            let row = try decode(#"{"key":"future_flag","value":\#(raw)}"#)
            #expect(row.key == "future_flag")
            #expect(row.boolValue == nil)
        }
    }
}
