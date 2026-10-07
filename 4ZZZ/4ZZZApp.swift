import SwiftUI

@main
struct FourZZZApp: App {
    @State private var player = PlaybackCoordinator.shared
    @State private var identifier = TrackIdentifier()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(player)
                .environment(identifier)
                .environment(\.theme, .system)
        }
    }
}
