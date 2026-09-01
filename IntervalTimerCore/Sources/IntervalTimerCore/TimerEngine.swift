import Foundation

/// 区切りの節目に起きること。ハプティクスと色の切り替えはこれを見て決める。
public enum TimerEvent: Equatable, Sendable {
    /// 今の区切りの残りが20%以下になった。区切りごとに1回だけ出る。
    case warning
    /// 区切りが0になり、次の区切りへ入った。`nextIndex` は0始まり。
    case splitEnded(nextIndex: Int)
    /// 全体が0になった。
    case finished
}

/// 画面に出す値を1回ぶんまとめたもの。
public struct TimerSnapshot: Equatable, Sendable {
    public let elapsed: Double
    public let totalRemaining: Double
    public let splitRemaining: Double
    public let splitLength: Double
    /// 今の区切り（0始まり）。画面には `index + 1` を出す。
    public let index: Int
    public let isWarning: Bool
    public let isFinished: Bool
    public let isRunning: Bool
    /// 仮想的な開始時刻（`now - elapsed`）。
    /// 一時停止を挟んでも、ここを基準にすれば区切りの境界が実時刻で表せる。
    /// `Text(timerInterval:)` に渡す範囲はここから作る。
    public let anchor: Date

    /// 画面に出す区切り番号（1始まり）。
    public var displayIndex: Int { index + 1 }
}

/// 経過時間の算出・区切りの判定・状態遷移。UIには依存しない。
///
/// **1秒ずつ減算する実装にはしていない。** 経過は常に「現在時刻 − 開始時刻 ＋ 停止までの累積」で出す。
/// 画面が消えてもアプリが止まっても、次に時刻を渡した瞬間に正しい値へ追いつく。
///
/// 時刻は必ず引数で受け取る。テストから任意に進められるようにするため。
public struct TimerEngine: Equatable, Sendable {

    public enum Phase: Equatable, Sendable {
        case running(since: Date)
        case paused
        case finished
    }

    public let config: TimerConfig
    public private(set) var phase: Phase

    /// 「一度も止めずにここまで来ていたら、開始はこの時刻だったことになる」という仮想の開始時刻。
    ///
    /// 動いている間は変わらない。再開したときだけ、止まっていた秒数ぶん後ろへずらす。
    /// 経過を「累積 ＋ 今回ぶん」で持つより誤差が乗りにくく、
    /// 画面が1秒に10回描き直されるのを防げる（値が動かないので再描画が起きない）。
    private var virtualStart: Date

    /// 一時停止中・終了後に固定した経過秒数。
    private var frozenElapsed: Double

    /// 最後に通知した区切り。ここが変わったら「区切りが終わった」。
    private var lastIndex: Int
    /// 今の区切りで20%通知をもう出したか。区切りが変わったら false に戻す。
    private var warned: Bool

    public init(config: TimerConfig, startedAt: Date) {
        self.config = config
        self.phase = .running(since: startedAt)
        self.virtualStart = startedAt
        self.frozenElapsed = 0
        self.lastIndex = 0
        self.warned = false
    }

    /// `Text(timerInterval:)` に渡す範囲の起点。
    ///
    /// 動いている間ずっと同じ値なので、これを基準にすれば
    /// 秒の描画をシステムに任せられる（常時表示のままでも数字が進む）。
    public var anchor: Date { virtualStart }

    // MARK: - 経過時間

    /// 開始からの経過秒数。全体秒数を超えない。
    ///
    /// **1秒ずつ足していない。** 現在時刻と仮想開始時刻の差なので、
    /// 何秒アプリが止まっていようと、次に呼ばれた瞬間に正しい値になる。
    public func elapsed(at now: Date) -> Double {
        switch phase {
        case .running:
            // 時刻が巻き戻ったときに負にならないよう max を挟む。
            return min(max(0, now.timeIntervalSince(virtualStart)), config.totalSeconds)
        case .paused, .finished:
            return min(frozenElapsed, config.totalSeconds)
        }
    }

    /// 今の区切り（0始まり）。
    ///
    /// 1区切りの秒数を足し込まず、割り算1回で出している。丸め誤差が溜まらない。
    public func index(at elapsed: Double) -> Int {
        guard elapsed > 0, config.totalSeconds > 0 else { return 0 }
        let raw = Int(floor(elapsed * Double(config.parts) / config.totalSeconds))
        return raw.clamped(to: 0...(config.parts - 1))
    }

    // MARK: - 進める

    /// 時刻を進め、その間に起きたことを返す。
    ///
    /// 裏に回っていて何区切りぶんも飛んでいた場合でも、`splitEnded` は1回だけ返す。
    /// 溜まっていた振動をまとめて鳴らしても意味がないため。
    public mutating func advance(to now: Date) -> [TimerEvent] {
        guard case .running = phase else { return [] }

        let e = elapsed(at: now)

        if e >= config.totalSeconds {
            frozenElapsed = config.totalSeconds
            phase = .finished
            lastIndex = config.parts - 1
            warned = true
            return [.finished]
        }

        var events: [TimerEvent] = []

        let idx = index(at: e)
        if idx != lastIndex {
            lastIndex = idx
            warned = false
            events.append(.splitEnded(nextIndex: idx))
        }

        if !warned, config.givesWarning, remainingInSplit(at: e, index: idx) <= splitLength(index: idx) * TimerConfig.warningRatio {
            warned = true
            events.append(.warning)
        }

        return events
    }

    // MARK: - 状態遷移

    public mutating func pause(at now: Date) {
        guard case .running = phase else { return }
        frozenElapsed = elapsed(at: now)
        phase = .paused
    }

    public mutating func resume(at now: Date) {
        guard case .paused = phase else { return }
        // 止まっていたぶんだけ仮想の開始時刻を後ろへずらす。ここで1回だけ計算しておけば、
        // 以後は動いている間ずっと同じ値のままになる。
        virtualStart = now.addingTimeInterval(-frozenElapsed)
        phase = .running(since: virtualStart)
    }

    /// 同じ設定で最初からやり直す（終了画面の「もう一度」）。
    public mutating func restart(at now: Date) {
        virtualStart = now
        frozenElapsed = 0
        lastIndex = 0
        warned = false
        phase = .running(since: now)
    }

    // MARK: - 表示用

    public func snapshot(at now: Date) -> TimerSnapshot {
        let e = elapsed(at: now)
        let finished = (phase == .finished) || e >= config.totalSeconds
        let idx = finished ? config.parts - 1 : index(at: e)
        let left = finished ? 0 : remainingInSplit(at: e, index: idx)
        let length = splitLength(index: idx)
        let running: Bool
        if case .running = phase { running = !finished } else { running = false }

        return TimerSnapshot(
            elapsed: e,
            totalRemaining: max(0, config.totalSeconds - e),
            splitRemaining: left,
            splitLength: length,
            index: idx,
            // 色は「今そうであるか」で決める。1回だけのフラグ(`warned`)は振動用で、こちらには使わない。
            // 裏から復帰したときも、その瞬間の残り時間だけを見て正しい色になる。
            isWarning: !finished && config.givesWarning && left <= length * TimerConfig.warningRatio,
            isFinished: finished,
            isRunning: running,
            anchor: virtualStart
        )
    }

    // MARK: - 内部

    private func splitLength(index i: Int) -> Double {
        config.boundary(i + 1) - config.boundary(i)
    }

    private func remainingInSplit(at elapsed: Double, index i: Int) -> Double {
        max(0, config.boundary(i + 1) - elapsed)
    }
}
