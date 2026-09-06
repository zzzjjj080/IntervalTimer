import SwiftUI
import IntervalTimerCore
import IntervalTimerUI

struct PhoneDoneView: View {
    @Environment(PhoneRunner.self) private var runner

    var body: some View {
        ZStack {
            Skin.done.background.ignoresSafeArea()
            GeometryReader { geo in
                let side = min(geo.size.width - 60, geo.size.height - 220)
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ZStack {
                        SegmentRing(parts: runner.display?.config.parts ?? 1,
                                    index: runner.display?.config.parts ?? 1,
                                    progressInSplit: 1, skin: .done, diameter: side,
                                    lineWidth: 14, allDone: true)
                        VStack(spacing: 6) {
                            Text("終了")
                                .font(.system(size: side * 0.20, weight: .heavy, design: .rounded))
                                .foregroundStyle(Skin.done.ink)
                            if let d = runner.display {
                                Text("\(d.config.minutes)分 / \(d.config.parts)区切り")
                                    .font(.subheadline)
                                    .foregroundStyle(Skin.done.inkDim)
                            }
                        }
                    }
                    .frame(width: side, height: side)
                    Spacer(minLength: 0)
                    VStack(spacing: 10) {
                        PhoneButton(title: "もう一度", skin: .done) { runner.again() }
                        PhoneButton(title: "設定に戻る", skin: .done) { runner.reset() }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}
