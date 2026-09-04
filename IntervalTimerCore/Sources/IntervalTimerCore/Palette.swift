import Foundation

/// 画面の色。ここには数値だけ置き、SwiftUI の `Color` への変換はアプリ側でやる。
///
/// **屋外・直射日光下で使う。** 通常／警告／終了の3状態は、色相ではなく
/// **明るさ**で見分けられるようにしてある。まぶしい場所でも、色が分かりにくい人にも、
/// 「画面が明るくなった＝区切りが近い」で伝わる。
/// 実際のコントラスト比は ``Contrast`` で測っていて、テストで固定している。
public enum PaletteHex {
    /// 通常。暗い青緑。
    public static let background: UInt32 = 0x0F3239
    public static let ink: UInt32        = 0xF2F6F4
    public static let inkDim: UInt32     = 0x7FA5A8

    /// 残り20%。明るい琥珀。ここだけ文字が黒に反転するので、目を上げた瞬間に分かる。
    public static let warnBackground: UInt32 = 0xD96A0B
    public static let warnInk: UInt32        = 0x1A1207
    public static let warnInkDim: UInt32     = 0x2B1D0A

    /// 終了。いちばん明るい。
    public static let doneBackground: UInt32 = 0xE8E2D4
    public static let doneInk: UInt32        = 0x17282C
    public static let doneInkDim: UInt32     = 0x4A5A5D
}

/// WCAG の相対輝度とコントラスト比。目視ではなく数字で確かめるために置いている。
public enum Contrast {

    public static func luminance(_ hex: UInt32) -> Double {
        func channel(_ v: UInt32) -> Double {
            let c = Double(v) / 255.0
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let r = channel((hex >> 16) & 0xFF)
        let g = channel((hex >> 8) & 0xFF)
        let b = channel(hex & 0xFF)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /// 1.0〜21.0。WCAG AA は本文 4.5、大きな文字 3.0。
    public static func ratio(_ a: UInt32, _ b: UInt32) -> Double {
        let x = luminance(a), y = luminance(b)
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}
