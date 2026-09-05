import Foundation
import Testing
@testable import IntervalTimerCore

/// 仕様書「5. 受け入れ基準」の11項目をそのままテストにしたもの。
/// HTMLプロトタイプで目視した挙動を、ここで固定する。
struct EngineTests {

    /// 判定ループの代わり。0.1秒ずつ時刻を進めて、起きたイベントを開始からの秒数つきで集める。
    /// 刻みを足し込むと誤差が溜まるので、必ず「開始時刻＋i×0.1」で作る。
    private func run(_ engine: inout TimerEngine, from base: Date, seconds: Double, step: Double = 0.1) -> [(at: Double, event: TimerEvent)] {
        var log: [(at: Double, event: TimerEvent)] = []
        let ticks = Int(seconds / step)
        for i in 0...ticks {
            let offset = Double(i) * step
            for e in engine.advance(to: base.addingTimeInterval(offset)) {
                log.append((at: offset, event: e))
            }
        }
        return log
    }

    private let base = Date(timeIntervalSinceReferenceDate: 0)

    // MARK: - 1・2. 開始直後と1秒後の表示

    @Test func 開始直後は全体2000と区切り500がでる() {
        let engine = TimerEngine(config: TimerConfig(minutes: 20, parts: 4), startedAt: base)
        let s = engine.snapshot(at: base)
        #expect(TimeText.clock(s.totalRemaining) == "20:00")
        #expect(TimeText.clock(s.splitRemaining) == "5:00")
        #expect(s.displayIndex == 1)
    }

    @Test func 一秒後は1959と459になる() {
        let engine = TimerEngine(config: TimerConfig(minutes: 20, parts: 4), startedAt: base)
        let s = engine.snapshot(at: base.addingTimeInterval(1))
        #expect(TimeText.clock(s.totalRemaining) == "19:59")
        #expect(TimeText.clock(s.splitRemaining) == "4:59")
    }

    // MARK: - 3・4・5. 20%通知・区切りの切れ目・終了

    @Test func 二十分四分割の通知は各区切りで一回ずつ起きる() {
        var engine = TimerEngine(config: TimerConfig(minutes: 20, parts: 4), startedAt: base)
        let log = run(&engine, from: base, seconds: 1200)

        let warnings = log.filter { $0.event == .warning }.map(\.at)
        #expect(warnings == [225, 525, 825, 1125])   // 各区切りの75%が終わったところ

        let splits = log.compactMap { entry -> Double? in
            if case .splitEnded = entry.event { return entry.at } else { return nil }
        }
        #expect(splits == [300, 600, 900])

        let finished = log.filter { $0.event == .finished }.map(\.at)
        #expect(finished == [1200])
    }

    @Test func 区切りが進むと表示が2of4_3of4_4of4になる() {
        var engine = TimerEngine(config: TimerConfig(minutes: 20, parts: 4), startedAt: base)
        for (t, expected) in [(300.0, 2), (600.0, 3), (900.0, 4)] {
            _ = engine.advance(to: base.addingTimeInterval(t))
            #expect(engine.snapshot(at: base.addingTimeInterval(t)).displayIndex == expected)
        }
    }

    @Test func 七十五パーセントの瞬間に色が変わり0で戻る() {
        let engine = TimerEngine(config: TimerConfig(minutes: 20, parts: 4), startedAt: base)
        #expect(engine.snapshot(at: base.addingTimeInterval(224.9)).isWarning == false)
        #expect(engine.snapshot(at: base.addingTimeInterval(225.0)).isWarning == true)
        #expect(engine.snapshot(at: base.addingTimeInterval(299.9)).isWarning == true)
        #expect(engine.snapshot(at: base.addingTimeInterval(300.0)).isWarning == false)   // 次の区切りへ
    }

    @Test func 終了すると走っていない状態になる() {
        var engine = TimerEngine(config: TimerConfig(minutes: 20, parts: 4), startedAt: base)
        _ = engine.advance(to: base.addingTimeInterval(1200))
        let s = engine.snapshot(at: base.addingTimeInterval(1300))
        #expect(s.isFinished)
        #expect(s.isRunning == false)
        #expect(s.totalRemaining == 0)
        #expect(TimeText.clock(s.splitRemaining) == "0:00")
        // 終了後にいくら時刻が進んでも、追加のイベントは出ない
        #expect(engine.advance(to: base.addingTimeInterval(2000)).isEmpty)
    }

    // MARK: - 6・7. 裏に回っても画面が消えてもズレない

