import Foundation
import Testing
@testable import IntervalTimerCore

struct TimeTextTests {

    @Test func 切り上げで出す() {
        #expect(TimeText.clock(300) == "5:00")
        #expect(TimeText.clock(299.99) == "5:00")   // まだ5分と言ってよい
        #expect(TimeText.clock(299.0) == "4:59")
        #expect(TimeText.clock(0.01) == "0:01")   // 0.01秒でも「残っている」ので0にしない
    }

    @Test func 端の値() {
        #expect(TimeText.clock(0) == "0:00")
        #expect(TimeText.clock(-5) == "0:00")
        #expect(TimeText.clock(0.4) == "0:01")     // 残っている間は0にしない
        #expect(TimeText.clock(59) == "0:59")
        #expect(TimeText.clock(60) == "1:00")
    }

    @Test func 一時間を超えたら時も出す() {
        #expect(TimeText.clock(3600) == "1:00:00")
        #expect(TimeText.clock(10800) == "3:00:00")   // 180分
        #expect(TimeText.clock(3599) == "59:59")
    }

    @Test func 浮動小数の誤差で一秒多く出さない() {
        #expect(TimeText.clock(300.0000000001) == "5:00")
        #expect(TimeText.clock(1200.0 - 0.0) == "20:00")
    }

    @Test func 文章に混ぜる表記はぴったりなら秒を出さない() {
        #expect(TimeText.brief(60) == "1分")
        #expect(TimeText.brief(300) == "5分")
        #expect(TimeText.brief(45) == "45秒")
        #expect(TimeText.brief(90) == "1分30秒")
        #expect(TimeText.brief(0) == "0秒")
    }

    @Test func プレビューの日本語表記() {
        #expect(TimeText.japanese(300) == "5分00秒")
        #expect(TimeText.japanese(140) == "2分20秒")
        #expect(TimeText.japanese(5) == "5秒")
        #expect(TimeText.japanese(60) == "1分00秒")
        #expect(TimeText.japanese(TimerConfig(minutes: 7, parts: 3).splitSeconds) == "2分20秒")
    }
}
