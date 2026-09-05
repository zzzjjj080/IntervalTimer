import SwiftUI
import IntervalTimerCore

/// 画面の3状態。色はここで一括して決める。
///
/// 状態ごとに「地の色・文字・弱い文字」を組で持たせてある。
/// 個々の場所で `if isWarning { ... }` と書き分けると必ず抜けが出る。
enum Skin {
    case normal, warning, done

    var background: Color {
        switch self {
        case .normal: Color(hex: PaletteHex.background)
        case .warning: Color(hex: PaletteHex.warnBackground)
        case .done: Color(hex: PaletteHex.doneBackground)
        }
    }

    var ink: Color {
        switch self {
        case .normal: Color(hex: PaletteHex.ink)
        case .warning: Color(hex: PaletteHex.warnInk)
        case .done: Color(hex: PaletteHex.doneInk)
        }
    }

    var inkDim: Color {
        switch self {
        case .normal: Color(hex: PaletteHex.inkDim)
        case .warning: Color(hex: PaletteHex.warnInkDim)
        case .done: Color(hex: PaletteHex.doneInkDim)
        }
    }

    /// 円環の「まだ来ていない」ぶん。
    var faint: Color { inkDim.opacity(0.28) }

    /// 区切りごとの色。冷たい色から暖かい色へ、時計回りに進む。
    ///
    /// **通常のときだけ色を使う。** 警告と終了は地の色そのものが合図なので、
    /// そこへ12色を重ねると何が起きたのか分からなくなる。単色に戻して地を主役にする。
    func segmentColors(parts: Int) -> [Color]? {
        guard self == .normal else { return nil }
        return PaletteHex.segments(parts: parts).map { Color(hex: $0) }
    }

    /// 設定画面で数字に添える暖色。
    var accent: Color { self == .normal ? Color(hex: PaletteHex.accent) : ink }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
