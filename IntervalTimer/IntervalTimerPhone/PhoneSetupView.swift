import SwiftUI
import IntervalTimerCore
import IntervalTimerUI

struct PhoneSetupView: View {
    @Environment(PhoneRunner.self) private var runner

    @AppStorage("lastMinutes") private var minutes: Int = 20
    @AppStorage("lastParts") private var parts: Int = 4

    private var config: TimerConfig { TimerConfig(minutes: minutes, parts: parts) }

    var body: some View {
        ZStack {
            Skin.normal.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // これから何が起きるかを、円環で先に見せる
                // 走る前なので進み具合は無い。**色だけ見せる。**
                // 何等分するのかと、どんな色で進むのかが、押す前に分かる
                SegmentRing(parts: parts, index: 0, progressInSplit: 0,
                            skin: .normal, diameter: 190,
                            colors: Skin.normal.segmentColors(parts: parts),
                            lineWidth: 12, allDone: true)
                    .overlay {
                        VStack(spacing: 2) {
                            Text("/\(TimeText.brief(config.splitSeconds))")
                                .font(.system(size: 34, weight: .heavy, design: .rounded))
                                .foregroundStyle(Skin.normal.accent)
                            Text("1区切り")
                                .font(.subheadline)
                                .foregroundStyle(Skin.normal.inkDim)
                        }
                    }
                    .padding(.bottom, 28)

                PhoneStepRow(label: "全体", unit: String(localized: "分"),
                             tint: Color(hex: PaletteHex.totalInk),
                             value: $minutes, range: TimerConfig.minuteRange) { runner.stepped() }
                PhoneStepRow(label: "分割", unit: String(localized: "回"),
                             tint: Color(hex: PaletteHex.splitsInk),
                             value: $parts, range: TimerConfig.partsRange) { runner.stepped() }

                TimelineView(.everyMinute) { timeline in
                    HStack(spacing: 6) {
                        Text("終わり").foregroundStyle(Skin.normal.inkDim)
                        Text(timeline.date.addingTimeInterval(config.totalSeconds)
                                .formatted(date: .omitted, time: .shortened))
                            .fontWeight(.semibold)
                            .foregroundStyle(Skin.normal.ink)
                    }
                    .font(.callout)
                    .padding(.top, 18)
                }

                Spacer(minLength: 0)

                Button {
                    runner.start(config: config)
                } label: {
                    Text("開始")
                        .font(.title3.bold())
                        .foregroundStyle(Color(hex: PaletteHex.warnInk))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(hex: PaletteHex.startFill)))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .padding(.vertical, 20)
        }
    }
}

/// ＋ − の行。押しっぱなしで動き続けるのは Watch と同じ考え方。
struct PhoneStepRow: View {
    let label: LocalizedStringKey
    let unit: String
    let tint: Color
    @Binding var value: Int
    let range: ClosedRange<Int>
    let onStep: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            PhoneStepButton(systemName: "minus", tint: tint) { move(-1) }
            VStack(spacing: -2) {
                Text(label).font(.footnote.weight(.medium)).foregroundStyle(tint)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(value)")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Skin.normal.ink)
                    if !unit.isEmpty {
                        Text(unit).font(.footnote).foregroundStyle(tint.opacity(0.8))
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.18)))
            PhoneStepButton(systemName: "plus", tint: tint) { move(1) }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 5)
    }

    private func move(_ d: Int) {
        let v = (value + d).clamped(to: range)
        guard v != value else { return }
        value = v
        onStep()
    }
}

struct PhoneStepButton: View {
    let systemName: String
    let tint: Color
    let step: () -> Void
    @State private var holding: Task<Void, Never>?

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 62, height: 64)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(holding == nil ? 0.18 : 0.34)))
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 3600, pressing: { p in
                if p { begin() } else { end() }
            }, perform: {})
            .onDisappear { end() }
    }

    private func begin() {
        end()
        step()
        holding = Task { @MainActor in
            try? await Task.sleep(for: .seconds(HoldRepeat.delay))
            var done = 0
            while !Task.isCancelled {
                step()
                try? await Task.sleep(for: .seconds(HoldRepeat.interval(after: done)))
                done += 1
            }
        }
    }
    private func end() { holding?.cancel(); holding = nil }
}
