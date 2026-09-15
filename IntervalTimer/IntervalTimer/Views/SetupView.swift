import SwiftUI
import WatchKit
import IntervalTimerCore
import IntervalTimerUI

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

    /// いちばん下の ⚠︎ を押したときの説明を出しているか。
    @State private var showsNote = false

    private var config: TimerConfig { TimerConfig(minutes: minutes, parts: parts) }

    // MARK: - 寸法

    /// **スクロールさせない。** 数ポイントだけ動くのが気持ち悪いと言われた（2026-09-15）。
    /// 高さを画面の実寸から割り振るので、40mm から 49mm まで同じ並びで収まる。
    /// レイアウトに測らせない理由は実行画面と同じ（安全領域の扱いで高さが変わる）。
    private var screen: CGSize { WKInterfaceDevice.current().screenBounds.size }

    /// 上に空ける高さ。**ここにシステムの時計が出る。**
    ///
    /// 実行画面の円環は角が丸いので18ptで足りたが、この画面は右上に四角い「＋」が来るので、
    /// 時計と正面衝突する。画面の高さに比例させて、機種が変わっても当たらないようにする。
    private var clockReserve: CGFloat { screen.height * 0.13 }

    /// 下に空ける高さ。画面の角が丸いので、いちばん下の文字が欠けないように。
    private var bottomReserve: CGFloat { screen.height * 0.04 }

    /// 並べてよい高さ。ここに全部が収まるように割り振る。
    private var usable: CGFloat { screen.height - clockReserve - bottomReserve }

    // 割り振り。**合計が1を超えないこと**（行2つ＋1回の長さ＋開始＋いちばん下＋すき間4つ = 0.98）。
    // 46mm で行 51pt・開始 47pt、40mm で行 41pt・開始 38pt になる。
    private var rowHeight: CGFloat { usable * 0.25 }
    private var previewHeight: CGFloat { usable * 0.09 }
    private var startHeight: CGFloat { usable * 0.23 }
    private var footerHeight: CGFloat { usable * 0.08 }
    private var gap: CGFloat { usable * 0.02 }

    /// ＋ − ボタンの幅。**数値のセルより、押しやすさを優先する。**
    /// グローブでも外さずに押せることのほうが、180という数字が大きく出ることより大事。
    private var stepWidth: CGFloat {
        max(40, min(58, screen.width * 0.27))
    }

    var body: some View {
        ZStack {
            Skin.normal.background.ignoresSafeArea()

            // 安全領域に任せると高さが3分の1近く削られ、開始ボタンが画面の外へ出る。
            // 外して自分で余白を決める（実行画面と同じ考え方）。
            VStack(spacing: gap) {
                valueRow(label: "全体", unit: String(localized: "分"), field: .minutes,
                         tint: Color(hex: PaletteHex.totalInk),
                         value: $minutes, crown: $crownMinutes,
                         range: TimerConfig.minuteRange)
                    .frame(height: rowHeight)

                valueRow(label: "分割", unit: String(localized: "回"), field: .parts,
                         tint: Color(hex: PaletteHex.splitsInk),
                         value: $parts, crown: $crownParts,
                         range: TimerConfig.partsRange)
                    .frame(height: rowHeight)

                preview
                    .frame(height: previewHeight)

                startButton
                    .frame(height: startHeight)

                footer
                    .frame(height: footerHeight)
            }
            .padding(.horizontal, 6)
            .padding(.top, clockReserve)
            .padding(.bottom, bottomReserve)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showsNote) { noteSheet }
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
            StepButton(systemName: "minus", isUp: false, tint: tint, width: stepWidth, height: rowHeight) {
                set(value, crown, to: value.wrappedValue - 1, in: range)
            }
            .accessibilityIdentifier("\(field)-minus")

            VStack(spacing: -1) {
                Text(label)
                    .font(.system(size: rowHeight * 0.23, weight: .medium))
                    .foregroundStyle(tint)
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(value.wrappedValue)")
                        .font(.system(size: rowHeight * 0.56, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        // **数字は白のまま。** 色にすると、いちばん読みたいものが弱くなる。
                        // 色は見出し・単位・地・ボタンで足りる
                        .foregroundStyle(Skin.normal.ink)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: rowHeight * 0.23))
                            .foregroundStyle(tint.opacity(0.7))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

            StepButton(systemName: "plus", isUp: true, tint: tint, width: stepWidth, height: rowHeight) {
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

    // MARK: - 1回の長さ

    /// 1回（1区切り）の長さと、いま始めたら終わる時刻。
    ///
    /// **「/30秒」は記号に頼っていて分かりにくかった**（2026-09-15）。すぐ上の「分割 4回」と同じ「回」で
    /// 「1回 30秒」と言葉で書く。割り切れないときは「1回 約9秒」（``TimeText/perSplit(_:locale:)``）。
    /// 空いた横幅に「終わり 22:55」を出す。練習の予定と突き合わせるとき、長さより「何時に終わるか」が役に立つ。
    private var preview: some View {
        // 現在時刻から出すので、1分ごとに引き直す。秒までは要らない。
        TimelineView(.everyMinute) { timeline in
            HStack(spacing: 10) {
                Text("1回 \(TimeText.perSplit(config.splitSeconds))")
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
            .font(.system(size: previewHeight * 0.8))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxHeight: .infinity)
        }
    }

    /// いま始めたら終わる時刻。`22:55` のように分まで。
    /// 24時間表記かどうかは端末の設定に従わせる。
    private func endTime(startingAt now: Date) -> String {
        now.addingTimeInterval(config.totalSeconds)
            .formatted(date: .omitted, time: .shortened)
    }

    // MARK: - 開始

    private var startButton: some View {
        Button {
            runner.start(config: config)
        } label: {
            Text("開始")
                .font(.system(size: min(17, startHeight * 0.38), weight: .bold))
                // 塗りが橙なので、文字は白ではなくほぼ黒。こちらのほうが読める
                .foregroundStyle(Color(hex: PaletteHex.warnInk))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: PaletteHex.startFill))
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("start")
    }

    // MARK: - いちばん下

    /// いちばん下の1行。**高さは変えない**（変えるとスクロールが戻ってくる）。
    ///
    /// ふだんは**実機にどのビルドが入っているか**（BuildInfo）。
    /// 背面で動かせない事情があるときだけ、⚠︎ と短い一言に変わり、押すと理由と許可の変え方を出す。
    /// 長い案内は1行に入らないので、押した先で読ませる。
    @ViewBuilder
    private var footer: some View {
        if let note = runner.backgroundNote {
            Button {
                showsNote = true
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(note)
                        .lineLimit(1)
                }
                .font(.system(size: footerHeight * 0.66, weight: .semibold))
                .foregroundStyle(Color(hex: PaletteHex.stopInk))
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("backgroundNote")
        } else {
            Text(BuildInfo.text)
                .font(.system(size: footerHeight * 0.62, design: .monospaced))
                .foregroundStyle(Skin.normal.inkDim)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("buildInfo")
        }
    }

    /// ⚠︎ を押したときの説明。長い案内はここで読む（こちらはスクロールしてよい）。
    /// 版の表示もここに添える。⚠︎ が出ている間は、いちばん下に版が出ないため。
    private var noteSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(runner.backgroundHelp ?? runner.backgroundNote ?? "")
                    .font(.system(size: 14))
                    .foregroundStyle(Skin.normal.ink)
                Text(BuildInfo.text)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Skin.normal.inkDim)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
    }
}
