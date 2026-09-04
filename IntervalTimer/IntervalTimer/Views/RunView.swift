import SwiftUI
import WatchKit
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
        // 安全領域を外すのはここ1か所だけ。内側で重ねて外すと、かえって狭くなる。
        .ignoresSafeArea()
        // 裏から戻ったときに一気に追いつかせる。`.task` は最初の1回しか走らないので、
        // これが無いと復帰直後だけ古い数字が残る。
        .onChange(of: phase) { _, new in
            if new == .active { runner.catchUp() }
        }
    }

    /// 下のボタンに残しておく高さ。グローブでも押せるよう44ptは確保する。
    private static let controlsHeight: CGFloat = 48
    /// 上に空ける高さ。ここにシステムの時計が出るので、円環をぶつけない。
    private static let clockReserve: CGFloat = 18

    /// 円環の直径。
    ///
    /// **レイアウトに測らせない。** `GeometryReader` が返す高さは安全領域の扱いで
    /// 157ptにも210ptにもなり、そのたびに円環の大きさが変わって数字と重なった。
    /// 画面の実寸から自分で決めれば、機種が変わっても1か所で効く。
    private var ringSide: CGFloat {
        let screen = WKInterfaceDevice.current().screenBounds.size
        let byWidth = screen.width - 24
        let byHeight = screen.height - Self.clockReserve - Self.controlsHeight - 8
        return max(90, min(byWidth, byHeight))
    }

    @ViewBuilder
    private func content(_ d: Runner.Display, skin: Skin) -> some View {
        VStack(spacing: 0) {
            ZStack {
                // 円環だけを1秒ごとに描き直す。
                // 秒の数字はシステムが描いているので、こちらの都合で巻き込まない。
                // 0.1秒ごとにすると滑らかになるが、1区切り5分なら1秒で弧の1/300しか進まず、
                // 目では段が見えない。腕に着けて1時間動かすものなので、粗いほうを選ぶ。
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    SegmentRing(parts: d.config.parts,
                                index: d.index,
                                progressInSplit: progressInSplit(d, at: timeline.date),
                                skin: skin,
                                diameter: ringSide)
                }
                numbers(d, skin: skin, width: ringSide)
            }
            .frame(width: ringSide, height: ringSide)

            Spacer(minLength: 0)

            if let note = runner.backgroundNote {
                Text(note)
                    .font(.system(size: 10))
                    .foregroundStyle(skin.inkDim)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
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
        .padding(.top, Self.clockReserve)
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }

    /// 円環の内側。ここは数字が変わった瞬間しか描き直されない。
    private func numbers(_ d: Runner.Display, skin: Skin, width: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                Text("全体")
                    .font(.system(size: 12))
                    .foregroundStyle(skin.inkDim)
                totalText(d)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(skin.ink)
            }

            splitText(d)
                .accessibilityIdentifier("splitRemaining")
                .font(.system(size: 54, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.35)
                .lineLimit(1)
                .foregroundStyle(skin.ink)
                .padding(.vertical, 1)

            Text("\(d.index + 1) / \(d.config.parts)")
                .accessibilityIdentifier("splitIndex")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(skin.inkDim)
        }
        // 円環の線に文字がかからない幅に収める。
        // 円の内側なので、上下の行は中央より狭いところに来る。
        .frame(width: max(40, width - lineInset))
    }

    /// 円環の線ぶん＋見た目の余裕。文字が弧に触れない幅にする。
    private let lineInset: CGFloat = 30

    // MARK: - 円環の進み具合

    /// いまの区切りをどこまで進んだか。0...1。
    private func progressInSplit(_ d: Runner.Display, at now: Date) -> Double {
        let from = d.config.boundary(d.index)
        let to = d.config.boundary(d.index + 1)
        guard to > from else { return 0 }
        return ((elapsed(d, at: now) - from) / (to - from)).clamped(to: 0...1)
    }

    /// 開始からの経過。止まっている間は動かない。
    ///
    /// `Runner` はこの値を持っていない。1秒に10回変わる値を持たせると、
    /// 画面全体が同じ回数だけ描き直されてしまうため。ここで時刻から出す。
    private func elapsed(_ d: Runner.Display, at now: Date) -> Double {
        if d.isPaused || d.isFinished { return d.config.totalSeconds - d.frozenTotal }
        return min(max(0, now.timeIntervalSince(d.anchor)), d.config.totalSeconds)
    }

    // MARK: - 秒の描画

    // 動いている間は `Text(timerInterval:)` を使う。システム側が描画を維持するので、
    // 常時表示（Always-On）のままでもアプリのコードを動かさずに数字が進む。
    // 止まっている間は動かないので、素のテキストにする。
    //
    // `showsHours` は常に true を渡す。あちらの true は「常に時を出す」ではなく
    // 「1時間を超えたら出す」で、`TimeText.clock` の既定と同じ判断になる。

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
