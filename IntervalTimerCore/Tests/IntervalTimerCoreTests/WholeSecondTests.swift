import Foundation
import Testing
@testable import IntervalTimerCore

/// 全体・区切り・円環・振動が、同じ1秒の刻みで動くこと。
///
/// 全体の秒数は必ず整数なので、全体の数字はちょうどの秒で切り替わる。
/// 区切りの境目が半端（1分×8 なら 7.5 秒）だと、区切りの数字と円環だけ0.5秒ずれて減った
/// （実機で「全体の時間が合わない」と言われた。2026-09-13）。
struct WholeSecondTests {

    private let base = Date(timeIntervalSinceReferenceDate: 0)

    @Test func 境目はどの設定でもちょうどの秒になる() {
        for minutes in TimerConfig.minuteRange {
            for parts in TimerConfig.partsRange {
                let c = TimerConfig(minutes: minutes, parts: parts)
                for i in 0...parts {
                    let b = c.boundary(i)
                    #expect(b == b.rounded())
                }
            }
        }
    }

    @Test func 一分八分割は八秒と七秒が交互になり全体は変わらない() {
        let c = TimerConfig(minutes: 1, parts: 8)
        let lengths = (0..<8).map { c.boundary($0 + 1) - c.boundary($0) }
        #expect(lengths == [8, 7, 8, 7, 8, 7, 8, 7])
        #expect(c.boundary(8) == 60)
    }

    @Test func 区切りの番号は丸めた境目でちょうど進む() {
        // 割り算で出していたころは 7.5 秒で番号だけ先に進んでいた
        let engine = TimerEngine(config: TimerConfig(minutes: 1, parts: 8), startedAt: base)
        #expect(engine.snapshot(at: base.addingTimeInterval(7.9)).displayIndex == 1)
        #expect(engine.snapshot(at: base.addingTimeInterval(8.0)).displayIndex == 2)
        #expect(engine.snapshot(at: base.addingTimeInterval(14.9)).displayIndex == 2)
        #expect(engine.snapshot(at: base.addingTimeInterval(15.0)).displayIndex == 3)
    }

    @Test func 全体の数字と区切りの数字は同じ瞬間に切り替わる() {
        let engine = TimerEngine(config: TimerConfig(minutes: 1, parts: 8), startedAt: base)
        var lastTotal = ""
        var lastSplit = ""
        for i in 0...600 {
            let s = engine.snapshot(at: base.addingTimeInterval(Double(i) / 10))
            let total = TimeText.clock(s.totalRemaining)
            let split = TimeText.clock(s.splitRemaining)
            if i > 0 {
                #expect((total != lastTotal) == (split != lastSplit))
            }
            lastTotal = total
            lastSplit = split
        }
    }

    @Test func 残りわずかの合図もちょうどの秒に来る() {
        let c = TimerConfig(minutes: 1, parts: 7)   // 境目 0・9・17・26・34・43・51・60
        #expect(c.givesWarning)
        var engine = TimerEngine(config: c, startedAt: base)
        var warnings: [Double] = []
        for i in 0...600 {
            let t = Double(i) / 10
            for e in engine.advance(to: base.addingTimeInterval(t)) where e == .warning {
                warnings.append(t)
            }
        }
        #expect(warnings == [7, 15, 24, 32, 41, 49, 58])
    }

    @Test func 合図の時刻はどの設定でもちょうどの秒で区切りの内側() {
        for minutes in TimerConfig.minuteRange {
            for parts in TimerConfig.partsRange {
                let c = TimerConfig(minutes: minutes, parts: parts)
                for i in 0..<parts {
                    let w = c.warningPoint(i)
                    #expect(w == w.rounded())
                    #expect(w > c.boundary(i))
                    #expect(w < c.boundary(i + 1))
                }
            }
        }
    }
}
