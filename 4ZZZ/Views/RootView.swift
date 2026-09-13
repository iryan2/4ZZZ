import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            ProgramsView()
                .tabItem {
                    Label("Programs", systemImage: "square.grid.2x2")
                }

            LiveView()
                .tabItem {
                    Label("Live", systemImage: "dot.radiowaves.left.and.right")
                }

            FavouritesView()
                .tabItem {
                    Label("Favourites", systemImage: "star")
                }
        }
    }
}
