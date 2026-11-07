//
//  SnowfallTests.swift
//  EggtimerTests
//
//  크리스마스 월드 눈 내리기(코드 연출)의 순수 위치 계산 검증.
//  화면 밖으로 새지 않고, 같은 시각이면 같은 자리(프레임마다 튀지 않음), 시간이 흐르면 아래로 내려온다.
//

import Testing
import Foundation
import CoreGraphics
@testable import Eggtimer

struct SnowfallTests {
    private let size = CGSize(width: 390, height: 844)

    @Test func flakesAreDeterministicForTheSameSeed() {
        #expect(Snowfall.flakes(count: 40, seed: 7) == Snowfall.flakes(count: 40, seed: 7))
        #expect(Snowfall.flakes(count: 40, seed: 7) != Snowfall.flakes(count: 40, seed: 8))
    }

    @Test func flakeParametersStayInRange() {
        for f in Snowfall.flakes(count: 200, seed: 1) {
            #expect((0...1).contains(f.x))
            #expect((0...1).contains(f.y))
            #expect(Snowfall.sizeRange.contains(f.size))
            #expect(Snowfall.speedRange.contains(f.speed))
        }
    }

    @Test func positionAlwaysStaysOnScreenAndWraps() {
        let flakes = Snowfall.flakes(count: 60, seed: 3)
        for t in stride(from: 0.0, through: 600.0, by: 7.3) {
            for f in flakes {
                let p = Snowfall.position(of: f, at: t, in: size)
                #expect(p.y >= -f.size && p.y < size.height)
                #expect(p.x >= -Snowfall.maxDrift && p.x <= size.width + Snowfall.maxDrift)
            }
        }
    }

    @Test func snowFallsDownOverTime() {
        let f = Snowfall.Flake(x: 0.5, y: 0.1, size: 3, speed: 20, phase: 0)
        let a = Snowfall.position(of: f, at: 0, in: size)
        let b = Snowfall.position(of: f, at: 2, in: size)   // 2초 × 20pt/s = 40pt 아래
        #expect(b.y - a.y == 40)
    }

    @Test func positionsSnapToWholePoints() {
        // 픽셀아트와 어울리게 정수 좌표(번지는 반픽셀 없음).
        let f = Snowfall.Flake(x: 0.3333, y: 0.777, size: 2, speed: 23.7, phase: 1.1)
        let p = Snowfall.position(of: f, at: 3.21, in: size)
        #expect(p.x == p.x.rounded() && p.y == p.y.rounded())
    }

    @Test func onlyChristmasHasSnowfall() {
        #expect(World.christmas.hasSnowfall)
        #expect(!World.classic.hasSnowfall)
    }
}
