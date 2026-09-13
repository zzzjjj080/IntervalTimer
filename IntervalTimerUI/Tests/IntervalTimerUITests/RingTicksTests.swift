import Foundation
import SwiftUI
import Testing
import IntervalTimerCore
@testable import IntervalTimerUI

/// 円環の描き直しが、区切りの数字の切り替わりと同じ瞬間に来るか。
///
/// 数字は区切りの終わりの時刻から1秒ごとに切り替わる。
/// だから「区切りの終わり − 描き直す時刻」が**ちょうど整数秒**なら、そろっている。
struct RingTicksTests {

    private let anchor = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func isWholeSeconds(_ x: Double) -> Bool {
        abs(x - x.rounded()) < 1e-6
    }

    /// `now` の時点から見た、最初の数回ぶんの描き直し時刻。
    private func ticks(_ schedule: PeriodicTimelineSchedule, from now: Date) -> [Date] {
        Array(schedule.entries(from: now, mode: .normal).prefix(5))
    }

    @Test("区切りが整数秒のとき、描き直しは数字の切り替わりと重なる")
    func 整数秒の区切り() {
        let config = TimerConfig(minutes: 1, parts: 4)   // 1区切り15秒
        let end = RingClock.splitEnd(anchor: anchor, config: config, index: 1)
        let now = anchor.addingTimeInterval(18.37)
        for t in ticks(.ringTicks(anchor: anchor, config: config, index: 1), from: now) {
            #expect(isWholeSeconds(end.timeIntervalSince(t)))
        }
    }

    @Test("区切りに端数があっても、描き直しは数字の切り替わりと重なる")
    func 端数のある区切り() {
        let config = TimerConfig(minutes: 1, parts: 8)   // 1区切り7.5秒。境界が半端な位置に来る
        let end = RingClock.splitEnd(anchor: anchor, config: config, index: 0)
        let now = anchor.addingTimeInterval(2.9)
        let got = ticks(.ringTicks(anchor: anchor, config: config, index: 0), from: now)
        #expect(!got.isEmpty)
        for t in got {
            #expect(isWholeSeconds(end.timeIntervalSince(t)))
        }
    }

    @Test("いつ描き直しても、位相は変わらない")
    func 描き直しの瞬間に左右されない() {
        let config = TimerConfig(minutes: 7, parts: 9)   // 1区切り46.66…秒
        let schedule = PeriodicTimelineSchedule.ringTicks(anchor: anchor, config: config, index: 0)
        let a = ticks(schedule, from: anchor.addingTimeInterval(0.123))
        let b = ticks(schedule, from: anchor.addingTimeInterval(3.901))
        let phaseA = a[0].timeIntervalSince(anchor).truncatingRemainder(dividingBy: 1)
        let phaseB = b[0].timeIntervalSince(anchor).truncatingRemainder(dividingBy: 1)
        #expect(abs(phaseA - phaseB) < 1e-6)
    }

    @Test("以前の書き方（描き直した瞬間を起点）では、位相が描き直すたびに変わる")
    func 以前の不具合を再現する() {
        let now1 = anchor.addingTimeInterval(0.2)
        let now2 = anchor.addingTimeInterval(5.7)
        let a = ticks(.periodic(from: now1, by: 1), from: now1)
        let b = ticks(.periodic(from: now2, by: 1), from: now2)
        let phaseA = a[0].timeIntervalSince(anchor).truncatingRemainder(dividingBy: 1)
        let phaseB = b[0].timeIntervalSince(anchor).truncatingRemainder(dividingBy: 1)
        #expect(abs(phaseA - phaseB) > 0.1)
    }
}
