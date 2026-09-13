import Foundation
import Testing
import IntervalTimerCore
@testable import IntervalTimerUI

/// 円環の塗り方。**境目で前のマスが満タンになり、次のマスはちょうど1秒後に塗り始める。**
struct RingProgressTests {

    private let config = TimerConfig(minutes: 1, parts: 8)   // 境目 0・8・15・23…

    private func p(_ elapsed: Double, index: Int) -> Double {
        RingClock.progress(elapsed: elapsed, config: config, index: index)
    }

    @Test func 一秒ごとに一目盛りずつ進み途中では動かない() {
        #expect(p(0, index: 0) == 0)
        #expect(p(0.999, index: 0) == 0)
        #expect(p(1, index: 0) == 1.0 / 8)
        #expect(p(3.5, index: 0) == 3.0 / 8)
    }

    @Test func 境目で前のマスが満タンになる() {
        #expect(p(7.999, index: 0) == 7.0 / 8)
        #expect(p(8, index: 0) == 1)   // 番号の切り替えが少し遅れても、満タンで描かれる
    }

    @Test func 次のマスは境目のちょうど一秒後に塗り始める() {
        // 2つ目の区切りは 8〜15 秒の7秒
        #expect(p(8, index: 1) == 0)
        #expect(p(8.05, index: 1) == 0)   // 境目の直後の描き直しでも筋を出さない
        #expect(p(8.999, index: 1) == 0)
        #expect(p(9, index: 1) == 1.0 / 7)
    }

    @Test func 浮動小数の誤差で一秒遅れない() {
        #expect(p(9 - 1e-9, index: 1) == 1.0 / 7)
    }

    @Test func 番号だけ先に進んだ瞬間も範囲の外へ出ない() {
        #expect(p(7, index: 1) == 0)
    }
}