    @Test func 三十秒ぶん判定が飛んでも残り時間はズレない() {
        var engine = TimerEngine(config: TimerConfig(minutes: 20, parts: 4), startedAt: base)
        // 0.1秒ごとの判定を一切せず、いきなり30秒後の時刻を渡す（＝アプリが止まっていた状況）
        _ = engine.advance(to: base.addingTimeInterval(30))
        let s = engine.snapshot(at: base.addingTimeInterval(30))
        #expect(TimeText.clock(s.totalRemaining) == "19:30")
        #expect(TimeText.clock(s.splitRemaining) == "4:30")
    }

    @Test func 区切りを何個も飛び越えても切れ目の振動は一回にまとめる() {
        var engine = TimerEngine(config: TimerConfig(minutes: 20, parts: 4), startedAt: base)
        // 0秒 →  700秒（区切りを2つ跨いだ）
        let events = engine.advance(to: base.addingTimeInterval(700))
        let splitCount = events.filter { if case .splitEnded = $0 { return true } else { return false } }.count
        #expect(splitCount == 1)
        #expect(engine.snapshot(at: base.addingTimeInterval(700)).displayIndex == 3)
    }

    // MARK: - 8. 一時停止

    @Test func 一時停止した時間ぶんは経過しない() {
        var engine = TimerEngine(config: TimerConfig(minutes: 20, parts: 4), startedAt: base)
        engine.pause(at: base.addingTimeInterval(10))

        // 止めている間は、時刻が進んでも数字が動かない
        #expect(TimeText.clock(engine.snapshot(at: base.addingTimeInterval(10)).totalRemaining) == "19:50")
        #expect(TimeText.clock(engine.snapshot(at: base.addingTimeInterval(70)).totalRemaining) == "19:50")
        #expect(engine.advance(to: base.addingTimeInterval(70)).isEmpty)

        // 60秒止めて再開したら、経過は10秒のまま続く
        engine.resume(at: base.addingTimeInterval(70))
        #expect(TimeText.clock(engine.snapshot(at: base.addingTimeInterval(75)).totalRemaining) == "19:45")
    }

    @Test func もう一度で同じ設定の最初に戻る() {
        var engine = TimerEngine(config: TimerConfig(minutes: 20, parts: 4), startedAt: base)
        _ = engine.advance(to: base.addingTimeInterval(1200))
        #expect(engine.snapshot(at: base.addingTimeInterval(1200)).isFinished)

        let again = base.addingTimeInterval(1300)
        engine.restart(at: again)
        let s = engine.snapshot(at: again)
        #expect(s.isFinished == false)
        #expect(s.displayIndex == 1)
        #expect(TimeText.clock(s.totalRemaining) == "20:00")
        // 20%通知のフラグも戻っているので、また鳴る
        #expect(engine.advance(to: again.addingTimeInterval(225)).contains(.warning))
    }

    // MARK: - 9. 割り切れない設定

    @Test func 七分三分割でも最後の区切りがぴったり0で終わる() {
        let config = TimerConfig(minutes: 7, parts: 3)
        #expect(config.boundary(3) == config.totalSeconds)

        var engine = TimerEngine(config: config, startedAt: base)
        let log = run(&engine, from: base, seconds: 420)

        let splits = log.compactMap { entry -> Double? in
            if case .splitEnded = entry.event { return entry.at } else { return nil }
        }
        #expect(splits.count == 2)
        #expect(log.filter { $0.event == .finished }.map(\.at) == [420])

        // 端数が残っていないこと。最後の瞬間は両方0。
        let s = engine.snapshot(at: base.addingTimeInterval(420))
        #expect(s.totalRemaining == 0)
        #expect(s.splitRemaining == 0)
    }

    @Test func 割り切れない設定でも区切りの長さを足し込んだ誤差が出ない() {
        // 1区切り 140.0 秒。3つ足すと 420.0 にならない環境でも、境界計算なら合う。
        let config = TimerConfig(minutes: 7, parts: 3)
        for i in 0...3 {
            #expect(config.boundary(i) == 420.0 * Double(i) / 3.0)
        }
        // 一番端数が出やすい組み合わせでも、最後は必ず全体秒数に一致する
        for minutes in TimerConfig.minuteRange {
            for parts in TimerConfig.partsRange {
                let c = TimerConfig(minutes: minutes, parts: parts)
                #expect(c.boundary(parts) == c.totalSeconds, "\(minutes)分/\(parts)分割で端数が残った")
            }
        }
    }

