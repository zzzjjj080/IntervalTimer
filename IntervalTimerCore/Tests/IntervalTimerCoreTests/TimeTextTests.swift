import Foundation
import Testing
@testable import IntervalTimerCore

struct TimeTextTests {

    private let ja = Locale(identifier: "ja_JP")


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

    @Test func 既定はText_timerInterval_showsHours_trueと同じ判断になる() {
        // 実機で確認した挙動：showsHours: true でも、1時間未満なら時を出さない。
        // 動いている間（システムが描く）と止まっている間（こちらが描く）でずれないこと。
        #expect(TimeText.clock(2697) == "44:57")     // 実機のスクリーンショットと同じ
        #expect(TimeText.clock(3600) == "1:00:00")
        #expect(TimeText.clock(3599) == "59:59")
        #expect(TimeText.clock(10800) == "3:00:00")  // 全体180分
    }

    @Test func 時を出すかどうかは明示して上書きできる() {
        #expect(TimeText.clock(2700, showsHours: true) == "0:45:00")
        #expect(TimeText.clock(2700, showsHours: false) == "45:00")
        #expect(TimeText.clock(59, showsHours: true) == "0:00:59")
        // 時を出さないと決めたら、60分を超えても分に足し込む
        #expect(TimeText.clock(3660, showsHours: false) == "61:00")
        #expect(TimeText.clock(10800, showsHours: false) == "180:00")
    }

    @Test func 浮動小数の誤差で一秒多く出さない() {
        #expect(TimeText.clock(300.0000000001) == "5:00")
        #expect(TimeText.clock(1200.0 - 0.0) == "20:00")
    }

    @Test func 英語では単位が英語になる() {
        let en = Locale(identifier: "en_US")
        #expect(TimeText.brief(47, locale: en) == "47s")
        #expect(TimeText.brief(300, locale: en) == "5m")
        #expect(TimeText.brief(140, locale: en) == "2m20s")
        #expect(TimeText.japanese(300, locale: en) == "5m00s")
        // 時計の表記は言語に依らない
        #expect(TimeText.clock(300) == "5:00")
    }

    @Test func 短い表記はぴったりなら秒を出さない() {
        #expect(TimeText.brief(60, locale: ja) == "1分")
        #expect(TimeText.brief(300, locale: ja) == "5分")
        #expect(TimeText.brief(47, locale: ja) == "47秒")
        #expect(TimeText.brief(140, locale: ja) == "2分20秒")
        #expect(TimeText.brief(0, locale: ja) == "0秒")
        // 20分を12分割すると100秒。1分40秒
        #expect(TimeText.brief(100, locale: ja) == "1分40秒")
    }

    @Test func プレビューの日本語表記() {
        #expect(TimeText.japanese(300, locale: ja) == "5分00秒")
        #expect(TimeText.japanese(140, locale: ja) == "2分20秒")
        #expect(TimeText.japanese(5, locale: ja) == "5秒")
        #expect(TimeText.japanese(60, locale: ja) == "1分00秒")
        #expect(TimeText.japanese(TimerConfig(minutes: 7, parts: 3).splitSeconds, locale: ja) == "2分20秒")
    }
}
