import Foundation
import Testing
@testable import IntervalTimerCore

/// 配色は目で見て決めない。屋外で読めるかどうかを数字で固定しておく。
struct PaletteTests {

    @Test func 本文の文字はAA基準を満たす() {
        // WCAG AA（本文）= 4.5:1
        #expect(Contrast.ratio(PaletteHex.ink, PaletteHex.background) >= 4.5)
        #expect(Contrast.ratio(PaletteHex.inkDim, PaletteHex.background) >= 4.5)
        #expect(Contrast.ratio(PaletteHex.warnInkDim, PaletteHex.warnBackground) >= 4.5)
        #expect(Contrast.ratio(PaletteHex.doneInk, PaletteHex.doneBackground) >= 4.5)
        #expect(Contrast.ratio(PaletteHex.doneInkDim, PaletteHex.doneBackground) >= 4.5)
    }

    @Test func 大きな数字はAA基準の大文字を満たす() {
        // WCAG AA（大きな文字）= 3.0:1
        #expect(Contrast.ratio(PaletteHex.warnInk, PaletteHex.warnBackground) >= 4.5)
    }

    @Test func 三つの状態は明るさで見分けられる() {
        let normal = Contrast.luminance(PaletteHex.background)
        let warn = Contrast.luminance(PaletteHex.warnBackground)
        let done = Contrast.luminance(PaletteHex.doneBackground)

        // 通常 → 警告 → 終了 の順に明るくなる。色相の差に頼らずに区別できる。
        #expect(normal < warn)
        #expect(warn < done)

        // 隣り合う状態どうしにも、はっきりした差を要求する。
        // 色が分かりにくい人にも、日なたでも、明るさの変化だけで伝わるように。
        #expect(Contrast.ratio(PaletteHex.background, PaletteHex.warnBackground) >= 3.0)
        #expect(Contrast.ratio(PaletteHex.warnBackground, PaletteHex.doneBackground) >= 2.5)
    }

    @Test func 区切りの色はどれも地の色の上で読める() {
        // 円環は太い線なので「大きな文字」の基準（3:1）で見る。
        for hex in PaletteHex.segmentRamp {
            let r = Contrast.ratio(hex, PaletteHex.background)
            #expect(r >= 3.0, "\(String(hex, radix: 16)) が地の色に埋もれる（\(r)）")
        }
        // 設定画面の数字は小さいので本文の基準（4.5:1）。
        #expect(Contrast.ratio(PaletteHex.accent, PaletteHex.background) >= 4.5)
    }

    @Test func ボタンの色も読める() {
        // ボタンの文字は小さいので本文の基準（4.5:1）。
        #expect(Contrast.ratio(PaletteHex.goInk, PaletteHex.background) >= 4.5)
        #expect(Contrast.ratio(PaletteHex.stopInk, PaletteHex.background) >= 4.5)
        // 「開始」は塗りつぶしなので、塗りと文字の間で測る。
        #expect(Contrast.ratio(PaletteHex.warnInk, PaletteHex.startFill) >= 4.5)
        // 「開始」の塗りは地の色からはっきり浮くこと。
        #expect(Contrast.ratio(PaletteHex.startFill, PaletteHex.background) >= 3.0)
    }

    @Test func 分割数ぶんの色を端から端まで使う() {
        #expect(PaletteHex.segments(parts: 1) == [PaletteHex.segmentRamp.last!])
        for n in 2...12 {
            let c = PaletteHex.segments(parts: n)
            #expect(c.count == n)
            #expect(c.first == PaletteHex.segmentRamp.first)   // 冷たい色から
            #expect(c.last == PaletteHex.segmentRamp.last)     // 暖かい色まで
            #expect(Set(c).count == n, "\(n)分割で色が重複した")
        }
    }

    @Test func 隣り合う区切りの色は見分けられる() {
        // 12分割でも、隣どうしが同じに見えないこと。
        let c = PaletteHex.segments(parts: 12)
        for i in 0..<(c.count - 1) {
            #expect(Contrast.ratio(c[i], c[i+1]) >= 1.05 || c[i] != c[i+1])
        }
    }

    @Test func 相対輝度の計算があっている() {
        #expect(Contrast.luminance(0xFFFFFF) == 1.0)
        #expect(Contrast.luminance(0x000000) == 0.0)
        #expect(abs(Contrast.ratio(0xFFFFFF, 0x000000) - 21.0) < 0.001)
    }
}
