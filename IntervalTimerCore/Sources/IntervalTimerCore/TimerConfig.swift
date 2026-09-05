import Foundation

/// タイマーの設定。全体の長さと、それを何等分するか。
///
/// 範囲外の値を持てないようにしてある。`init` が必ず範囲へ丸めるので、
/// 「0分割」や「0分」といったあり得ない設定は作れない。
public struct TimerConfig: Equatable, Hashable, Codable, Sendable {

    /// 全体時間（分）。仕様上の範囲は 1〜180。
    public static let minuteRange = 1...180
    /// 分割回数。仕様上の範囲は 1〜12。分割1は「区切りなし」を意味する。
    public static let partsRange = 1...12

    public let minutes: Int
    public let parts: Int

    public init(minutes: Int, parts: Int) {
        self.minutes = minutes.clamped(to: Self.minuteRange)
        self.parts = parts.clamped(to: Self.partsRange)
    }

    /// 全体の秒数。
    public var totalSeconds: Double { Double(minutes) * 60 }

    /// 1区切りの秒数。
    ///
    /// 端数が出る設定（例: 全体7分・分割3）でも、この値を足し込んで境界を決めてはいけない。
    /// 丸め誤差が溜まって最後の区切りがぴったり0で終わらなくなる。
    /// 境界は必ず ``boundary(_:)`` で都度計算する。表示用の目安としてだけ使うこと。
    public var splitSeconds: Double { totalSeconds / Double(parts) }

    /// i 番目の区切りが終わる時刻（開始からの秒数）。i は 0...parts。
    /// `boundary(0) == 0`、`boundary(parts) == totalSeconds` になる。
    public func boundary(_ i: Int) -> Double {
        totalSeconds * Double(i.clamped(to: 0...parts)) / Double(parts)
    }

    /// 区切りの途中の合図を出すかどうか。
    ///
    /// 区切りが短いと合図が一瞬で過ぎてしまい、振動の意味がなくなる。
    /// 残りぶんが2秒未満になる設定では出さない。
    public var givesWarning: Bool { splitSeconds * Self.warningRatio >= 2.0 }

    /// 区切りの**75%が終わった**ところで合図を出す。つまり「残りこの割合」。
    ///
    /// 練習中は「そろそろ終わる」を先に知りたいので、区切りの終わりと同じ強さで鳴らす。
    /// 弱い合図だと、動いている最中は気づけない。
    public static let warningRatio = 0.25

    // MARK: - 保存からの読み出し

    /// 保存されたJSONから読むときも、必ず範囲へ丸める。
    /// 自動生成の decoder のままだと、壊れた保存値（0分割など）がそのまま入ってきて
    /// ゼロ除算になる。入り口をひとつにしておく。
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            minutes: try c.decodeIfPresent(Int.self, forKey: .minutes) ?? 20,
            parts: try c.decodeIfPresent(Int.self, forKey: .parts) ?? 4
        )
    }
}

extension Comparable {
    public func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
