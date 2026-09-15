import SwiftUI
import WatchKit
import IntervalTimerCore
import IntervalTimerUI

/// ＋ − のボタン。**押している間、増え続ける（減り続ける）。**
///
/// `Button` ではなく長押しで受けている。`Button` は指を離したときにしか呼ばれないので、
/// 押しっぱなしを拾えない。`pressing:` なら押した瞬間と離した瞬間の両方が来る。
///
/// グローブでも押せるよう、幅と高さは呼び出し側が決める（高さの既定は44pt）。
/// 設定画面はスクロールさせないので、画面の高さから割り振った高さを渡す。
/// `minus.circle` のような細い記号は避け、太い `minus` / `plus` を使う。
struct StepButton: View {
    let systemName: String
    /// 増やす側か。触覚の向きを決める
    let isUp: Bool
    let tint: Color
    let width: CGFloat
    var height: CGFloat = 44
    let step: () -> Void

    @State private var holding: Task<Void, Never>?

    var body: some View {
        Image(systemName: systemName)
            // 記号の大きさも高さに合わせる。小さい画面で記号だけ大きく残らないように
            .font(.system(size: max(13, min(18, height * 0.40)), weight: .bold))
            .foregroundStyle(tint)
            .frame(width: width, height: height)
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
