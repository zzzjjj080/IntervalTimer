import Foundation

/// 秒数を文字にする。
///
/// **切り上げる。** 開始直後に `20:00` と出て、1秒後に `19:59` へ落ちるのが正しい。
/// 切り捨てにすると開始した瞬間に `19:59` と出て、1秒損したように見える。
public enum TimeText {

    /// 浮動小数の誤差で `300.0000000001` のような値が来たときに `5:01` と出さないための余裕。
    private static let epsilon = 1e-6

    /// `m:ss`。1時間を超えたら `h:mm:ss`。
    ///
    /// この既定の振る舞いは `Text(timerInterval:showsHours: true)` と一致する。
    /// **あちらの `showsHours: true` は「常に時を出す」ではなく「1時間を超えたら出す」。**
    /// 実機で 44分57秒 を出したら `0:44:57` ではなく `44:57` だった。
    /// 動いている間はシステムが描き、止まっている間はこちらが描くので、
    /// **両者がずれないことがここでは一番大事。** 既定のまま使うこと。
    ///
    /// `showsHours` を明示すると、その判断を上書きできる（テスト用）。
    public static func clock(_ seconds: Double, showsHours: Bool? = nil) -> String {
        let s = Int(ceil(max(0, seconds) - epsilon))
        let sec = s % 60
        if showsHours ?? (s >= 3600) {
            return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, sec)
        }
        // 時を出さないと決めたなら、60分を超えても分に足し込む（`61:00`）。
        return String(format: "%d:%02d", s / 60, sec)
    }

    /// `1分` `47秒` `2分20秒`。**ぴったりなら秒を出さない。**
    /// 設定画面で「1区切りの長さ」を短く見せるのに使う。
    public static func brief(_ seconds: Double) -> String {
        let s = Int(ceil(max(0, seconds) - epsilon))
        let m = s / 60, sec = s % 60
        if m == 0 { return "\(sec)秒" }
        if sec == 0 { return "\(m)分" }
        return "\(m)分\(sec)秒"
    }

    /// `5分00秒`。
    public static func japanese(_ seconds: Double) -> String {
        let s = Int(ceil(max(0, seconds) - epsilon))
        let m = s / 60, sec = s % 60
        return m > 0 ? "\(m)分\(String(format: "%02d", sec))秒" : "\(sec)秒"
    }
}
