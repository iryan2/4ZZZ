import SwiftUI

struct LiveView: View {
    @Environment(PlaybackCoordinator.self) private var player

    @State private var channel: Guide = .fm
    @State private var entries: [ScheduleEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var position: (current: ScheduleEntry?, next: ScheduleEntry?) {
        ScheduleResolver.position(in: entries)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Channel", selection: $channel) {
                        ForEach(Guide.allCases) { guide in
                            Text(guide.displayName).tag(guide)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .accessibilityLabel("Channel")
                }

                Section {
                    onAirCard
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Live")
            .task(id: channel) { await load() }
            .refreshable { await load() }
            .safeAreaInset(edge: .bottom) { MiniPlayerBar() }
        }
    }

    private var onAirCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                player.play(.live(channel))
            } label: {
                onAirSummary
            }
            .buttonStyle(.plain)
            .accessibilityHint("Plays the live stream")

            if let next = position.next, next.id != position.current?.id {
                Divider()
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next up")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(next.name)
                            .font(.subheadline.weight(.medium))
                        Text(StationFormat.time(from: next))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var onAirSummary: some View {
        Group {
            if isLoading && entries.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let current = position.current {
                HStack(spacing: 14) {
                    scheduleArtwork(current)
                    VStack(alignment: .leading, spacing: 3) {
                        Label("On air now", systemImage: "dot.radiowaves.left.and.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                        Text(current.name)
                            .font(.headline)
                        if let broadcasters = current.displayBroadcasters {
                            Text(broadcasters)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }
            } else {
                Label("Nothing scheduled right now", systemImage: "moon.zzz")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(onAirAccessibilityLabel)
    }

    private var onAirAccessibilityLabel: String {
        if let current = position.current {
            return "Play \(channel.displayName), on air now \(current.name)"
        }
        return "Play \(channel.displayName)"
    }

    private func scheduleArtwork(_ entry: ScheduleEntry) -> some View {
        Group {
            if let url = entry.artworkURL {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.secondary.opacity(0.15)
                }
            } else {
                Color.secondary.opacity(0.15)
                    .overlay {
                        Image(systemName: "music.mic")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            entries = try await AirNetClient.shared.guide(channel)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
