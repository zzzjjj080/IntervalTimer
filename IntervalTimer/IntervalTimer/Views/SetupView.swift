import SwiftUI
import WatchKit
import IntervalTimerCore

struct SetupView: View {
    @Environment(Runner.self) private var runner

    // 直近の設定は保存して、次に開いたときの初期値にする。
    @AppStorage("lastMinutes") private var minutes: Int = 20
    @AppStorage("lastParts") private var parts: Int = 4

    // Digital Crown は Double でしか回らないので、整数とは別に持つ。
    @State private var crownMinutes: Double = 20
    @State private var crownParts: Double = 4

    @FocusState private var focus: Field?
    private enum Field: Hashable { case minutes, parts }

    private var config: TimerConfig { TimerConfig(minutes: minutes, parts: parts) }

    /// 上に空ける高さ。**ここにシステムの時計が出る。**
    ///
    /// 実行画面の円環は角が丸いので18ptで足りたが、この画面は右上に四角い「＋」が来るので、
    /// 時計と正面衝突する。画面の高さに比例させて、機種が変わっても当たらないようにする。
    private var clockReserve: CGFloat {
        WKInterfaceDevice.current().screenBounds.height * 0.13
    }

    /// ＋ − ボタンの幅。**数値のセルより、押しやすさを優先する。**
    /// グローブでも外さずに押せることのほうが、180という数字が大きく出ることより大事。
    private var stepWidth: CGFloat {
        let w = WKInterfaceDevice.current().screenBounds.width
        return max(40, min(58, w * 0.27))
    }

    var body: some View {
        ZStack {
            Skin.normal.background.ignoresSafeArea()

            // 安全領域に任せると高さが3分の1近く削られ、開始ボタンが画面の外へ出る。
            // 外して自分で余白を決める（実行画面と同じ考え方）。
            ScrollView {
                VStack(spacing: 4) {
                    valueRow(label: "全体", unit: String(localized: "分"), field: .minutes,
                             tint: Color(hex: PaletteHex.totalInk),
                             value: $minutes, crown: $crownMinutes,
                             range: TimerConfig.minuteRange)

                    valueRow(label: "分割", unit: String(localized: "回"), field: .parts,
                             tint: Color(hex: PaletteHex.splitsInk),
                             value: $parts, crown: $crownParts,
                             range: TimerConfig.partsRange)

                    preview

                    Button {
                        runner.start(config: config)
                    } label: {
                        Text("開始")
                            .font(.system(size: 17, weight: .bold))
                            // 塗りが橙なので、文字は白ではなくほぼ黒。こちらのほうが読める
                            .foregroundStyle(Color(hex: PaletteHex.warnInk))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(hex: PaletteHex.startFill))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("start")

                    if let note = runner.backgroundNote {
                        Text(note)
                            .font(.system(size: 11))
                            .foregroundStyle(Skin.normal.inkDim)
                            .multilineTextAlignment(.center)
                            .padding(.top, 6)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
            .padding(.top, clockReserve)
        }
        .ignoresSafeArea()
        .onAppear {
            // 保存してある値をつまみ側にも入れておく。ここは素の代入で済ませる。
            crownMinutes = Double(minutes)
            crownParts = Double(parts)
        }
    }

    // MARK: - 数値の行

    /// `unit` は**訳し終えた文字**で受ける。英語では単位が要らないので空文字になり、
    /// そのときは何も描かない。空の `Text` を置くと、豆腐（□）が出る。
    private func valueRow(label: LocalizedStringKey, unit: String, field: Field,
                          tint: Color,
                          value: Binding<Int>, crown: Binding<Double>,
                          range: ClosedRange<Int>) -> some View {
        HStack(spacing: 4) {
            StepButton(systemName: "minus", tint: tint, width: stepWidth) {
                set(value, crown, to: value.wrappedValue - 1, in: range)
            }
            .accessibilityIdentifier("\(field)-minus")

            VStack(spacing: -1) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(tint)
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(value.wrappedValue)")
                        .font(.system(size: 27, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        // **数字は白のまま。** 色にすると、いちばん読みたいものが弱くなる。
                        // 色は見出し・単位・地・ボタンで足りる
                        .foregroundStyle(Skin.normal.ink)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 11))
                            .foregroundStyle(tint.opacity(0.7))
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(focus == field ? 0.34 : 0.20))
            )
            .accessibilityIdentifier("\(field)-value")
            .contentShape(Rectangle())
            .focusable()
            .focused($focus, equals: field)
            .digitalCrownRotation(
                crown,
                from: Double(range.lowerBound), through: Double(range.upperBound),
                by: 1, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true
            )
            .onTapGesture { focus = field }
            .onChange(of: crown.wrappedValue) { _, new in
                let rounded = Int(new.rounded()).clamped(to: range)
                if value.wrappedValue != rounded { value.wrappedValue = rounded }
            }

            StepButton(systemName: "plus", tint: tint, width: stepWidth) {
                set(value, crown, to: value.wrappedValue + 1, in: range)
            }
            .accessibilityIdentifier("\(field)-plus")
        }
    }

    private func set(_ value: Binding<Int>, _ crown: Binding<Double>, to new: Int, in range: ClosedRange<Int>) {
        let v = new.clamped(to: range)
        guard v != value.wrappedValue else { return }
        value.wrappedValue = v
        crown.wrappedValue = Double(v)
        // 触覚は ``StepButton`` が鳴らす。長押しの連続では間引くため、ここでは鳴らさない
    }

    // MARK: - プレビュー

    /// 1区切りの長さと、いま始めたら終わる時刻。
    ///
    /// 「1区切り 5分00秒」は長い。**`/5分` で意味は通る。**
    /// 空いた横幅に「終わり 22:55」を出す。練習の予定と突き合わせるとき、
    /// 20分という長さより「何時に終わるか」のほうが役に立つ。
    private var preview: some View {
        // 現在時刻から出すので、1分ごとに引き直す。秒までは要らない。
        TimelineView(.everyMinute) { timeline in
            HStack(spacing: 10) {
                Text("/\(TimeText.brief(config.splitSeconds))")
                    .fontWeight(.semibold)
                    .foregroundStyle(Skin.normal.accent)

                HStack(spacing: 3) {
                    Text("終わり")
                        .foregroundStyle(Skin.normal.inkDim)
                    Text(endTime(startingAt: timeline.date))
                        .fontWeight(.semibold)
                        .foregroundStyle(Skin.normal.ink)
                }
            }
            .font(.system(size: 14))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(minHeight: 20)
        }
    }

    /// いま始めたら終わる時刻。`22:55` のように分まで。
    /// 24時間表記かどうかは端末の設定に従わせる。
    private func endTime(startingAt now: Date) -> String {
        now.addingTimeInterval(config.totalSeconds)
            .formatted(date: .omitted, time: .shortened)
    }
}
