import Foundation
import Observation

struct ListeningProgress: Codable, Identifiable, Hashable, Sendable {
    var episodeID: String
    var showSlug: String
    var showName: String
    var title: String?
    var start: Date
    var guide: Guide
    var artworkURL: URL?
    var duration: TimeInterval
    var position: TimeInterval
    var updatedAt: Date
    var completed: Bool

    var id: String { episodeID }

    var fraction: Double {
        guard duration > 0 else { return 0 }
        return min(max(position / duration, 0), 1)
    }

    var playbackSource: PlaybackSource {
        .episode(
            showSlug: showSlug,
            showName: showName,
            episodeID: episodeID,
            title: title,
            start: start,
            guide: guide,
            artworkURL: artworkURL
        )
    }
}

@MainActor
@Observable
final class LibraryStore {
    static let shared = LibraryStore()

    private(set) var favourites: [Program] = []
    private(set) var continueListening: [ListeningProgress] = []

    private var saveTask: Task<Void, Never>?
    private let fileURL: URL

    private init() {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appending(path: "Library.json")
        load()
    }

    // MARK: - Favourites

    func isFavourite(slug: String) -> Bool {
        favourites.contains { $0.slug == slug }
    }

    func toggleFavourite(_ program: Program) {
        guard let slug = program.slug, !slug.isEmpty else { return }
        if let index = favourites.firstIndex(where: { $0.slug == slug }) {
            favourites.remove(at: index)
        } else {
            favourites.append(program)
        }
        scheduleSave()
    }

    func removeFavourite(slug: String) {
        favourites.removeAll { $0.slug == slug }
        scheduleSave()
    }

    // MARK: - Continue listening

    /// Records playback progress. Completed episodes are dropped from the list.
    func recordProgress(
        source: PlaybackSource,
        position: TimeInterval,
        duration: TimeInterval,
        completed: Bool
    ) {
        guard
            let episodeID = source.episodeID,
            let showSlug = source.showSlug
        else { return }

        if completed {
            continueListening.removeAll { $0.episodeID == episodeID }
            scheduleSave()
            return
        }

        // Ignore trivial progress so loading a title doesn't clutter the list.
        guard position > 15, duration > 0 else { return }

        let entry = ListeningProgress(
            episodeID: episodeID,
            showSlug: showSlug,
            showName: Self.showName(of: source),
            title: Self.title(of: source),
            start: source.episodeStart ?? Date(),
            guide: source.guide,
            artworkURL: source.artworkURL,
            duration: duration,
            position: position,
            updatedAt: Date(),
            completed: false
        )

        if let index = continueListening.firstIndex(where: { $0.episodeID == episodeID }) {
            continueListening[index] = entry
        } else {
            continueListening.append(entry)
        }
        continueListening.sort { $0.updatedAt > $1.updatedAt }
        if continueListening.count > 10 {
            continueListening = Array(continueListening.prefix(10))
        }
        scheduleSave()
    }

    func savedPosition(for source: PlaybackSource) -> TimeInterval? {
        guard let episodeID = source.episodeID else { return nil }
        guard let entry = continueListening.first(where: { $0.episodeID == episodeID }) else { return nil }
        return entry.position
    }

    func removeProgress(episodeID: String) {
        continueListening.removeAll { $0.episodeID == episodeID }
        scheduleSave()
    }

    // MARK: - Persistence

    private struct State: Codable {
        var favourites: [Program] = []
        var progress: [ListeningProgress] = []
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let state = try? decoder.decode(State.self, from: data) else { return }
        favourites = state.favourites
        continueListening = state.progress
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        let state = State(favourites: favourites, progress: continueListening)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Helpers

    private static func showName(of source: PlaybackSource) -> String {
        if case .episode(_, let showName, _, _, _, _, _) = source { return showName }
        return ""
    }

    private static func title(of source: PlaybackSource) -> String? {
        if case .episode(_, _, _, let title, _, _, _) = source { return title }
        return nil
    }
}
