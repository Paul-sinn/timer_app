//
//  SyncPagingTests.swift
//  EggtimerTests
//
//  Supabase pull 경로 페이지네이션의 순수 로직 검증(Phase 3-4):
//  페이지 경계 계산 · 마지막 페이지 판정 · 상한 가드 · id 중복 제거 · push 청크 분할 · select 컬럼 목록.
//
//  네트워크 왕복 자체는 테스트하지 않는다(lessons: 컨테이너/네트워크 통합은 유닛 테스트 대상 아님).
//  대신 "페이지 1장 가져오기"를 클로저로 주입해 반복 루프 정책만 검증한다.
//

import Testing
import Foundation
@testable import Eggtimer

// MARK: - 테스트 더블

/// 페이지네이션 루프 검증용 최소 행(Identifiable만 만족하면 된다).
private struct PagedRow: Identifiable, Equatable {
    let id: Int
}

/// 고정 개수의 행을 offset/limit으로 잘라 돌려주는 가짜 원격 소스. 요청받은 범위를 기록한다.
private final class PagedSource {
    let rows: [PagedRow]
    private(set) var requested: [SyncPageRange] = []

    init(count: Int) {
        rows = (0..<count).map { PagedRow(id: $0) }
    }

    func page(_ range: SyncPageRange) -> [PagedRow] {
        requested.append(range)
        guard range.from < rows.count else { return [] }
        return Array(rows[range.from..<min(range.to + 1, rows.count)])
    }
}

/// 언제나 꽉 찬 페이지를 돌려주는 소스(상한 가드 검증용 — 끝이 없다).
private final class EndlessSource {
    private(set) var calls = 0

    func page(_ range: SyncPageRange) -> [PagedRow] {
        calls += 1
        return (range.from...range.to).map { PagedRow(id: $0) }
    }
}

/// 페이지네이션 도중 앞쪽에 행이 추가돼 offset이 밀린 상황(같은 행을 두 번 받는다).
private final class ShiftingSource {
    private(set) var calls = 0

    func page(_ range: SyncPageRange) -> [PagedRow] {
        calls += 1
        // 1페이지: 0,1 / 2페이지: 1,2 (1이 중복) / 3페이지: 비어 있음
        switch range.from {
        case 0: return [PagedRow(id: 0), PagedRow(id: 1)]
        case 2: return [PagedRow(id: 1), PagedRow(id: 2)]
        default: return []
        }
    }
}

private struct FakeNetworkError: Error, Equatable {}

// MARK: -

struct SyncPagingTests {

    // MARK: - 페이지 경계 계산

    @Test func firstPageStartsAtZeroAndIsInclusive() {
        let r = SyncPaging.range(page: 0, pageSize: 500)
        #expect(r.from == 0)
        // PostgREST range는 양끝 포함 → 0...499 = 500행
        #expect(r.to == 499)
    }

    @Test func pagesAreContiguousWithoutGapOrOverlap() {
        let size = 500
        var previous = SyncPaging.range(page: 0, pageSize: size)
        for page in 1..<5 {
            let current = SyncPaging.range(page: page, pageSize: size)
            #expect(current.from == previous.to + 1)
            #expect(current.to - current.from + 1 == size)
            previous = current
        }
    }

    @Test func defaultPageSizeStaysBelowPostgrestMaxRows() {
        // "받은 행 수 < 페이지 크기"로 끝을 판정하므로, 서버 상한(Supabase 기본 db-max-rows = 1000)에
        // 걸려 잘린 응답을 마지막 페이지로 오판하지 않으려면 페이지 크기가 상한보다 작아야 한다.
        #expect(SyncPaging.pageSize > 0)
        #expect(SyncPaging.pageSize < 1000)
        #expect(SyncPaging.maxPages > 0)
    }

    // MARK: - 마지막 페이지 판정

    @Test func shortPageIsLastPage() {
        #expect(SyncPaging.isLastPage(received: 0, pageSize: 500))
        #expect(SyncPaging.isLastPage(received: 1, pageSize: 500))
        #expect(SyncPaging.isLastPage(received: 499, pageSize: 500))
    }

    @Test func fullPageIsNotLastPage() {
        #expect(!SyncPaging.isLastPage(received: 500, pageSize: 500))
    }

    // MARK: - 전체 수집 루프 (경계 케이스)

