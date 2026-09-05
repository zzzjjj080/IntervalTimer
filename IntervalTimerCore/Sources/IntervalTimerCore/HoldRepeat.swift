import Foundation

/// ＋ − を押し続けたときに、数字が増え続ける速さ。
///
/// **押した瞬間から走り出させない。** 1つだけ変えたいときに行き過ぎる。
/// 少し待ってから始めて、押し続けるほど速くする。
public enum HoldRepeat {

    /// 押してから、連続で増え始めるまでの間。
    public static let delay: Double = 0.4

    /// 何回か進んだら倍の速さにする。
    private static let fastAfter = 20

    /// `done` 回進んだあとの、次までの間隔。
    public static func interval(after done: Int) -> Double {
        done < fastAfter ? 0.12 : 0.06
    }

    /// 押しっぱなしで `steps` 回ぶん進むのにかかる秒数。
    ///
    /// **速さを変えたら、この値をテストで見る。**
    /// 速すぎると狙った数で止められず、遅すぎると端から端まで行けない。
    public static func duration(steps: Int) -> Double {
        // 1回目は押した瞬間なので待ち時間ゼロ。2回目の前にだけ `delay` が入り、
        // 3回目以降が `interval`。数え違えると「1つだけ動かしたい」が壊れる。
        guard steps > 1 else { return 0 }
        return delay + (0..<(steps - 2)).reduce(0) { $0 + interval(after: $1) }
    }
}
