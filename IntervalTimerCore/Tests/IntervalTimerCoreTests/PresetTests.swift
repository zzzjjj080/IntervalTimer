import Foundation
import Testing
@testable import IntervalTimerCore

struct PresetTests {

    @Test func 三枠まで() {
        var book = PresetBook()
        for i in 1...5 {
            book.add(Preset(name: "\(i)", config: TimerConfig(minutes: i, parts: 2)))
        }
        #expect(book.presets.count == 3)
        #expect(book.presets.map(\.name) == ["1", "2", "3"])   // 古いものを黙って消さない
        #expect(book.isFull)
    }

    @Test func 削除も改名もIDで指す() {
        let a = Preset(name: "同じ名前", config: TimerConfig(minutes: 10, parts: 2))
        let b = Preset(name: "同じ名前", config: TimerConfig(minutes: 20, parts: 4))
        var book = PresetBook(presets: [a, b])

        book.rename(id: b.id, to: "打撃")
        #expect(book.preset(id: a.id)?.name == "同じ名前")
        #expect(book.preset(id: b.id)?.name == "打撃")

        book.remove(id: a.id)
        #expect(book.presets.map(\.id) == [b.id])
    }

    @Test func 無いIDへの操作は落ちずに無視される() {
        var book = PresetBook(presets: [Preset(name: "守備", config: TimerConfig(minutes: 15, parts: 3))])
        book.remove(id: UUID())
        book.rename(id: UUID(), to: "x")
        #expect(book.presets.count == 1)
        #expect(book.presets[0].name == "守備")
    }

    @Test func 保存して読み直せる() {
        let book = PresetBook(presets: [
            Preset(name: "打撃", config: TimerConfig(minutes: 20, parts: 4)),
            Preset(name: "走塁", config: TimerConfig(minutes: 7, parts: 3)),
        ])
        let restored = PresetBook.decode(json: book.encodedJSON())
        #expect(restored == book)
    }

    @Test func 項目が足りない古いJSONでも読める() {
        // presets キーごと無い版（初期の保存形式）
        #expect(PresetBook.decode(json: "{}").presets.isEmpty)
        // 壊れた文字列でも落ちない
        #expect(PresetBook.decode(json: "これはJSONではない").presets.isEmpty)
        #expect(PresetBook.decode(json: "").presets.isEmpty)
    }

    @Test func 範囲外の値が保存されていても読み込みで丸まる() {
        let json = #"{"presets":[{"id":"\#(UUID().uuidString)","name":"壊れ","config":{"minutes":9999,"parts":99}}]}"#
        let book = PresetBook.decode(json: json)
        #expect(book.presets.first?.config == TimerConfig(minutes: 180, parts: 12))
    }

    @Test func 名前が空なら数字で見せる() {
        let p = Preset(name: "   ", config: TimerConfig(minutes: 20, parts: 4))
        #expect(p.displayName == "20分 / 4")
    }
}
