import Foundation
import Observation

/// 動作確認用の足あと。**開き直しても消えないよう保存する**（直近8件）。
///
/// 文字盤へ戻されると、こちらのコードは止まる。その間はログも出ないので、
/// 「なぜ戻ったか」はコンソールを見ていても分からないことがある。
/// 開き直すと新しい出来事で上書きされるので、保存しておいて設定画面に出す
/// （ワンタップタイマーで実際にそうなった。引き継ぎ書 4-131）。
///
/// 書き込むのは DEBUG のときだけ。リリース構成では常に空。
@MainActor
@Observable
final class Trail {
    static let shared = Trail()

    private static let key = "debugTrail"
    private(set) var lines: [String] = UserDefaults.standard.stringArray(forKey: key) ?? []

    func add(_ message: String) {
        #if DEBUG
        let stamp = Date.now.formatted(date: .omitted, time: .standard)
        lines.insert("\(stamp) \(message)", at: 0)
        lines = Array(lines.prefix(8))
        UserDefaults.standard.set(lines, forKey: Self.key)
        #endif
    }
}
