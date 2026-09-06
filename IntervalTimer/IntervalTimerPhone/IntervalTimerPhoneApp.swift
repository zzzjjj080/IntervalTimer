import SwiftUI

/// iPhone 側のアプリ。
///
/// **なぜ存在するか。** Xcode は watchOS のアーカイブを App Store へ出せない
/// （配布方式のクラスが iOS / Mac / tvOS / visionOS の分しか無い）。
/// Apple の想定は「iOS アプリの中に Watch アプリを入れて出す」形なので、
/// その器としてこのターゲットがある。
///
/// ただし器として空にはしない。**同じタイマーを iPhone でも使えるようにする。**
/// 中身の無いアプリは審査（2.1 / 4.2）で止まるし、そもそも入れた人が困る。
@main
struct IntervalTimerPhoneApp: App {
    var body: some Scene {
        WindowGroup {
            PhoneRootView()
        }
    }
}
