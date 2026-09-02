import AppKit
import CoreGraphics
import Foundation

// インターバルのアプリアイコン。
//
// 「全体を区切って、いま1つ目を走っている」を1024pxで描く。
// watchOS のアイコンは**円に切り抜かれ**、ホーム画面では40px程度まで縮む。
// 細い線も文字も残らないので、太い弧と色の差だけで作る。
// 円で切られる前提なので、絵は中央に寄せて外周に余白を残す。

let S: CGFloat = 1024

func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF)/255, green: CGFloat((hex >> 8) & 0xFF)/255,
            blue: CGFloat(hex & 0xFF)/255, alpha: a)
}
func newContext(_ w: Int, _ h: Int) -> CGContext {
    guard let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { fatalError("context") }
    return c
}
func savePNG(_ image: CGImage, _ path: String) {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
    try! data.write(to: URL(fileURLWithPath: path))
}

// アプリの配色をそのまま使う（IntervalTimerCore の PaletteHex と同じ値）
let BG_DARK: UInt32   = 0x0F3239
let BG_LIGHT: UInt32  = 0x17454E
let INK: UInt32       = 0xF2F6F4
let AMBER: UInt32     = 0xD96A0B

func fillBackground(_ ctx: CGContext, size: CGFloat) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let g = CGGradient(colorsSpace: space, colors: [color(BG_LIGHT), color(BG_DARK)] as CFArray,
                       locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
}

/// 分割されたリング。`parts` 等分し、`hot` 番目（0始まり）だけ琥珀にする。
/// 12時から時計回りに進む。タイマーの向きと同じにしておく。
///
/// `visibleGapDegrees` は**目で見える隙間**。丸い端（`.round`）は弧の両端から
/// 線幅の半分だけ外へ張り出すので、そのぶんを差し引かないと隙間が埋まって
/// ただの輪に見える。40pxまで縮むアイコンでは、これが致命的になる。
func drawRing(_ ctx: CGContext, size: CGFloat, radius: CGFloat, width: CGFloat,
              parts: Int, hot: Int, visibleGapDegrees: CGFloat) {
    let c = CGPoint(x: size/2, y: size/2)
    let step = 360.0 / CGFloat(parts)
    // 丸い端が片側に張り出す角度
    let capDegrees = (width / 2) / radius * 180 / .pi
    let gapDegrees = visibleGapDegrees + capDegrees * 2
    let arc = max(step * 0.25, step - gapDegrees)

    ctx.setLineWidth(width)
    ctx.setLineCap(.round)

    for i in 0..<parts {
        // CoreGraphics の角度は3時方向が0で反時計回り。12時から時計回りにしたいので変換する。
        let startDeg = 90 - (CGFloat(i) * step) - gapDegrees/2
        let endDeg = startDeg - arc
        ctx.setStrokeColor(color(i == hot ? AMBER : INK))
        ctx.beginPath()
        ctx.addArc(center: c, radius: radius,
                   startAngle: startDeg * .pi/180, endAngle: endDeg * .pi/180,
                   clockwise: true)
        ctx.strokePath()
    }
}

func drawIcon(_ ctx: CGContext, _ variant: Int, _ size: CGFloat) {
    fillBackground(ctx, size: size)
    let k = size / S    // 1024基準で書いて縮尺だけ変える
    switch variant {
    case 1:  // 4分割・標準の太さ
        drawRing(ctx, size: size, radius: 320*k, width: 96*k, parts: 4, hot: 0, visibleGapDegrees: 15)
    case 2:  // 4分割・太め。いちばん小さくしても形が残る
        drawRing(ctx, size: size, radius: 305*k, width: 130*k, parts: 4, hot: 0, visibleGapDegrees: 16)
    default: // 6分割・細め。区切りが多い設定を思わせる
        drawRing(ctx, size: size, radius: 322*k, width: 84*k, parts: 6, hot: 0, visibleGapDegrees: 11)
    }
}

func iconImage(_ variant: Int, _ size: CGFloat) -> CGImage {
    let ctx = newContext(Int(size), Int(size))
    drawIcon(ctx, variant, size)
    return ctx.makeImage()!
}

// ---- 1024pxを3案ぶん書き出す ----
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
for v in 1...3 { savePNG(iconImage(v, S), "\(out)/icon-\(v).png") }

// ---- 見比べ用のシート。円に切り抜いた姿と、ホーム画面の実寸(40px)も並べる ----
let cell: CGFloat = 300, small: CGFloat = 40
let sheet = newContext(Int(cell*3 + 80), Int(cell + 140))
sheet.setFillColor(color(0x1C1C1E)); sheet.fill(CGRect(x: 0, y: 0, width: cell*3+80, height: cell+140))
for v in 1...3 {
    let x = 20 + CGFloat(v-1) * (cell + 20)
    // 円に切り抜いた姿（watchOSでの実際の見え方）
    sheet.saveGState()
    sheet.addEllipse(in: CGRect(x: x, y: 110, width: cell, height: cell))
    sheet.clip()
    sheet.draw(iconImage(v, cell), in: CGRect(x: x, y: 110, width: cell, height: cell))
    sheet.restoreGState()
    // ホーム画面の実寸
    sheet.saveGState()
    sheet.addEllipse(in: CGRect(x: x + cell/2 - small/2, y: 40, width: small, height: small))
    sheet.clip()
    sheet.draw(iconImage(v, small), in: CGRect(x: x + cell/2 - small/2, y: 40, width: small, height: small))
    sheet.restoreGState()
}
savePNG(sheet.makeImage()!, "\(out)/icon-sheet.png")
print("書き出しました: \(out)")
