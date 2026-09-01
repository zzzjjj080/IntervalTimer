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

    /// セグメントバーの「まだ来ていない」ぶん。
    var faint: Color { inkDim.opacity(0.28) }
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
