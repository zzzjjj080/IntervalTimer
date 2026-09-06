// swift-tools-version: 6.0
import PackageDescription

// Watch と iPhone で同じ絵を使うための層。
// **色と円環をここに置く。** 両方に同じコードを持たせると、必ず片方だけ直してずれる。
// WatchKit にも UIKit にも依存させない（SwiftUI だけ）。
let package = Package(
    name: "IntervalTimerUI",
    platforms: [.watchOS(.v11), .iOS(.v18), .macOS(.v14)],
    products: [.library(name: "IntervalTimerUI", targets: ["IntervalTimerUI"])],
    dependencies: [.package(path: "../IntervalTimerCore")],
    targets: [
        .target(name: "IntervalTimerUI", dependencies: [
            .product(name: "IntervalTimerCore", package: "IntervalTimerCore")
        ])
    ]
)
