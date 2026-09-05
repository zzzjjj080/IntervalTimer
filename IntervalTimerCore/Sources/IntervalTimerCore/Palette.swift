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

    /// 設定画面で「1区切り◯分」の数字に使う暖色。地の色の上で 7:1 出る。
    public static let accent: UInt32 = 0xE8C04A

    /// 設定画面の行ごとの色。円環の色（冷たい側）から取っている。
    /// **行ごとに色を変えると、どちらをいじっているのか一目で分かる。**
    public static let totalInk: UInt32  = 0xA8DCE3   // 全体
    public static let splitsInk: UInt32 = 0x4EC3AE   // 分割

    /// 「開始」ボタンの塗り。いちばん押すものなので、画面で一番目立たせる。
    /// 文字は ``warnInk``（ほぼ黒）を載せる。白より読みやすい。
    public static let startFill: UInt32 = 0xE8760F

    /// 進める操作（再開・一時停止）。緑は「動いている」の合図として通じる。
    public static let goInk: UInt32 = 0x4EC3AE

    /// やめる操作（リセット）。**「開始」より目立たせない。**
    /// 誤って押されると全部消えるので、色は付けても、押したくなる色にはしない。
    public static let stopInk: UInt32 = 0xE9A63A

    /// 区切りごとの色。**冷たい色から暖かい色へ、時計回りに進む。**
    ///
    /// 位置そのものが「どこまで来たか」を表す。数字を読まなくても、
    /// 暖色まで来ていれば終わりが近いと分かる。最後は警告と同じ琥珀にしてある。
    ///
    /// 12色あるのは、分割の最大が12だから。分割が少ないときは
    /// ``segments(parts:)`` が等間隔に選ぶので、いつでも端から端まで使う。
    public static let segmentRamp: [UInt32] = [
        0xA8DCE3, 0x7FD2D3, 0x56C7BE, 0x4EC3AE,
        0x6BC98F, 0x93CF72, 0xBBD45C, 0xE0CE52,
        0xE8C04A, 0xE9A63A, 0xE28A22, 0xD96A0B,
    ]

    /// 分割数ぶんの色を、``segmentRamp`` から等間隔に取る。
    public static func segments(parts: Int) -> [UInt32] {
        let n = max(1, parts)
        guard n > 1 else { return [segmentRamp.last!] }
        return (0..<n).map { i in
            let t = Double(i) / Double(n - 1)
            return segmentRamp[Int((t * Double(segmentRamp.count - 1)).rounded())]
        }
    }

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
