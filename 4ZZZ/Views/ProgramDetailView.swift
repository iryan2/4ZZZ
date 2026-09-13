import SwiftUI

struct ProgramDetailView: View {
    let summary: Program
    let slug: String

    @Environment(PlaybackCoordinator.self) private var player
    private let store = LibraryStore.shared
    @State private var program: Program?
    @State private var episodes: [Episode] = []
    @State private var keywords: [String] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var displayedProgram: Program { program ?? summary }

    var body: some View {
        List {
            Section {
                header
            }

            Section("Recent episodes") {
                if isLoading && episodes.isEmpty {
                    ProgressView()
                } else if episodes.isEmpty {
                    Text("No recent episodes available.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(episodes) { episode in
                        episodeRow(episode)
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(displayedProgram.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                favouriteButton
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private var favouriteButton: some View {
        let isFavourite = store.isFavourite(slug: slug)
        return Button {
            store.toggleFavourite(displayedProgram)
        } label: {
            Image(systemName: isFavourite ? "star.fill" : "star")
        }
        .accessibilityLabel(isFavourite ? "Remove from favourites" : "Add to favourites")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let artworkURL = displayedProgram.artworkURL {
                AsyncImage(url: artworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.secondary.opacity(0.15)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text(displayedProgram.name)
                .font(.title2.bold())

            if let broadcasters = displayedProgram.displayBroadcasters {
                Text(broadcasters)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            KeywordLine(keywords: keywords)

            if let description = displayedProgram.displayDescription {
                Text(description)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }

    private func episodeRow(_ episode: Episode) -> some View {
        Button {
            play(episode)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 3) {
                    Text(episodeTitle(episode))
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("\(StationFormat.dateTime(episode.start)) · \(StationFormat.duration(episode.duration))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 44)
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Play \(episodeTitle(episode)), \(StationFormat.dateTime(episode.start))")
        }
        .buttonStyle(.plain)
    }

    private func episodeTitle(_ episode: Episode) -> String {
        episode.displayTitle ?? "\(displayedProgram.name) — \(StationFormat.day(episode.start))"
    }

    private func play(_ episode: Episode) {
        player.play(
            .episode(
                showSlug: slug,
                showName: displayedProgram.name,
                episodeID: episode.id,
                title: episodeTitle(episode),
                start: episode.start,
                guide: displayedProgram.guide,
                artworkURL: episode.artworkURL ?? displayedProgram.artworkURL
            )
        )
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let programTask = AirNetClient.shared.program(slug: slug)
            async let episodesTask = AirNetClient.shared.episodes(slug: slug)
            async let keywordsTask = AirNetClient.shared.programKeywords()
            let (loadedProgram, loadedEpisodes) = try await (programTask, episodesTask)
            program = loadedProgram
            episodes = loadedEpisodes.sorted { $0.start > $1.start }
            keywords = ProgramTagOverrides.tags(for: slug, grid: (try? await keywordsTask) ?? [:])
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
