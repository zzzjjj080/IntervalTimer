import Foundation
import Observation
import UIKit
import IntervalTimerCore
import IntervalTimerUI

/// iPhone 側で画面とエンジンをつなぐところ。
///
/// 時間の測り方は Watch と同じ（``TimerEngine``）。違うのは背面の扱いだけ。
/// Watch はワークアウトで動き続けるが、**iPhone は裏に回ると止まる**ので、
/// 区切りの時刻をあらかじめ通知として登録しておく（``PhoneNotifier``）。
@MainActor
@Observable
final class PhoneRunner {

    enum Screen: Equatable { case setup, run, done }

    struct Display: Equatable {
        var config: TimerConfig
        var anchor: Date
        var index: Int
        var isWarning: Bool
        var isPaused: Bool
        var isFinished: Bool
        var frozenTotal: Double
        var frozenSplit: Double

        var skin: Skin {
            if isFinished { return .done }
            return isWarning ? .warning : .normal
        }
    }

    private(set) var screen: Screen = .setup
    private(set) var display: Display?
    /// 通知の許可が下りていないときに、画面へ出す1行。
    private(set) var note: String?

    private var engine: TimerEngine?
    private var ticker: Task<Void, Never>?
    private let haptics = PhoneHaptics()
    private let notifier = PhoneNotifier()

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
        // 走っている間は画面を消さない。消えると触覚も鳴らせなくなる
        UIApplication.shared.isIdleTimerDisabled = true
        #if DEBUG
        // 画面の見え方だけを確かめたいときに、許可ダイアログを出さないための逃げ道。
        // 合成タップはシステムダイアログに届かないので、ここでしか避けられない。
        if ProcessInfo.processInfo.environment["IT_NO_NOTIFY"] == "1" { return }
        #endif
        Task {
            await notifier.requestPermission()
            note = notifier.isAllowed ? nil
                 : String(localized: "通知が許可されていないので、画面を閉じている間はお知らせできません。")
        }
    }

    func pauseOrResume() {
        guard var e = engine else { return }
        switch e.phase {
        case .running: e.pause(at: Date())
        case .paused:  e.resume(at: Date())
        case .finished: return
        }
        engine = e
        haptics.step()
        refresh()
        Task { await notifier.clear() }
    }

    func reset() {
        stopTicking()
        engine = nil
        display = nil
        screen = .setup
        UIApplication.shared.isIdleTimerDisabled = false
        Task { await notifier.clear() }
    }

    func again() {
        guard var e = engine else { return }
        haptics.start()
        e.restart(at: Date())
        engine = e
        screen = .run
        refresh()
        startTicking()
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func stepped() { haptics.step() }

    /// 裏へ回るとき。**そこから先の合図を通知に預ける。**
    func goingToBackground() {
        // `.running` は開始時刻を持つので、`==` では比べられない
        guard let engine, case .running = engine.phase else { return }
        let s = engine.snapshot(at: Date())
        Task { await notifier.schedule(config: engine.config, anchor: s.anchor, from: Date()) }
    }

    /// 前に戻ったとき。通知は要らなくなるので消し、止まっていた間へ追いつく。
    func cameToForeground() {
        Task { await notifier.clear() }
        haptics.warmUp()
        tick()
    }

    // MARK: - 時計

    private func startTicking() {
        stopTicking()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: PhoneRunner.tickInterval)
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
        UIApplication.shared.isIdleTimerDisabled = false
        Task { await notifier.clear() }
    }

    /// 値が変わったときだけ書き込む。動いている間の残り時間はここに入れない。
    private func refresh() {
        guard let engine else { return }
        let s = engine.snapshot(at: Date())
        let paused = (engine.phase == .paused)
        let stopped = paused || s.isFinished
        let next = Display(
            config: engine.config, anchor: s.anchor, index: s.index,
            isWarning: s.isWarning, isPaused: paused, isFinished: s.isFinished,
            frozenTotal: stopped ? s.totalRemaining : 0,
            frozenSplit: stopped ? s.splitRemaining : 0)
        if display != next { display = next }
    }
}
