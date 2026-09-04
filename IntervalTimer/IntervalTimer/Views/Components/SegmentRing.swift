import SwiftUI

/// 区切りぶんに分かれた円環。時計の文字盤のように、12時から時計回りに進む。
///
/// 1本の弧が1区切り。**消化済みは塗り、進行中は途中まで塗る。**
/// 「いま何区切り目か」と「その中でどこまで来たか」を、数字を読まずに掴めるようにする。
///
/// **大きさは呼び出し側が決めて `diameter` で渡す。**
/// `GeometryReader` に測らせると、内側に置いた数字と取り合って
/// 思ったより小さく描かれることがあった。円環は画面の骨格なので、寸法を握っておく。
struct SegmentRing: View {
    let parts: Int
    /// 進行中の区切り（0始まり）。
    let index: Int
    /// 進行中の区切りをどこまで塗るか。0...1。
    let progressInSplit: Double
    let skin: Skin
    let diameter: CGFloat
    var lineWidth: CGFloat = 9
    /// 終了後は全部を塗る。
    var allDone: Bool = false

    var body: some View {
        ZStack {
            ForEach(0..<max(1, parts), id: \.self) { i in
                // 下敷き。まだ来ていない区切りも、ここで形が見える
                ArcShape(startDegrees: start(i), spanDegrees: span, lineWidth: lineWidth)
                    .stroke(skin.faint, style: stroke)

                let filled = amount(for: i)
                if filled > 0 {
                    ArcShape(startDegrees: start(i), spanDegrees: span * filled, lineWidth: lineWidth)
                        .stroke(skin.ink, style: stroke)
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .animation(.easeOut(duration: 0.25), value: index)
    }

    // MARK: - 角度

    private var radius: CGFloat { (diameter - lineWidth) / 2 }
    private var step: Double { 360.0 / Double(max(1, parts)) }

    /// 丸い端（`.round`）は弧の両端から線幅の半分だけ外へ張り出す。
    /// そのぶんを足しておかないと隙間が埋まって、ただの輪に見える（アイコンで踏んだ）。
    private var gap: Double {
        let visible = parts <= 6 ? 6.0 : 4.0   // 区切りが多いときは詰める。点線に見えてしまうため
        let cap = Double(lineWidth / 2) / Double(max(1, radius)) * 180 / .pi
        return visible + cap * 2
    }

    private var span: Double { max(step * 0.2, step - gap) }

    /// 12時を起点に、時計回り。
    /// SwiftUI は下向きがy軸の正なので、角度が増える向きが画面上の時計回りになる。
    private func start(_ i: Int) -> Double {
        -90.0 + Double(i) * step + (step - span) / 2
    }

    private var stroke: StrokeStyle {
        StrokeStyle(lineWidth: lineWidth, lineCap: .round)
    }

    private func amount(for i: Int) -> Double {
        if allDone || i < index { return 1 }
        if i == index { return min(max(progressInSplit, 0), 1) }
        return 0
    }
}

/// 弧1本。`Shape` にしておくと、与えられた枠にそのまま収まる。
private struct ArcShape: Shape {
    let startDegrees: Double
    let spanDegrees: Double
    let lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = (min(rect.width, rect.height) - lineWidth) / 2
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: max(0, r),
                 startAngle: .degrees(startDegrees),
                 endAngle: .degrees(startDegrees + spanDegrees),
                 clockwise: false)
        return p
    }
}
