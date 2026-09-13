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

    /// 区切りの中でどこまで塗るか。0...1。**1秒単位に切り捨てる。**
    ///
    /// 区切りの数字が1秒ごとに減るのに合わせ、弧も1秒に1目盛りずつ進める。
    /// **境目で前のマスが満タンになり、次のマスはちょうど1秒後に1目盛り目が塗られる。**
    ///
    /// 経過をそのまま割ると、境目で番号が切り替わった直後の描き直し（1秒刻みの外で起きる）で
    /// 次のマスに細い筋が出て、「満タンとほぼ同時に次を塗り始めた」ように見えた（実機。2026-09-13）。
    public static func progress(elapsed: Double, config: TimerConfig, index: Int) -> Double {
        let from = config.boundary(index)
        let to = config.boundary(index + 1)
        guard to > from else { return 0 }
        // 描き直しの時刻は「区切りの終わり − 整数秒」で作られ、浮動小数の誤差でわずかに手前へ出ることがある。
        // そのまま切り捨てると1秒遅れるので、ほんの少し足してから切り捨てる
        let whole = floor(elapsed - from + 1e-6)
        return (whole / (to - from)).clamped(to: 0...1)
    }
}
