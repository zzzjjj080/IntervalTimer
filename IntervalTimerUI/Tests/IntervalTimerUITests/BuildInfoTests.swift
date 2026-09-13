import Testing
@testable import IntervalTimerUI

/// 設定画面のいちばん下に出す「どのビルドが入っているか」の表示。
struct BuildInfoTests {

    @Test func 印があれば版番号の後ろに並べる() {
        #expect(BuildInfo.format(version: "1.1", build: "2", stamp: "b58 09/13 22:06") == "1.1 (2) · b58 09/13 22:06")
    }

    @Test func 印が空なら版番号だけ() {
        // Xcode から直接ビルドすると印は渡らず、空になる
        #expect(BuildInfo.format(version: "1.1", build: "2", stamp: "") == "1.1 (2)")
        #expect(BuildInfo.format(version: "1.1", build: "2", stamp: nil) == "1.1 (2)")
        #expect(BuildInfo.format(version: "1.1", build: "2", stamp: "   ") == "1.1 (2)")
    }

    @Test func 展開されなかった変数は出さない() {
        #expect(BuildInfo.format(version: "1.1", build: "2", stamp: "$(IT_BUILD_STAMP)") == "1.1 (2)")
    }

    @Test func 版番号が読めなくても落ちない() {
        #expect(BuildInfo.format(version: nil, build: nil, stamp: "b1") == "? (?) · b1")
    }
}
