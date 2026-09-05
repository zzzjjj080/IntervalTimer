import SwiftUI
import IntervalTimerCore

struct RootView: View {
    @Environment(Runner.self) private var runner

    var body: some View {
        screens
            .task { startForCheckingIfAsked() }
    }

    @ViewBuilder
    private var screens: some View {
        switch runner.screen {
        case .setup: SetupView()
        case .run:   RunView()
        case .done:  DoneView()
        }
    }

    /// シミュレータでの動作確認用の入口。
    ///
    /// 合成タップはシートやダイアログに届かず「実装が壊れている」ように見えるので、
    /// 確認したい画面へは環境変数で直接入る。
    ///
    ///     SIMCTL_CHILD_IT_START="20,4,239" xcrun simctl launch booted com.zzzjjj080.IntervalTimer
    ///
    /// 3つめは「何秒前に始まったことにするか」。警告や終了の状態をすぐ出せる。
    /// **リリース構成には入らない。** `strings` で確かめること。
    private func startForCheckingIfAsked() {
        #if DEBUG
        guard runner.screen == .setup,
              let spec = ProcessInfo.processInfo.environment["IT_START"] else { return }
        let n = spec.split(separator: ",").compactMap { Int($0) }
        guard n.count >= 2 else { return }
        runner.start(config: TimerConfig(minutes: n[0], parts: n[1]),
                     backdated: n.count > 2 ? TimeInterval(n[2]) : 0)
        // `IT_PAUSED=1` で、一時停止した状態の画面をそのまま出す。
        if ProcessInfo.processInfo.environment["IT_PAUSED"] == "1" { runner.pauseOrResume() }
        #endif
    }
}
