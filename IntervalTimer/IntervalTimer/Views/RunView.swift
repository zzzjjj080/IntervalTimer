import SwiftUI
import IntervalTimerCore

struct RunView: View {
    @Environment(Runner.self) private var runner
    @Environment(\.scenePhase) private var phase

    var body: some View {
        ZStack {
            let skin = runner.display?.skin ?? .normal
            skin.background
                .ignoresSafeArea()
                // 屋外で目を上げた瞬間に「変わった」と分かるだけの速さ。
                .animation(.easeInOut(duration: 0.35), value: skin)

            if let d = runner.display {
                content(d, skin: skin)
            }
        }
        // 裏から戻ったときに一気に追いつかせる。`.task` は最初の1回しか走らないので、
        // これが無いと復帰直後だけ古い数字が残る。
        .onChange(of: phase) { _, new in
            if new == .active { runner.catchUp() }
        }
    }

    @ViewBuilder
    private func content(_ d: Runner.Display, skin: Skin) -> some View {
        VStack(spacing: 0) {

            // 全体の残り（小さめ）
            HStack(spacing: 6) {
                Text("全体")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(skin.inkDim)
                totalText(d)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(skin.ink)
            }
            .padding(.top, 2)

            Spacer(minLength: 2)

            // 現在の区切りの残り（画面の主役）
            splitText(d)
                .accessibilityIdentifier("splitRemaining")
                .font(.system(size: 60, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .foregroundStyle(skin.ink)

            Spacer(minLength: 2)

            Text("\(d.index + 1) / \(d.config.parts)")
                .accessibilityIdentifier("splitIndex")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(skin.inkDim)
                .padding(.bottom, 6)

            SegmentBar(parts: d.config.parts, index: d.index, skin: skin)
                .padding(.bottom, 8)

            if let note = runner.backgroundNote {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(skin.inkDim)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.bottom, 6)
            }

            HStack(spacing: 6) {
                SmallButton(title: d.isPaused ? "再開" : "一時停止", skin: skin) {
                    runner.pauseOrResume()
                }
                .accessibilityIdentifier("pause")
                SmallButton(title: "リセット", skin: skin) {
                    runner.reset()
                }
                .accessibilityIdentifier("reset")
            }
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 2)
    }

    // MARK: - 秒の描画

    // 動いている間は `Text(timerInterval:)` を使う。システム側が描画を維持するので、
    // 常時表示（Always-On）のままでもアプリのコードを動かさずに数字が進む。
    // 止まっている間は動かないので、素のテキストにする。

    // `showsHours` は常に true を渡す。あちらの true は「常に時を出す」ではなく
    // 「1時間を超えたら出す」で、`TimeText.clock` の既定と同じ判断になる。
    // 設定の長さで true/false を出し分けると、逆に両者がずれる。

    @ViewBuilder
    private func totalText(_ d: Runner.Display) -> some View {
        if d.isPaused || d.isFinished {
            Text(TimeText.clock(d.frozenTotal))
        } else {
            Text(timerInterval: d.anchor...d.anchor.addingTimeInterval(d.config.totalSeconds),
                 pauseTime: nil, countsDown: true, showsHours: true)
        }
    }

    @ViewBuilder
    private func splitText(_ d: Runner.Display) -> some View {
        if d.isPaused || d.isFinished {
            Text(TimeText.clock(d.frozenSplit))
        } else {
            let from = d.anchor.addingTimeInterval(d.config.boundary(d.index))
            let to = d.anchor.addingTimeInterval(d.config.boundary(d.index + 1))
            Text(timerInterval: from...to, pauseTime: nil, countsDown: true, showsHours: true)
        }
    }
}

/// 実行画面の下に並べる小さいボタン。指1本ぶん（44pt）は確保する。
struct SmallButton: View {
    let title: String
    let skin: Skin
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                // Button は中の文字色を勝手に上書きするので、自分で指定し直す。
                .foregroundStyle(skin.ink)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(skin.ink.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }
}
