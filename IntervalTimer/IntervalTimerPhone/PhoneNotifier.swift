import Foundation
import UserNotifications
import IntervalTimerCore

/// 画面を閉じている間の合図。
///
/// **iPhone には Watch のワークアウトに当たる仕掛けが無い。**
/// 裏に回るとアプリは止まるので、振動も鳴らせない。
/// その代わり、**区切りの時刻をあらかじめ通知として登録しておく。**
///
/// 前に出ているときは通知を使わず、こちらで触覚を鳴らす。
/// 二重に知らせないよう、前に戻ったら登録を消す。
///
/// 許可されなくてもタイマーは動く。**その旨は画面に出す。**
@MainActor
final class PhoneNotifier {

    private(set) var isAllowed = false
    private let center = UNUserNotificationCenter.current()

    func requestPermission() async {
        do {
            isAllowed = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            isAllowed = false
        }
    }

    /// 残りの区切りぶんを、まとめて登録する。
    func schedule(config: TimerConfig, anchor: Date, from now: Date) async {
        await clear()
        guard isAllowed else { return }

        for i in 1...config.parts {
            let end = anchor.addingTimeInterval(config.boundary(i))
            // 途中の合図（75%）
            if config.givesWarning {
                let cue = anchor.addingTimeInterval(
                    config.boundary(i) - config.splitSeconds * TimerConfig.warningRatio)
                if cue > now {
                    await add(at: cue, id: "cue-\(i)",
                              title: String(localized: "そろそろ区切りです"),
                              body: "\(i) / \(config.parts)")
                }
            }
            guard end > now else { continue }
            let last = (i == config.parts)
            await add(at: end, id: "end-\(i)",
                      title: last ? String(localized: "終了") : String(localized: "区切りが終わりました"),
                      body: last ? String(localized: "おつかれさまでした")
                                 : "\(i + 1) / \(config.parts)")
        }
    }

    func clear() async {
        center.removeAllPendingNotificationRequests()
    }

    private func add(at date: Date, id: String, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        // 秒まで指定したいので、残り秒数で組む。時刻で組むと日をまたぐ設定で崩れる
        let after = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: after, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
