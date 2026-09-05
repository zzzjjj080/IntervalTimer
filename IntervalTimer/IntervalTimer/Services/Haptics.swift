import WatchKit
import IntervalTimerCore

/// 3種類の通知。
///
/// | 場面 | 触覚 |
/// |---|---|
/// | 区切りの75%が終わった | `.notification` を3回（0.13秒あけて） |
/// | 区切りが0になった | 同じ（3回） |
/// | 全体が0になった | 3回 → 少し空けて 3回 ＋ `.stop` |
///
/// **区切りの途中と終わりは、わざと同じにしてある。**
/// 練習中は腕を振っているので、弱い合図では気づけない。
/// 「そろそろ終わる」も「終わった」も、同じ強さで確実に伝わるほうがいい。
/// 全体の終わりだけは**長さ**で区別する。種類を変えても指では分からない。
///
/// iPhone と違い `intensity` は指定できない。強さは**回数**でしか作れない。
///
/// なお watchOS の触覚は、アプリが前面にあるか、ワークアウトが動いている間しか鳴らない。
/// 腕を下ろしたまま鳴らすには ``WorkoutKeeper`` が要る。
@MainActor
final class Haptics {

    /// 直前に流した連打。新しい通知が来たら止める（終了の合図に区切りの合図が重ならないように）。
    private var running: Task<Void, Never>?

    /// 連打の間隔。詰めすぎると1発に感じ、空けすぎると別々の合図に感じる。
    private static let gap = Duration.milliseconds(130)

    func play(_ event: TimerEvent) {
        running?.cancel()
        switch event {
        case .warning, .splitEnded:
            running = Task { await Self.burst(3) }
        case .finished:
            running = Task {
                await Self.burst(3)
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await Self.burst(3)
                guard !Task.isCancelled else { return }
                WKInterfaceDevice.current().play(.stop)
            }
        }
    }

    private static func burst(_ times: Int) async {
        for i in 0..<times {
            guard !Task.isCancelled else { return }
            WKInterfaceDevice.current().play(.notification)
            if i < times - 1 { try? await Task.sleep(for: gap) }
        }
    }
}