    @Test func fetchAllReturnsNothingForEmptySource() async throws {
        let source = PagedSource(count: 0)
        let rows: [PagedRow] = try await SyncPaging.fetchAll(pageSize: 10, maxPages: 5) {
            source.page($0)
        }
        #expect(rows.isEmpty)
        // 0행이어도 요청은 1번 나가야 한다(빈 응답으로 끝을 안다).
        #expect(source.requested == [SyncPageRange(from: 0, to: 9)])
    }

    @Test func fetchAllHandlesExactlyOnePage() async throws {
        let source = PagedSource(count: 10)
        let rows: [PagedRow] = try await SyncPaging.fetchAll(pageSize: 10, maxPages: 5) {
            source.page($0)
        }
        #expect(rows.map(\.id) == Array(0..<10))
        // 정확히 페이지 크기면 "더 있는지" 알 수 없으므로 빈 페이지 1번을 더 확인한다.
        #expect(source.requested.count == 2)
        #expect(source.requested.last == SyncPageRange(from: 10, to: 19))
    }

    @Test func fetchAllHandlesPageSizePlusOne() async throws {
        let source = PagedSource(count: 11)
        let rows: [PagedRow] = try await SyncPaging.fetchAll(pageSize: 10, maxPages: 5) {
            source.page($0)
        }
        #expect(rows.map(\.id) == Array(0..<11))
        #expect(source.requested.count == 2)
    }

