import SwiftUI
import WidgetKit

/// 文字盤に置いて、一発でアプリを開くためのコンプリケーション。
///
/// **残り時間は出していない。** 出すにはアプリと拡張で状態を共有する必要があり
/// （App Group）、仕掛けが増える。まずは「押すと開く」だけを確実に動かす。
@main
struct IntervalTimerWidgetBundle: WidgetBundle {
    var body: some Widget { LaunchComplication() }
}

struct LaunchComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "IntervalTimerLaunch", provider: LaunchProvider()) { _ in
            ComplicationView()
        }
        .configurationDisplayName("インターバル")
        .description("タップしてタイマーを開きます。")
        .supportedFamilies([.accessoryCircular, .accessoryCorner,
                            .accessoryInline, .accessoryRectangular])
    }
}

struct LaunchEntry: TimelineEntry { let date: Date }

struct LaunchProvider: TimelineProvider {
    func placeholder(in context: Context) -> LaunchEntry { LaunchEntry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (LaunchEntry) -> Void) {
        completion(LaunchEntry(date: .now))
    }

    /// 中身が時刻で変わらないので、作り直させない。
    /// 更新の予算を使い切ると、いざ必要になったときに動かなくなる。
    func getTimeline(in context: Context, completion: @escaping (Timeline<LaunchEntry>) -> Void) {
        completion(Timeline(entries: [LaunchEntry(date: .now)], policy: .never))
    }
}

struct ComplicationView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        content
            // **watchOS 10 以降はこれが必須。**
            // 付けないとコンプリケーションが描画されず、丸にビックリマークになる。
            .containerBackground(for: .widget) { background }
    }

    /// 地の色。
    ///
    /// 色を出せる文字盤ではアプリと同じ濃いティール。**地を置くのが肝で、**
    /// これが無いと明るい文字盤や写真の上で輪が埋もれる（地なしの案を実寸で試して確認した）。
    /// 単色に着色される文字盤では、システム標準の地に任せる。
    @ViewBuilder
    private var background: some View {
        if mode == .fullColor {
            Palette.ground
        } else {
            AccessoryWidgetBackground()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            // インラインは1行の文字だけ。図は出せない。
            Label("インターバル", systemImage: "timer")
        case .accessoryRectangular:
            HStack(spacing: 8) {
                SplitRing(lineWidth: 4).frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text("インターバル").font(.headline)
                    Text("区切りタイマー").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        case .accessoryCorner:
            SplitRing(lineWidth: 5).widgetLabel("インターバル")
        default:
            SplitRing(lineWidth: 6).padding(3)
        }
    }
}

enum Palette {
    /// アプリと同じ地の色。
    static let ground = Color(red: 0x0F/255, green: 0x32/255, blue: 0x39/255)

    /// 12時から時計回りに4本ぶん。**明るさを揃えず、はっきり変える。**
    /// 文字盤は明るいものも暗いものもあるので、どちらの上でも4本が見分けられる必要がある。
    static let arcs: [Color] = [
        Color(red: 0xD9/255, green: 0x6A/255, blue: 0x0B/255),   // 琥珀（アプリの警告色）
        Color(red: 0xE8/255, green: 0xC0/255, blue: 0x4A/255),   // 金
        Color(red: 0x4E/255, green: 0xC3/255, blue: 0xAE/255),   // 若緑
        Color(red: 0x9E/255, green: 0xD9/255, blue: 0xE0/255),   // 淡い水
    ]
}

/// 4分割された円環。
///
/// **`GeometryReader` を使わない。** コンプリケーションの枠は極端に小さく、
/// 測らせると 0 や NaN が返ってきて描画ごと落ちることがある。
/// `Shape` は与えられた矩形をそのまま受け取るので、測る必要がない。
struct SplitRing: View {
    @Environment(\.widgetRenderingMode) private var mode
    var lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            if mode == .fullColor {
                // 色を出せる文字盤では4色。押す前から「あのアプリだ」と分かる
                ForEach(0..<4, id: \.self) { i in
                    SplitArcs(only: i, lineWidth: lineWidth)
                        .stroke(Palette.arcs[i],
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                }
            } else {
                // 単色に着色される文字盤では、色相では区別できない。濃さで分ける
                SplitArcs(only: nil, lineWidth: lineWidth)
                    .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .opacity(0.3)
                SplitArcs(only: 0, lineWidth: lineWidth)
                    .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .widgetAccentable()
            }
        }
    }
}

/// 4分割の弧。`only` にその番号だけ、`nil` なら1本目以外を描く。
private struct SplitArcs: Shape {
    let only: Int?
    let lineWidth: CGFloat
    private let parts = 4

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let radius = (side - lineWidth) / 2
        guard radius > 0.5 else { return Path() }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let step = 360.0 / Double(parts)
        // 丸い端は線幅の半分だけ外へ張り出す。差し引かないと隙間が埋まって輪に見える。
        let cap = Double(lineWidth / 2) / Double(radius) * 180 / .pi
        let span = max(step * 0.2, step - (8 + cap * 2))

        var p = Path()
        for i in 0..<parts where (only == nil ? i != 0 : i == only) {
            let start = -90.0 + Double(i) * step + (step - span) / 2
            p.addArc(center: center, radius: radius,
                     startAngle: .degrees(start),
                     endAngle: .degrees(start + span),
                     clockwise: false)
        }
        return p
    }
}
