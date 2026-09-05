import SwiftUI
import WidgetKit

/// 文字盤に置いて、一発でアプリを開くためのコンプリケーション。
///
/// 絵はアプリのアイコンと同じ「4分割された円環」。
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
                // **watchOS 10 以降はこれが必須。**
                // 付けないとコンプリケーションが描画されず、丸にビックリマークになる。
                .containerBackground(for: .widget) { AccessoryWidgetBackground() }
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
            SplitRing(lineWidth: 5)
                .widgetLabel("インターバル")
        default:
            SplitRing(lineWidth: 5).padding(2)
        }
    }
}

/// 4分割された円環。アイコンと同じ絵。
///
/// **`GeometryReader` を使わない。** コンプリケーションの枠は極端に小さく、
/// 測らせると 0 や NaN が返ってきて描画ごと落ちることがある。
/// `Shape` は与えられた矩形をそのまま受け取るので、測る必要がない。
///
/// 文字盤では単色に着色されるので、色相では区別できない。
/// 1本だけ濃く、残りを薄くして、**濃さ**で「いま1つ目」を表す。
struct SplitRing: View {
    var lineWidth: CGFloat = 5

    var body: some View {
        ZStack {
            SplitArcs(accent: false, lineWidth: lineWidth)
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .opacity(0.3)
            SplitArcs(accent: true, lineWidth: lineWidth)
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
        .widgetAccentable()
    }
}

/// 4分割の弧。`accent` が true なら1本目だけ、false なら残り3本を描く。
private struct SplitArcs: Shape {
    let accent: Bool
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
        for i in 0..<parts where (i == 0) == accent {
            let start = -90.0 + Double(i) * step + (step - span) / 2
            p.addArc(center: center, radius: radius,
                     startAngle: .degrees(start),
                     endAngle: .degrees(start + span),
                     clockwise: false)
        }
        return p
    }
}
