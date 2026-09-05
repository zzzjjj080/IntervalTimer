import SwiftUI
import WidgetKit

/// 文字盤に置いて、一発でアプリを開くためのコンプリケーション。
///
/// 絵はアプリのアイコンと同じ「4分割された円環」にしてある。
/// 文字盤には小さく出るので、名前ではなく形で見つけられるほうがいい。
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

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                SplitRing(lineWidth: 5).padding(3)
            }
        case .accessoryCorner:
            SplitRing(lineWidth: 5)
                .padding(2)
                .widgetLabel("インターバル")
        case .accessoryInline:
            // インラインは1行の文字だけ。図は出せない。
            Label("インターバル", systemImage: "timer")
        default:
            HStack(spacing: 8) {
                SplitRing(lineWidth: 4).frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("インターバル").font(.headline)
                    Text("区切りタイマー").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// 4分割された円環。アイコンと同じ絵。
///
/// 文字盤では単色に着色されるので、色相では区別できない。
/// 1本だけ濃く、残りを薄くして、**濃さ**で「いま1つ目」を表す。
struct SplitRing: View {
    var lineWidth: CGFloat = 5
    private let parts = 4

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let radius = max(1, (side - lineWidth) / 2)
            let step = 360.0 / Double(parts)
            // 丸い端は線幅の半分だけ外へ張り出す。差し引かないと隙間が埋まって輪に見える。
            let cap = Double(lineWidth / 2) / Double(radius) * 180 / .pi
            let span = max(step * 0.2, step - (8 + cap * 2))

            ZStack {
                ForEach(0..<parts, id: \.self) { i in
                    let start = -90.0 + Double(i) * step + (step - span) / 2
                    Arc(startDegrees: start, spanDegrees: span, lineWidth: lineWidth)
                        .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .opacity(i == 0 ? 1 : 0.3)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .widgetAccentable()
    }
}

private struct Arc: Shape {
    let startDegrees: Double
    let spanDegrees: Double
    let lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = max(0, (min(rect.width, rect.height) - lineWidth) / 2)
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: r,
                 startAngle: .degrees(startDegrees),
                 endAngle: .degrees(startDegrees + spanDegrees),
                 clockwise: false)
        return p
    }
}
