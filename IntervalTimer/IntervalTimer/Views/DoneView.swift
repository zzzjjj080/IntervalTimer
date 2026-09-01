import SwiftUI
import IntervalTimerCore

struct DoneView: View {
    @Environment(Runner.self) private var runner

    var body: some View {
        ZStack {
            Skin.done.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                Text("終了")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Skin.done.ink)

                if let d = runner.display {
                    Text("\(d.config.minutes)分 / \(d.config.parts)区切り")
                        .font(.system(size: 14))
                        .foregroundStyle(Skin.done.inkDim)
                        .padding(.top, 4)

                    SegmentBar(parts: d.config.parts, index: d.config.parts, skin: .done, allDone: true)
                        .padding(.top, 10)
                }

                Spacer(minLength: 0)

                SmallButton(title: "もう一度", skin: .done) { runner.again() }
                    .padding(.bottom, 6)
                SmallButton(title: "設定に戻る", skin: .done) { runner.reset() }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
    }
}