    // MARK: - 10. 分割なし

    @Test func 分割1でも動く() {
        var engine = TimerEngine(config: TimerConfig(minutes: 5, parts: 1), startedAt: base)
        let s = engine.snapshot(at: base)
        #expect(s.displayIndex == 1)
        #expect(TimeText.clock(s.totalRemaining) == "5:00")
        #expect(TimeText.clock(s.splitRemaining) == "5:00")   // 全体と区切りが同じ

        let log = run(&engine, from: base, seconds: 300)
        // 途中の切れ目は無い。20%（残り1分）の警告と、終了だけ。
        #expect(log.filter { if case .splitEnded = $0.event { return true } else { return false } }.isEmpty)
        #expect(log.filter { $0.event == .warning }.map(\.at) == [225])
        #expect(log.filter { $0.event == .finished }.map(\.at) == [300])
    }

    // MARK: - 11. 短すぎる区切りでは20%通知を出さない

    @Test func 一分十二分割では途中の合図が出ない() {
        let config = TimerConfig(minutes: 1, parts: 12)   // 1区切り5秒 → 残り25%は1.25秒
        #expect(config.givesWarning == false)

        var engine = TimerEngine(config: config, startedAt: base)
        let log = run(&engine, from: base, seconds: 60)
        #expect(log.filter { $0.event == .warning }.isEmpty)
        #expect(engine.snapshot(at: base.addingTimeInterval(4.5)).isWarning == false)
        // 切れ目と終了は普通に起きる
        #expect(log.filter { if case .splitEnded = $0.event { return true } else { return false } }.count == 11)
        #expect(log.filter { $0.event == .finished }.count == 1)
    }

    @Test func 残りが二秒ちょうどなら合図は出る() {
        // 「残りぶんが2秒未満なら出さない」。区切り8秒がちょうど境目（8×0.25 = 2.0）。
        #expect(TimerConfig(minutes: 2, parts: 12).givesWarning == true)   // 120秒/12 = 10秒 → 2.5秒
        #expect(TimerConfig(minutes: 1, parts: 7).givesWarning == true)    // 60秒/7 ≒ 8.6秒 → 2.1秒
        #expect(TimerConfig(minutes: 1, parts: 8).givesWarning == false)   // 60秒/8 = 7.5秒 → 1.9秒
    }

    // MARK: - 範囲

    @Test func 設定は範囲の外へ出られない() {
        #expect(TimerConfig(minutes: 0, parts: 0) == TimerConfig(minutes: 1, parts: 1))
        #expect(TimerConfig(minutes: 999, parts: 99) == TimerConfig(minutes: 180, parts: 12))
        #expect(TimerConfig(minutes: -5, parts: -1).minutes == 1)
    }

    @Test func 時刻が巻き戻っても経過は負にならない() {
        let engine = TimerEngine(config: TimerConfig(minutes: 20, parts: 4), startedAt: base)
        let s = engine.snapshot(at: base.addingTimeInterval(-100))
        #expect(s.elapsed == 0)
        #expect(TimeText.clock(s.totalRemaining) == "20:00")
    }
}

/// 画面の描き直しを減らすための性質。
/// 秒の表示は `Text(timerInterval:)` にシステムが描かせるので、
/// アプリ側の状態が1秒に10回動くと、その意味がなくなる。
struct AnchorTests {
    private let base = Date(timeIntervalSinceReferenceDate: 0)

    @Test func 動いている間は基準時刻が一切動かない() {
        var engine = TimerEngine(config: TimerConfig(minutes: 20, parts: 4), startedAt: base)
        var seen: Set<Date> = []
        for i in 0...3000 {
            let now = base.addingTimeInterval(Double(i) * 0.1)
            _ = engine.advance(to: now)
            seen.insert(engine.snapshot(at: now).anchor)
        }
        #expect(seen == [base])
    }

    @Test func 再開すると止まっていた秒数ぶんだけ基準時刻がずれる() {
        var engine = TimerEngine(config: TimerConfig(minutes: 20, parts: 4), startedAt: base)
        engine.pause(at: base.addingTimeInterval(10))
        engine.resume(at: base.addingTimeInterval(70))   // 60秒止めた
        #expect(engine.snapshot(at: base.addingTimeInterval(70)).anchor == base.addingTimeInterval(60))

        // 再開後も動かない
        let a = engine.snapshot(at: base.addingTimeInterval(80)).anchor
        let b = engine.snapshot(at: base.addingTimeInterval(200)).anchor
        #expect(a == b)
    }
}
