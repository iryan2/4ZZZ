import SwiftUI

@main
struct FourZZZApp: App {
    @State private var player = PlaybackCoordinator.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(player)
                .environment(\.theme, .system)
        }
    }
}
