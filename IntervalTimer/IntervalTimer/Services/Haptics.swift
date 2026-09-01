import WatchKit
import IntervalTimerCore

/// 3種類の通知。強さの差でどれが起きたか分かるようにする。
///
/// | 場面 | 触覚 |
/// |---|---|
/// | 残り20% | `.click` を1発 |
/// | 区切りが0 | `.notification` を2回（0.15秒あけて） |
/// | 全体が0 | `.notification` を3回 ＋ `.stop` |
///
/// iPhone と違い `intensity` は指定できない。強さは「回数」でしか作れないので、
/// 種類ではなく**回数で差をつける**。
///
/// なお watchOS の触覚は、アプリが前面にあるか、ワークアウトが動いている間しか鳴らない。
/// 腕を下ろしたまま鳴らすには ``WorkoutKeeper`` が要る。
@MainActor
final class Haptics {

    /// 直前に流した連打。新しい通知が来たら止める（終了の3連打に区切りの2連打が重ならないように）。
    private var running: Task<Void, Never>?

    func play(_ event: TimerEvent) {
        running?.cancel()
        switch event {
        case .warning:
            WKInterfaceDevice.current().play(.click)
        case .splitEnded:
            burst(.notification, times: 2, gap: 0.15)
        case .finished:
            running = Task {
                for i in 0..<3 {
                    guard !Task.isCancelled else { return }
                    WKInterfaceDevice.current().play(.notification)
                    if i < 2 { try? await Task.sleep(for: .milliseconds(150)) }
                }
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                WKInterfaceDevice.current().play(.stop)
            }
        }
    }

    private func burst(_ type: WKHapticType, times: Int, gap: Double) {
        running = Task {
            for i in 0..<times {
                guard !Task.isCancelled else { return }
                WKInterfaceDevice.current().play(type)
                if i < times - 1 { try? await Task.sleep(for: .seconds(gap)) }
            }
        }
    }
}
