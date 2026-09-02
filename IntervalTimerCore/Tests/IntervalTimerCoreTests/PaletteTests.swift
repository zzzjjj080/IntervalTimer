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
        #expect(Contrast.ratio(PaletteHex.tipInk, PaletteHex.background) >= 4.5)
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

    @Test func 相対輝度の計算があっている() {
        #expect(Contrast.luminance(0xFFFFFF) == 1.0)
        #expect(Contrast.luminance(0x000000) == 0.0)
        #expect(abs(Contrast.ratio(0xFFFFFF, 0x000000) - 21.0) < 0.001)
    }
}
