import SwiftUI

struct FavouritesView: View {
    private let store = LibraryStore.shared

    private var sortedFavourites: [Program] {
        store.favourites.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.favourites.isEmpty {
                    ContentUnavailableView {
                        Label("No favourites yet", systemImage: "star")
                    } description: {
                        Text("Star a program from its page and it will appear here.")
                    }
                } else {
                    List {
                        ForEach(sortedFavourites) { program in
                            NavigationLink(value: program) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(program.name)
                                        .font(.headline)
                                    if let broadcasters = program.displayBroadcasters {
                                        Text(broadcasters)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(minHeight: 44)
                                .padding(.vertical, 2)
                                .accessibilityElement(children: .combine)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                if let slug = sortedFavourites[index].slug {
                                    store.removeFavourite(slug: slug)
                                }
                            }
                        }
                    }
                    .navigationDestination(for: Program.self) { program in
                        if let slug = program.slug {
                            ProgramDetailView(summary: program, slug: slug)
                        }
                    }
                }
            }
            .navigationTitle("Favourites")
        }
        .safeAreaInset(edge: .bottom) { MiniPlayerBar() }
        .safeAreaInset(edge: .top) { OfflineBanner() }
    }
}