    @Test func fetchAllWalksMultiplePagesInOrder() async throws {
        let source = PagedSource(count: 25)
        let rows: [PagedRow] = try await SyncPaging.fetchAll(pageSize: 10, maxPages: 5) {
            source.page($0)
        }
        #expect(rows.map(\.id) == Array(0..<25))
        #expect(source.requested == [
            SyncPageRange(from: 0, to: 9),
            SyncPageRange(from: 10, to: 19),
            SyncPageRange(from: 20, to: 29),
        ])
    }

    @Test func fetchAllThrowsWhenPageLimitExceeded() async {
        let source = EndlessSource()
        do {
            let _: [PagedRow] = try await SyncPaging.fetchAll(pageSize: 10, maxPages: 3) {
                source.page($0)
            }
            Issue.record("상한을 넘겼는데 에러 없이 반환됐다 — 무한 루프 가드가 없다")
        } catch let error as SyncPagingError {
            #expect(error == .pageLimitExceeded(pageSize: 10, maxPages: 3))
        } catch {
            Issue.record("예상치 못한 에러: \(error)")
        }
        // 상한만큼만 요청하고 멈춘다.
        #expect(source.calls == 3)
    }

    @Test func fetchAllThrowsWhenSourceIsExactlyPageLimitLong() async {
        // 정확히 상한(3페이지 × 10행)만큼 있는 경우: 마지막 페이지가 꽉 찼으니 더 있는지 알 수 없다.
        // 조용히 자르지 말고 에러를 내는 게 이 구현의 계약이다(잘린 결과 = 영구 재업로드).
        let source = PagedSource(count: 30)
        do {
            let _: [PagedRow] = try await SyncPaging.fetchAll(pageSize: 10, maxPages: 3) {
                source.page($0)
            }
            Issue.record("상한과 데이터 크기가 같을 때 조용히 잘렸다")
        } catch let error as SyncPagingError {
            #expect(error == .pageLimitExceeded(pageSize: 10, maxPages: 3))
        } catch {
            Issue.record("예상치 못한 에러: \(error)")
        }
    }

    @Test func fetchAllPropagatesFetchError() async {
        do {
            let _: [PagedRow] = try await SyncPaging.fetchAll(pageSize: 10, maxPages: 5) { _ in
                throw FakeNetworkError()
            }
            Issue.record("네트워크 에러가 삼켜졌다")
        } catch is FakeNetworkError {
            // 기대대로 호출부(SyncCoordinator)까지 전파된다 → 부분 결과로 머지하지 않는다.
        } catch {
            Issue.record("예상치 못한 에러: \(error)")
        }
    }

    // MARK: - id 중복 제거

    @Test func deduplicationKeepsFirstOccurrenceOrder() {
        let rows = [PagedRow(id: 3), PagedRow(id: 1), PagedRow(id: 3), PagedRow(id: 2), PagedRow(id: 1)]
        #expect(SyncPaging.deduplicatedByID(rows).map(\.id) == [3, 1, 2])
    }

    @Test func deduplicationOfEmptyIsEmpty() {
        #expect(SyncPaging.deduplicatedByID([PagedRow]()).isEmpty)
    }

    @Test func fetchAllDeduplicatesRowsShiftedAcrossPageBoundary() async throws {
        // 페이지네이션 중 새 행이 앞에 끼어들면 offset이 밀려 같은 행을 두 번 받을 수 있다.
        // 호출부 insertFromRemote는 "호출 전" 기존 id만 걸러내므로 배열 내부 중복은 그대로 두 번 저장된다.
        let source = ShiftingSource()
        let rows: [PagedRow] = try await SyncPaging.fetchAll(pageSize: 2, maxPages: 5) {
            source.page($0)
        }
        #expect(rows.map(\.id) == [0, 1, 2])
    }

    // MARK: - push 청크 분할

    @Test func chunksOfEmptyArrayIsEmpty() {
        #expect(SyncPaging.chunks([Int](), size: 10).isEmpty)
    }

    @Test func chunksSmallerThanSizeStayInOneRequest() {
        #expect(SyncPaging.chunks(Array(0..<3), size: 10) == [[0, 1, 2]])
    }

    @Test func chunksExactMultipleSplitEvenly() {
        #expect(SyncPaging.chunks(Array(0..<4), size: 2) == [[0, 1], [2, 3]])
    }

    @Test func chunksWithRemainderKeepTail() {
        let chunked = SyncPaging.chunks(Array(0..<5), size: 2)
        #expect(chunked == [[0, 1], [2, 3], [4]])
        // 분할해도 원소는 하나도 잃지 않고 순서도 유지된다.
        #expect(chunked.flatMap { $0 } == Array(0..<5))
    }

    @Test func defaultChunkSizeIsBounded() {
        #expect(SyncPaging.chunkSize > 0)
        #expect(SyncPaging.chunkSize <= 1000)
    }

    // MARK: - select 컬럼 목록 (CodingKeys 단일 출처)

    @Test func sessionSelectColumnsComeFromCodingKeys() {
        let columns = FocusSessionRow.selectColumns.split(separator: ",").map(String.init)
        let keys = FocusSessionRow.CodingKeys.allCases.map(\.stringValue)
        #expect(columns == keys)
        #expect(!FocusSessionRow.selectColumns.contains("*"))
        // 앱이 디코딩하지 않는 컬럼은 실어 오지 않는다.
        #expect(!columns.contains("created_at"))
        // 정렬 tiebreaker이자 머지 키 → 반드시 포함돼야 한다.
        #expect(columns.contains("id"))
    }

    @Test func creatureSelectColumnsComeFromCodingKeys() {
        let columns = HatchedCreatureRow.selectColumns.split(separator: ",").map(String.init)
        let keys = HatchedCreatureRow.CodingKeys.allCases.map(\.stringValue)
        #expect(columns == keys)
        #expect(!HatchedCreatureRow.selectColumns.contains("*"))
        #expect(!columns.contains("created_at"))
        #expect(!columns.contains("updated_at"))
        #expect(columns.contains("id"))
    }

    @Test func sessionSelectColumnsAreSufficientToDecode() throws {
        let row = FocusSessionRow(
            id: UUID(), userId: UUID(), startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            plannedSeconds: 1500, activeSeconds: 1490, interruptionCount: 1,
            distracted: false, completed: true, companionId: UUID(), mode: "pomodoro"
        )
        let encoded = try JSONEncoder().encode(row)
        let full = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let columns = Set(FocusSessionRow.selectColumns.split(separator: ",").map(String.init))

        // 컬럼 목록이 디코딩에 필요한 키를 하나도 빠뜨리지 않는다.
        let projected = full.filter { columns.contains($0.key) }
        #expect(projected.count == full.count)

        let data = try JSONSerialization.data(withJSONObject: projected)
        let decoded = try JSONDecoder().decode(FocusSessionRow.self, from: data)
        #expect(decoded == row)
    }

    @Test func creatureSelectColumnsAreSufficientToDecode() throws {
        let row = HatchedCreatureRow(id: UUID(), userId: UUID(), species: "slime",
                                     imageName: "slime_1",
                                     hatchedAt: Date(timeIntervalSince1970: 1_700_000_500))
        let encoded = try JSONEncoder().encode(row)
        let full = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let columns = Set(HatchedCreatureRow.selectColumns.split(separator: ",").map(String.init))

        let projected = full.filter { columns.contains($0.key) }
        #expect(projected.count == full.count)

        let data = try JSONSerialization.data(withJSONObject: projected)
        let decoded = try JSONDecoder().decode(HatchedCreatureRow.self, from: data)
        #expect(decoded == row)
    }
}
