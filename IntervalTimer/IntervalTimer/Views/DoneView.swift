import SwiftUI
import WatchKit
import IntervalTimerCore

struct DoneView: View {
    @Environment(Runner.self) private var runner

    /// ボタン2つぶん。
    private static let controlsHeight: CGFloat = 96
    private static let clockReserve: CGFloat = 18

    /// 実行画面と同じ考え方で、画面の実寸から決める。
    private var ringSide: CGFloat {
        let screen = WKInterfaceDevice.current().screenBounds.size
        return max(80, min(screen.width - 24,
                           screen.height - Self.clockReserve - Self.controlsHeight - 8))
    }

    var body: some View {
        ZStack {
            Skin.done.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    // 実行中と同じ円環を、全部塗った状態で出す。
                    // 別の見せ方にすると、終わった瞬間に画面が別物になって戸惑う。
                    SegmentRing(parts: runner.display?.config.parts ?? 1,
                                index: runner.display?.config.parts ?? 1,
                                progressInSplit: 1,
                                skin: .done,
                                diameter: ringSide,
                                allDone: true)

                    VStack(spacing: 2) {
                        Text("終了")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(Skin.done.ink)
                        if let d = runner.display {
                            Text("\(d.config.minutes)分 / \(d.config.parts)区切り")
                                .font(.system(size: 13))
                                .foregroundStyle(Skin.done.inkDim)
                        }
                    }
                    .frame(width: max(40, ringSide - 30))
                }
                .frame(width: ringSide, height: ringSide)

                Spacer(minLength: 0)

                SmallButton(title: "もう一度", skin: .done) { runner.again() }
                    .accessibilityIdentifier("again")
                    .padding(.bottom, 6)
                SmallButton(title: "設定に戻る", skin: .done) { runner.reset() }
                    .accessibilityIdentifier("backToSetup")
            }
            .padding(.top, Self.clockReserve)
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
        .ignoresSafeArea()
    }
}
