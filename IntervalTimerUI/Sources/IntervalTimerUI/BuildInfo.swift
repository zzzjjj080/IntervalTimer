import Foundation

/// 実機に**どのビルドが入っているか**を画面で見分けるための表示。
///
/// 設定画面のいちばん下に小さく出す。`1.0 (1) · b58 09/13 22:06` のように、
/// App Store の版番号と、ビルドした時点の印を並べる。
///
/// **印は手で増やさない。** インストール用のスクリプトが、ビルドのたびに `IT_BUILD_STAMP`
/// （`b<コミット数>` とビルド時刻。まだコミットしていない変更があれば `+`）を渡し、
/// Info.plist の `ITBuildStamp` に入る。手で増やす方式（盤面タスクの `BuildInfo.marker`）は
/// 増やし忘れると印が嘘をつくので、自動にした。Xcode から直接ビルドしたときは印が空になり、版番号だけ出る。
public enum BuildInfo {

    /// いま動いているアプリの表示。
    public static var text: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return format(version: info["CFBundleShortVersionString"] as? String,
                      build: info["CFBundleVersion"] as? String,
                      stamp: info["ITBuildStamp"] as? String)
    }

    /// 表示の組み立て。テストから呼べるよう、Bundle に触らない形で分けてある。
    public static func format(version: String?, build: String?, stamp: String?) -> String {
        let base = "\(version ?? "?") (\(build ?? "?"))"
        guard let stamp = stamp?.trimmingCharacters(in: .whitespaces), !stamp.isEmpty,
              !stamp.hasPrefix("$(") else { return base }
        return "\(base) · \(stamp)"
    }
}
