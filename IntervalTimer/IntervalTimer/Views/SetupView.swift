import SwiftUI
import WatchKit
import IntervalTimerCore

struct SetupView: View {
    @Environment(Runner.self) private var runner

    // 直近の設定は保存して、次に開いたときの初期値にする。
    @AppStorage("lastMinutes") private var minutes: Int = 20
    @AppStorage("lastParts") private var parts: Int = 4
    @AppStorage("presets") private var presetsJSON: String = "{}"

    // Digital Crown は Double でしか回らないので、整数とは別に持つ。
    @State private var crownMinutes: Double = 20
    @State private var crownParts: Double = 4

    @State private var showingSave = false
    @State private var showingEdit = false

    @FocusState private var focus: Field?
    private enum Field: Hashable { case minutes, parts }

    private var config: TimerConfig { TimerConfig(minutes: minutes, parts: parts) }
    private var book: PresetBook { PresetBook.decode(json: presetsJSON) }

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
                    valueRow(label: "全体", unit: "分", field: .minutes,
                             value: $minutes, crown: $crownMinutes,
                             range: TimerConfig.minuteRange)

                    valueRow(label: "分割", unit: "回", field: .parts,
                             value: $parts, crown: $crownParts,
                             range: TimerConfig.partsRange)

                    preview

                    Button {
                        runner.start(config: config)
                    } label: {
                        Text("開始")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Skin.normal.background)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Skin.normal.ink)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("start")

                    presetSection

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
            openSheetForCheckingIfAsked()
        }
        .sheet(isPresented: $showingSave) {
            SavePresetSheet(config: config) { name in
                var b = book
                b.add(Preset(name: name, config: config))
                presetsJSON = b.encodedJSON()
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditPresetsSheet(book: book) { updated in
                presetsJSON = updated.encodedJSON()
            }
        }
    }

    /// シートを開いた状態で起動するための入口。
    ///
    /// シミュレータへの合成タップはシートに届かないので（引き継ぎ書 4-24）、
    /// ここを通さないと保存・整理の画面を一度も見られない。
    ///
    ///     SIMCTL_CHILD_IT_SHEET=save xcrun simctl launch <udid> com.zzzjjj080.IntervalTimer
    private func openSheetForCheckingIfAsked() {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["IT_SHEET"] {
        case "save": showingSave = true
        case "edit", "delete": showingEdit = true
        default: break
        }
        #endif
    }

    // MARK: - 数値の行

    private func valueRow(label: String, unit: String, field: Field,
                          value: Binding<Int>, crown: Binding<Double>,
                          range: ClosedRange<Int>) -> some View {
        HStack(spacing: 4) {
            stepButton(systemName: "minus") {
                set(value, crown, to: value.wrappedValue - 1, in: range)
            }
            .accessibilityIdentifier("\(field)-minus")

            VStack(spacing: -1) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(Skin.normal.inkDim)
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(value.wrappedValue)")
                        .font(.system(size: 27, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .foregroundStyle(Skin.normal.ink)
                    Text(unit)
                        .font(.system(size: 11))
                        .foregroundStyle(Skin.normal.inkDim)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Skin.normal.ink.opacity(focus == field ? 0.14 : 0.06))
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

            stepButton(systemName: "plus") {
                set(value, crown, to: value.wrappedValue + 1, in: range)
            }
            .accessibilityIdentifier("\(field)-plus")
        }
    }

    /// グローブでも押せるよう、高さ44pt・幅は画面の27%。`minus.circle` のような細い記号は避ける。
    private func stepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Skin.normal.ink)
                .frame(width: stepWidth, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Skin.normal.ink.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }

    private func set(_ value: Binding<Int>, _ crown: Binding<Double>, to new: Int, in range: ClosedRange<Int>) {
        let v = new.clamped(to: range)
        guard v != value.wrappedValue else { return }
        value.wrappedValue = v
        crown.wrappedValue = Double(v)
        WKInterfaceDevice.current().play(.click)
    }

    // MARK: - プレビュー

    private var preview: some View {
        HStack(spacing: 4) {
            Text("1区切り")
                .foregroundStyle(Skin.normal.inkDim)
            Text(TimeText.japanese(config.splitSeconds))
                .fontWeight(.semibold)
                .foregroundStyle(Skin.normal.ink)
        }
        .font(.system(size: 14))
        .frame(minHeight: 20)
    }

    // MARK: - プリセット

    @ViewBuilder
    private var presetSection: some View {
        let b = book
        if !b.presets.isEmpty {
            VStack(spacing: 4) {
                ForEach(b.presets) { preset in
                    Button {
                        minutes = preset.config.minutes
                        parts = preset.config.parts
                        crownMinutes = Double(preset.config.minutes)
                        crownParts = Double(preset.config.parts)
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        HStack {
                            Text(preset.displayName)
                                .font(.system(size: 14, weight: .medium))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text("\(preset.config.minutes)分/\(preset.config.parts)")
                                .font(.system(size: 12))
                                .foregroundStyle(Skin.normal.inkDim)
                        }
                        .foregroundStyle(Skin.normal.ink)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Skin.normal.ink.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("preset-\(preset.displayName)")
                }
            }
            .padding(.top, 6)
        }

        HStack(spacing: 4) {
            if !b.isFull {
                textButton("保存") { showingSave = true }
            }
            if !b.presets.isEmpty {
                // 消す操作は、読み込む行から離れた別の画面に置く。並べると必ず誤爆する。
                textButton("整理") { showingEdit = true }
            }
        }
        .padding(.top, 4)
    }

    private func textButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Skin.normal.inkDim)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
    }
}
