import SwiftUI

@main
struct FourZZZApp: App {
    @State private var player = PlaybackCoordinator()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(player)
                .environment(\.theme, .system)
        }
    }
}
