// swift-tools-version: 6.0
import PackageDescription

// UIにもHealthKitにも依存しないロジック層。
// 「今が何時か」を渡したら「何秒残っていて、いま何を鳴らすべきか」が返るところまでをここで固める。
// Xcodeを開かなくても `swift test` で回せる。
let package = Package(
    name: "IntervalTimerCore",
    platforms: [.watchOS(.v11), .iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "IntervalTimerCore", targets: ["IntervalTimerCore"])
    ],
    targets: [
        .target(name: "IntervalTimerCore"),
        .testTarget(name: "IntervalTimerCoreTests", dependencies: ["IntervalTimerCore"])
    ]
)
