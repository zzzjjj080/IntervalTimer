import WatchKit
import IntervalTimerCore

/// 触覚。**アプリの触覚はここに全部集める。**
///
/// watchOS には iPhone の `intensity` に当たるものが無い。
/// 強さは **種類と回数と間隔** でしか作れないので、散らばると強弱の設計ができなくなる。
///
/// | 場面 | 触覚 | ねらい |
/// |---|---|---|
/// | ＋ を押した | `.directionUp` | 増えたことが向きで分かる |
/// | − を押した | `.directionDown` | 減ったことが向きで分かる |
/// | 開始 | `.start` ＋ `.notification` | 走り出した手応え |
/// | 区切りの75% | `.notification` ×4 | 練習中の腕でも気づける強さ |
/// | 区切りが0 | 同じ ×4 | 途中と終わりは同じでよい |
/// | 全体が0 | ×4 → 間 → ×4 ＋ `.stop` | **長さ**で区別する |
///
/// 種類を変えても指では区別できない。**回数と長さで差をつける。**
///
/// なお watchOS の触覚は、アプリが前面にあるか、ワークアウトが動いている間しか鳴らない。
/// 腕を下ろしたまま鳴らすには ``WorkoutKeeper`` が要る。
@MainActor
final class Haptics {

    /// 直前に流した連打。新しい合図が来たら止める（終了の合図に区切りの合図が重ならないように）。
    private var running: Task<Void, Never>?

    /// 連打の間隔。詰めすぎると1発に感じ、空けすぎると別々の合図に感じる。
    private static let gap = Duration.milliseconds(110)

    /// 区切りの合図の回数。**ここを増やすと強くなる。**
    private static let cueTaps = 4

    // MARK: - タイマーの合図

    func play(_ event: TimerEvent) {
        running?.cancel()
        switch event {
        case .warning, .splitEnded:
            running = Task { await Self.burst(Self.cueTaps) }
        case .finished:
            running = Task {
                await Self.burst(Self.cueTaps)
                try? await Task.sleep(for: .milliseconds(280))
                guard !Task.isCancelled else { return }
                await Self.burst(Self.cueTaps)
                guard !Task.isCancelled else { return }
                WKInterfaceDevice.current().play(.stop)
            }
        }
    }

    // MARK: - 操作の手応え

    /// 数字を1つ動かした。向きが分かる触覚にしてある。
    /// `.click` だと弱くて、手袋越しでは分からない。
    static func step(up: Bool) {
        WKInterfaceDevice.current().play(up ? .directionUp : .directionDown)
    }

    /// 走り出した。押した実感が要るので2つ重ねる。
    func start() {
        running?.cancel()
        running = Task {
            WKInterfaceDevice.current().play(.start)
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            WKInterfaceDevice.current().play(.notification)
        }
    }

    // MARK: - 内部

    private static func burst(_ times: Int) async {
        for i in 0..<times {
            guard !Task.isCancelled else { return }
            WKInterfaceDevice.current().play(.notification)
            if i < times - 1 { try? await Task.sleep(for: gap) }
        }
    }
}
