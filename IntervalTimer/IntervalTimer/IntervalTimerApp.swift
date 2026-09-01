import SwiftUI

@main
struct IntervalTimerApp: App {
    @State private var runner = Runner()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(runner)
        }
    }
}
