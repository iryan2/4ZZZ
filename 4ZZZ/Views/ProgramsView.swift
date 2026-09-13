import SwiftUI

struct ProgramsView: View {
    @Environment(PlaybackCoordinator.self) private var player
    private let store = LibraryStore.shared

    @State private var programs: [Program] = []
    @State private var keywordsBySlug: [String: [String]] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var query = ""

    private func keywords(for program: Program) -> [String] {
        guard let slug = program.slug else { return [] }
        return ProgramTagOverrides.tags(for: slug, grid: keywordsBySlug)
    }

    private var filteredPrograms: [Program] {
        let active = programs
            .filter { !($0.archived ?? false) && $0.hasUsableSlug }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        guard !query.isEmpty else { return active }
        return active.filter { program in
            if program.name.localizedCaseInsensitiveContains(query) { return true }
            if program.displayBroadcasters?.localizedCaseInsensitiveContains(query) == true { return true }
            return keywords(for: program).contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private var showsContinueListening: Bool {
        query.isEmpty && !store.continueListening.isEmpty
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Programs")
                .searchable(text: $query, prompt: "Search programs")
                .task { await load() }
                .refreshable { await load(force: true) }
                .navigationDestination(for: Program.self) { program in
                    if let slug = program.slug {
                        ProgramDetailView(summary: program, slug: slug)
                    }
                }
        }
        .safeAreaInset(edge: .bottom) { MiniPlayerBar() }
        .safeAreaInset(edge: .top) { OfflineBanner() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && programs.isEmpty {
            ProgressView("Loading programs…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage, programs.isEmpty {
            ContentUnavailableView {
                Label("Can't load programs", systemImage: "wifi.exclamationmark")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again") { Task { await load(force: true) } }
            }
        } else if filteredPrograms.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            List {
                if showsContinueListening {
                    Section("Continue listening") {
                        ForEach(store.continueListening) { entry in
                            continueListeningRow(entry)
                        }
                    }
                }

                Section {
                    ForEach(filteredPrograms) { program in
                        NavigationLink(value: program) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(program.name)
                                    .font(.headline)
                                if let broadcasters = program.displayBroadcasters {
                                    Text(broadcasters)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                KeywordLine(keywords: keywords(for: program))
                            }
                            .frame(minHeight: 44)
                            .padding(.vertical, 2)
                            .accessibilityElement(children: .combine)
                        }
                    }
                } header: {
                    if showsContinueListening {
                        Text("Programs")
                    }
                }
            }
        }
    }

    private func continueListeningRow(_ entry: ListeningProgress) -> some View {
        Button {
            player.play(entry.playbackSource)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.title ?? entry.showName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(entry.showName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                ProgressView(value: entry.fraction)
                    .tint(.accentColor)
                HStack {
                    Text(StationFormat.clock(entry.position))
                    Spacer()
                    Text(StationFormat.clock(entry.duration))
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Resume \(entry.title ?? entry.showName), \(Int(entry.fraction * 100)) percent played"
            )
        }
        .buttonStyle(.plain)
        .swipeActions {
            Button(role: .destructive) {
                store.removeProgress(episodeID: entry.episodeID)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private func load(force: Bool = false) async {
        if !programs.isEmpty && !force { return }
        isLoading = true
        errorMessage = nil
        do {
            async let programsTask = AirNetClient.shared.programs()
            async let keywordsTask = AirNetClient.shared.programKeywords()
            programs = try await programsTask
            keywordsBySlug = (try? await keywordsTask) ?? [:]
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
