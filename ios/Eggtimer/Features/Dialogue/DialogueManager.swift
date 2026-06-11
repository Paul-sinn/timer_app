//
//  DialogueManager.swift
//  Eggtimer
//
//  대사 선택기(Feature 4). 트리거 → 조건/비반복/쿨다운 필터 → 가중 랜덤.
//  최근 표시 링버퍼로 같은 말 반복을 막고, 전역 쿨다운으로 스팸을 막는다.
//  주입형 RNG·시계로 결정적 테스트 가능.
//

import SwiftUI

@Observable
@MainActor
final class DialogueManager {
    /// 현재 표시 중인 대사(없으면 nil).
    private(set) var currentLine: DialogueLine?

    private let lines: [DialogueLine]
    private let clock: () -> Date
    /// 최근 표시한 줄 id(이 개수만큼은 다시 안 뽑음).
    private var recentIDs: [String] = []
    private let recentWindow: Int
    /// 줄별 마지막 표시 시각.
    private var lastShown: [String: Date] = [:]
    /// 마지막으로 대사를 바꾼 시각(전역 쿨다운용).
    private var lastChangeAt: Date?
    private let globalCooldown: TimeInterval

    init(lines: [DialogueLine] = DialogueCatalog.all,
         recentWindow: Int = 5,
         globalCooldown: TimeInterval = 8,
         clock: @escaping () -> Date = { Date() }) {
        self.lines = lines
        self.recentWindow = recentWindow
        self.globalCooldown = globalCooldown
        self.clock = clock
    }

    /// 트리거 발생 → 후보 선정 → 가중 랜덤으로 currentLine 갱신(시스템 RNG).
    func fire(_ trigger: DialogueTrigger, speaker: DialogueSpeaker = .egg) {
        var generator = SystemRandomNumberGenerator()
        fire(trigger, speaker: speaker, using: &generator)
    }

    func fire<G: RandomNumberGenerator>(_ trigger: DialogueTrigger, speaker: DialogueSpeaker = .egg,
                                        using generator: inout G) {
        let now = clock()
        // 전역 쿨다운은 ambient한 idle에만 적용(맥락 대사는 항상 통과; 줄별 cooldown이 스팸 방지).
        if trigger == .idle,
           let last = lastChangeAt, now.timeIntervalSince(last) < globalCooldown {
            return
        }

        let byTrigger = lines.filter { $0.trigger == trigger && $0.speaker == speaker }
        // 1순위: 최근 표시 제외 + 쿨다운 경과. 비면 폴백으로 완화.
        let fresh = byTrigger.filter { !recentIDs.contains($0.id) && cooldownElapsed($0, now: now) }
        let pool = !fresh.isEmpty ? fresh
            : (byTrigger.filter { cooldownElapsed($0, now: now) }.isEmpty ? byTrigger
               : byTrigger.filter { cooldownElapsed($0, now: now) })
        guard let pick = weightedPick(pool, using: &generator) else { return }

        currentLine = pick
        lastShown[pick.id] = now
        lastChangeAt = now
        recentIDs.append(pick.id)
        if recentIDs.count > recentWindow { recentIDs.removeFirst() }
    }

    /// 대사 숨김.
    func clear() { currentLine = nil }

    private func cooldownElapsed(_ line: DialogueLine, now: Date) -> Bool {
        guard let shown = lastShown[line.id] else { return true }
        return now.timeIntervalSince(shown) >= line.cooldown
    }

    private func weightedPick<G: RandomNumberGenerator>(_ pool: [DialogueLine], using generator: inout G) -> DialogueLine? {
        guard !pool.isEmpty else { return nil }
        let total = pool.reduce(0) { $0 + max(1, $1.weight) }
        var ticket = Int.random(in: 0..<total, using: &generator)
        for line in pool {
            let w = max(1, line.weight)
            if ticket < w { return line }
            ticket -= w
        }
        return pool.last
    }
}
