import SwiftUI
import WatchKit
import IntervalTimerCore

/// ＋ − のボタン。**押している間、増え続ける（減り続ける）。**
///
/// `Button` ではなく長押しで受けている。`Button` は指を離したときにしか呼ばれないので、
/// 押しっぱなしを拾えない。`pressing:` なら押した瞬間と離した瞬間の両方が来る。
///
/// グローブでも押せるよう、高さ44pt・幅は呼び出し側が決める。
/// `minus.circle` のような細い記号は避け、太い `minus` / `plus` を使う。
struct StepButton: View {
    let systemName: String
    /// 増やす側か。触覚の向きを決める
    let isUp: Bool
    let tint: Color
    let width: CGFloat
    let step: () -> Void

    @State private var holding: Task<Void, Never>?

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: width, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(holding == nil ? 0.16 : 0.34))
            )
            .contentShape(Rectangle())
            // 押し続けても `perform` が呼ばれないよう、長い時間を指定しておく。
            // 使うのは `pressing` のほうだけ。
            .onLongPressGesture(minimumDuration: 3600, pressing: { pressing in
                if pressing { begin() } else { end() }
            }, perform: {})
            .onDisappear { end() }
    }

    private func begin() {
        end()
        step()
        Haptics.step(up: isUp)

        holding = Task { @MainActor in
            // 押した瞬間から走り出させない。1つだけ変えたいときに行き過ぎる
            try? await Task.sleep(for: .seconds(HoldRepeat.delay))
            var done = 0
            while !Task.isCancelled {
                step()
                // 連続で鳴らすと震えっぱなしになる。速くなってからは間引く
                if done % 3 == 0 { Haptics.step(up: isUp) }
                try? await Task.sleep(for: .seconds(HoldRepeat.interval(after: done)))
                done += 1
            }
        }
    }

    private func end() {
        holding?.cancel()
        holding = nil
    }
}
