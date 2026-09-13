import SwiftUI
import IntervalTimerCore

/// 円環を描き直す時刻。**区切りの数字が切り替わる瞬間にそろえる。**
///
/// 区切りの残り秒は `Text(timerInterval:)` がシステムに描かれ、
/// 区切りの終わりの時刻からちょうど1秒ごとに切り替わる。円環もその瞬間に描き直さないと、
/// 数字が減ったのに弧が遅れて減る（逆もある）。
///
/// **`.periodic(from: .now, by: 1)` にしてはいけない。** 起点が「画面を描き直した瞬間」になり、
/// 数字とは無関係な位相で動く。しかも区切りが変わる・色が変わる・一時停止するたびに
/// 描き直されて起点が引き直されるので、**合う時と、最大1秒ずれる時が入れ替わる**
/// （実機でそう見えた。2026-09-13）。
///
/// `PeriodicTimelineSchedule` は起点の**位相**にそろえて描き直す。過去でも未来でも同じで、
/// 起点 +2.4 秒なら +0.4、+1.4… に来る（Mac で実測）。だから区切りの終わりをそのまま渡せばよい。
public extension TimelineSchedule where Self == PeriodicTimelineSchedule {

    static func ringTicks(anchor: Date, config: TimerConfig, index: Int) -> PeriodicTimelineSchedule {
        .periodic(from: RingClock.splitEnd(anchor: anchor, config: config, index: index), by: 1)
    }
}

public enum RingClock {
    /// いまの区切りが終わる時刻。区切りの数字はここを基準に1秒ごとに切り替わる。
    public static func splitEnd(anchor: Date, config: TimerConfig, index: Int) -> Date {
        anchor.addingTimeInterval(config.boundary(index + 1))
    }
}
