import SwiftUI
import IntervalTimerCore
import IntervalTimerUI

struct PhoneRootView: View {
    @State private var runner = PhoneRunner()
    @Environment(\.scenePhase) private var phase

    var body: some View {
        Group {
            switch runner.screen {
            case .setup: PhoneSetupView()
            case .run:   PhoneRunView()
            case .done:  PhoneDoneView()
            }
        }
        .environment(runner)
        // 裏へ回るときに通知へ預け、戻ったら消して追いつく。
        // `.task` は最初の1回しか走らないので、これが無いと復帰で古い数字が残る。
        .task { startForCheckingIfAsked() }
        .onChange(of: phase) { _, new in
            switch new {
            case .active:     runner.cameToForeground()
            case .background: runner.goingToBackground()
            default: break
            }
        }
    }

    /// シミュレータでの動作確認用の入口。Watch 側と同じ仕組み。
    ///
    ///     SIMCTL_CHILD_IT_START="20,4,700" xcrun simctl launch <udid> com.zzzjjj080.IntervalTimer
    ///
    /// **リリース構成には入らない。** `strings` で確かめること。
    private func startForCheckingIfAsked() {
        #if DEBUG
        guard runner.screen == .setup,
              let spec = ProcessInfo.processInfo.environment["IT_START"] else { return }
        let n = spec.split(separator: ",").compactMap { Int($0) }
        guard n.count >= 2 else { return }
        runner.start(config: TimerConfig(minutes: n[0], parts: n[1]),
                     backdated: n.count > 2 ? TimeInterval(n[2]) : 0)
        #endif
    }
}
