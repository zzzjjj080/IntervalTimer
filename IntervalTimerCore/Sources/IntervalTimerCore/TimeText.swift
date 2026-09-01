import Foundation

/// 秒数を文字にする。
///
/// **切り上げる。** 開始直後に `20:00` と出て、1秒後に `19:59` へ落ちるのが正しい。
/// 切り捨てにすると開始した瞬間に `19:59` と出て、1秒損したように見える。
public enum TimeText {

    /// 浮動小数の誤差で `300.0000000001` のような値が来たときに `5:01` と出さないための余裕。
    private static let epsilon = 1e-6

    /// `m:ss`。60分を超えたら `h:mm:ss`。
    public static func clock(_ seconds: Double) -> String {
        let s = Int(ceil(max(0, seconds) - epsilon))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%d:%02d", m, sec)
    }

    /// `1分` `45秒` `1分30秒`。文章の中に混ぜる用。ぴったりのときは秒を出さない。
    public static func brief(_ seconds: Double) -> String {
        let s = Int(ceil(max(0, seconds) - epsilon))
        let m = s / 60, sec = s % 60
        if m == 0 { return "\(sec)秒" }
        if sec == 0 { return "\(m)分" }
        return "\(m)分\(sec)秒"
    }

    /// `5分00秒`。設定画面のプレビュー用。
    public static func japanese(_ seconds: Double) -> String {
        let s = Int(ceil(max(0, seconds) - epsilon))
        let m = s / 60, sec = s % 60
        return m > 0 ? "\(m)分\(String(format: "%02d", sec))秒" : "\(sec)秒"
    }
}
