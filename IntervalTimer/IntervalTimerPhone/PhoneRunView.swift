import SwiftUI
import IntervalTimerCore
import IntervalTimerUI

struct PhoneRunView: View {
    @Environment(PhoneRunner.self) private var runner

    var body: some View {
        ZStack {
            let skin = runner.display?.skin ?? .normal
            skin.background.ignoresSafeArea()
                .animation(.easeInOut(duration: 0.35), value: skin)

            if let d = runner.display {
                GeometryReader { geo in
                    let side = min(geo.size.width - 40, geo.size.height - 190)
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        ZStack {
                            // 起点は区切りの終わり（`RingClock`）。Watch と同じ。`.now` だと数字と最大1秒ずれる
                            TimelineView(.ringTicks(anchor: d.anchor, config: d.config, index: d.index)) { t in
                                SegmentRing(parts: d.config.parts, index: d.index,
                                            progressInSplit: progress(d, at: t.date),
                                            skin: skin, diameter: side,
                                            colors: skin.segmentColors(parts: d.config.parts),
                                            lineWidth: 14)
                            }
                            numbers(d, skin: skin, width: side)
                        }
                        .frame(width: side, height: side)

                        Spacer(minLength: 0)

                        if let note = runner.note {
                            Text(note)
                                .font(.footnote)
                                .foregroundStyle(skin.inkDim)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 28)
                                .padding(.bottom, 10)
                        }

                        HStack(spacing: 12) {
                            PhoneButton(title: d.isPaused ? "再開" : "一時停止",
                                        skin: skin, tint: skin.goTint) { runner.pauseOrResume() }
                            PhoneButton(title: "リセット",
                                        skin: skin, tint: skin.stopTint) { runner.reset() }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
    }

    private func numbers(_ d: PhoneRunner.Display, skin: Skin, width: CGFloat) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                Text("全体").font(.subheadline).foregroundStyle(skin.inkDim)
                totalText(d).font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(skin.ink)
            }
            splitText(d)
                .font(.system(size: width * 0.30, weight: .heavy, design: .rounded))
                .monospacedDigit().minimumScaleFactor(0.35).lineLimit(1)
                .foregroundStyle(skin.ink)
            Text("\(d.index + 1) / \(d.config.parts)")
                .font(.headline).foregroundStyle(skin.inkDim)
        }
        .frame(width: max(60, width - 60))
    }

    /// 1秒単位で塗る（`RingClock`。Watch と同じ計算）
    private func progress(_ d: PhoneRunner.Display, at now: Date) -> Double {
        RingClock.progress(elapsed: elapsed(d, at: now), config: d.config, index: d.index)
    }

    private func elapsed(_ d: PhoneRunner.Display, at now: Date) -> Double {
        if d.isPaused || d.isFinished { return d.config.totalSeconds - d.frozenTotal }
        return min(max(0, now.timeIntervalSince(d.anchor)), d.config.totalSeconds)
    }

    // 動いている間はシステムに描かせる。止まっている間は素のテキスト。
    @ViewBuilder
    private func totalText(_ d: PhoneRunner.Display) -> some View {
        if d.isPaused || d.isFinished {
            Text(TimeText.clock(d.frozenTotal))
        } else {
            Text(timerInterval: d.anchor...d.anchor.addingTimeInterval(d.config.totalSeconds),
                 pauseTime: nil, countsDown: true, showsHours: true)
        }
    }

    @ViewBuilder
    private func splitText(_ d: PhoneRunner.Display) -> some View {
        if d.isPaused || d.isFinished {
            Text(TimeText.clock(d.frozenSplit))
        } else {
            let from = d.anchor.addingTimeInterval(d.config.boundary(d.index))
            let to = d.anchor.addingTimeInterval(d.config.boundary(d.index + 1))
            Text(timerInterval: from...to, pauseTime: nil, countsDown: true, showsHours: true)
        }
    }
}

struct PhoneButton: View {
    let title: LocalizedStringKey
    let skin: Skin
    var tint: Color? = nil
    let action: () -> Void

    private var face: Color { tint ?? skin.ink }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(face)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(face.opacity(0.16)))
        }
        .buttonStyle(.plain)
    }
}
