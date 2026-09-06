import SwiftUI

/// iPhone 側のアプリ。
///
/// **なぜ存在するか。** Xcode は watchOS のアーカイブを App Store へ出せないので、
/// iOS アプリを配信の器にして、その中に Watch アプリを入れている。
///
/// ただし器として空にはしない。**同じタイマーを iPhone でも使えるようにしてある。**
/// 中身の無いアプリは審査で止まるし、入れた人も困る。
/// 時間の測り方は Watch と同じ `IntervalTimerCore`、絵は `IntervalTimerUI` を共有している。
@main
struct IntervalTimerPhoneApp: App {
    var body: some Scene {
        WindowGroup { PhoneRootView() }
    }
}
