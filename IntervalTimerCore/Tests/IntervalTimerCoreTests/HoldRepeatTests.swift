import Foundation
import Testing
@testable import IntervalTimerCore

/// 長押しの速さ。数字だけの話なので、実機を触らずにここで決められる。
struct HoldRepeatTests {

    @Test func 押し続けるほど速くなる() {
        #expect(HoldRepeat.interval(after: 0) == 0.12)
        #expect(HoldRepeat.interval(after: 19) == 0.12)
        #expect(HoldRepeat.interval(after: 20) == 0.06)
        #expect(HoldRepeat.interval(after: 200) == 0.06)
    }

    @Test func 端から端まで十数秒で行ける() {
        // 全体は 1〜180。180回ぶん押しっぱなしにしたときの時間。
        let full = HoldRepeat.duration(steps: TimerConfig.minuteRange.count)
        #expect(full > 8, "速すぎて狙った数で止められない（\(full)秒）")
        #expect(full < 16, "遅すぎて端まで行けない（\(full)秒）")
    }

    @Test func 分割は一瞬で端まで行ける() {
        // 分割は 1〜12 しかない。ここが遅いと苛立つ。
        let full = HoldRepeat.duration(steps: TimerConfig.partsRange.count)
        #expect(full < 2.0, "12回ぶんに \(full)秒 はかかりすぎ")
    }

    @Test func 押しただけでは走り出さない() {
        // 1回ぶんは待ち時間ゼロ（押した瞬間に1つ動く）
        #expect(HoldRepeat.duration(steps: 1) == 0)
        // 2回目からは必ず delay を挟む
        #expect(HoldRepeat.duration(steps: 2) == HoldRepeat.delay)
    }
}
