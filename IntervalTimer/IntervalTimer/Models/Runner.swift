import Foundation
import Observation
import IntervalTimerCore

/// 画面と ``TimerEngine`` をつなぐところ。時計を進め、起きたことを触覚に流す。
///
/// **画面へ出す値をわざと少なくしてある。** 秒の数字は
/// `Text(timerInterval:)` にシステムが描かせるので、ここが1秒に10回動くと台無しになる。
/// ここが持つのは「区切りが変わった」「警告に入った」のような、
/// **本当に変わった瞬間にしか動かない値**だけ。
@MainActor
@Observable
final class Runner {

    enum Screen: Equatable { case setup, run, done }

    /// 実行画面が見るぶん。中身が変わらない限り再描画は起きない。
    struct Display: Equatable {
        var config: TimerConfig
        /// `Text(timerInterval:)` の起点。動いている間は変わらない。
        var anchor: Date
        var index: Int
        var isWarning: Bool
        var isPaused: Bool
        var isFinished: Bool
        /// 一時停止中・終了後に出す固定の残り時間。動いている間は使わない。
        var frozenTotal: Double
        var frozenSplit: Double

        var skin: Skin {
            if isFinished { return .done }
            return isWarning ? .warning : .normal
        }
    }

    private(set) var screen: Screen = .setup
    private(set) var display: Display?

    /// 背面で動かし続けるための仕掛け。画面から状態を見せる。
    let keeper = WorkoutKeeper()

    /// 前回の実行で背面動作を確保できなかったときの注意書き。設定画面に1行出す。
    private(set) var backgroundNote: String?

    private var engine: TimerEngine?
    private var ticker: Task<Void, Never>?

    /// ワークアウトの開始・終了を1本の列に並べる。
    /// 「終了」と、その直後の「もう一度」の開始が同時に走ると、
    /// 終了処理が、始まったばかりのセッションを畳んでしまう。
    private var keeperWork: Task<Void, Never>?
    private let haptics = Haptics()

    /// 判定の間隔。1秒ごとだと20%に達した瞬間の検出が最大1秒遅れる。
    private static let tickInterval = Duration.milliseconds(100)

    // MARK: - 操作

    /// `backdated` を与えると、その秒数だけ前に始まったことにして実行画面へ入る。
    /// 動作確認で、警告や終了の状態をすぐ出すために使う。通常の開始は0。
    func start(config: TimerConfig, backdated: TimeInterval = 0) {
        haptics.start()
        engine = TimerEngine(config: config, startedAt: Date().addingTimeInterval(-backdated))
        screen = .run
        refresh()
        startTicking()
        keepAwake()
    }

    func pauseOrResume() {
        guard var e = engine else { return }
        switch e.phase {
        case .running: e.pause(at: Date())
        case .paused:  e.resume(at: Date())
        case .finished: return
        }
        engine = e
        refresh()
    }

    /// 実行をやめて設定画面へ戻る。
    func reset() {
        stopTicking()
        engine = nil
        display = nil
        screen = .setup
        letGo()
    }

    /// 終了画面の「もう一度」。同じ設定で最初から。
    func again() {
        guard var e = engine else { return }
        haptics.start()
        e.restart(at: Date())
        engine = e
        screen = .run
        refresh()
        startTicking()
        keepAwake()
    }

    /// 裏から戻ってきたときに呼ぶ。止まっていた間のぶんへ一気に追いつく。
    func catchUp() {
        tick()
    }

    // MARK: - 時計

    private func startTicking() {
        stopTicking()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: Runner.tickInterval)
            }
        }
    }

    private func stopTicking() {
        ticker?.cancel()
        ticker = nil
    }

    private func tick() {
        guard var e = engine else { return }
        let events = e.advance(to: Date())
        engine = e

        for event in events {
            haptics.play(event)
            if event == .finished { finish() }
        }
        refresh()
    }

    private func finish() {
        stopTicking()
        screen = .done
        letGo()
    }

    /// 値が変わったときだけ書き込む。毎回入れ直すと、中身が同じでも画面が描き直される。
    private func refresh() {
        guard let engine else { return }
        let s = engine.snapshot(at: Date())
        let paused = (engine.phase == .paused)

        // 動いている間の残り時間はここに入れない。1秒に10回変わってしまい、
        // そのたびに画面が描き直される。動いている間の数字はシステムに描かせている。
        let stopped = paused || s.isFinished

        let next = Display(
            config: engine.config,
            anchor: s.anchor,
            index: s.index,
            isWarning: s.isWarning,
            isPaused: paused,
            isFinished: s.isFinished,
            frozenTotal: stopped ? s.totalRemaining : 0,
            frozenSplit: stopped ? s.splitRemaining : 0
        )
        if display != next { display = next }
    }

    // MARK: - 背面動作

    private func keepAwake() {
        #if DEBUG
        // 画面の見え方だけを確かめたいときに、ヘルスケアの許可ダイアログを出さないための逃げ道。
        // シミュレータにはヘルスケアの許可を外から与える手段が無く、
        // 合成タップもシステムダイアログには届かないので、ここでしか避けられない。
        // 背面動作そのものの確認は実機でやる。
        if ProcessInfo.processInfo.environment["IT_NO_WORKOUT"] == "1" { return }
        #endif
        let previous = keeperWork
        keeperWork = Task {
            await previous?.value
            await keeper.start()
            #if DEBUG
            print("[Runner] keeper.mode = \(keeper.mode) / errors = \(keeper.errors)")
            #endif
            switch keeper.mode {
            case .workout:
                backgroundNote = nil
            case .extended:
                backgroundNote = String(localized: "予備の手段で動いています。連続で動ける時間に上限があります。")
            case .none:
                // 理由を消さずにそのまま出す。「押しても何も起きない」が一番たちが悪い。
                backgroundNote = (keeper.firstError ?? String(localized: "背面で動かせません。")) + String(localized: "画面を消すとタイマーが止まります。")
            }
        }
    }

    private func letGo() {
        let previous = keeperWork
        keeperWork = Task {
            await previous?.value
            await keeper.end()
        }
    }
}
