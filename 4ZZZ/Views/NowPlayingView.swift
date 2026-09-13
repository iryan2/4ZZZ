import AVKit
import SwiftUI

struct NowPlayingView: View {
    @Environment(PlaybackCoordinator.self) private var player
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var scrubPosition: Double?
    @ScaledMetric(relativeTo: .largeTitle) private var playButtonSize: CGFloat = 68

    private var displayedElapsed: TimeInterval {
        scrubPosition ?? player.elapsed
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 8)
                artwork
                titleBlock
                if player.isLive {
                    liveBadge
                } else {
                    scrubber
                }
                transport
                sleepTimerStatus
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .accessibilityLabel("Close player")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    sleepTimerMenu
                    RoutePickerView()
                        .frame(width: 32, height: 32)
                        .accessibilityLabel("AirPlay")
                }
            }
        }
    }

    private var artwork: some View {
        Group {
            if let url = player.source?.artworkURL {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    artworkPlaceholder
                }
            } else {
                artworkPlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: theme.artworkCornerRadius))
        .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
        .padding(.horizontal, 12)
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: theme.artworkCornerRadius)
            .fill(.secondary.opacity(0.15))
            .overlay {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
            }
    }

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var liveBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(theme.live)
                .frame(width: 8, height: 8)
            Text("LIVE")
                .font(.subheadline.weight(.bold))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 14)
        .background(theme.live.opacity(0.12), in: Capsule())
        .accessibilityLabel("Live stream")
    }

    private var scrubber: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { scrubPosition ?? player.elapsed },
                    set: { scrubPosition = $0 }
                ),
                in: 0...max(player.duration ?? 0, 1)
            ) { editing in
                if !editing, let position = scrubPosition {
                    player.seek(to: position)
                    scrubPosition = nil
                }
            }
            .disabled(player.duration == nil)
            .accessibilityLabel("Playback position")
            .accessibilityValue(
                "\(StationFormat.clock(displayedElapsed)) of \(StationFormat.clock(player.duration ?? 0))"
            )

            HStack {
                Text(StationFormat.clock(displayedElapsed))
                Spacer()
                if let duration = player.duration {
                    Text("-\(StationFormat.clock(max(0, duration - displayedElapsed)))")
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private var transport: some View {
        VStack(spacing: 22) {
            HStack(spacing: 10) {
                ForEach(skipButtons, id: \.interval) { button in
                    skipButton(button)
                }
            }

            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.state == .playing ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: playButtonSize))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.state == .playing ? "Pause" : "Play")
        }
    }

    private var sleepTimerStatus: some View {
        Group {
            if let remaining = player.sleepTimerRemaining {
                Text("Sleeping in \(StationFormat.clock(remaining))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if player.sleepTimer == .endOfEpisode {
                Text("Stopping at the end of the episode")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sleepTimerMenu: some View {
        Menu {
            Button("Off") { player.setSleepTimer(.off) }
            ForEach([5, 10, 15, 30, 45, 60], id: \.self) { minutes in
                Button("\(minutes) minutes") { player.setSleepTimer(.minutes(minutes)) }
            }
            Button("End of episode") { player.setSleepTimer(.endOfEpisode) }
                .disabled(player.isLive)
        } label: {
            Image(systemName: player.sleepTimer == .off ? "moon.zzz" : "moon.zzz.fill")
        }
        .accessibilityLabel("Sleep timer")
    }

    // MARK: - Skip configuration

    private struct SkipButtonSpec {
        let interval: TimeInterval
        let systemImage: String
        let label: String
        let accessibilityLabel: String
    }

    private var skipButtons: [SkipButtonSpec] {
        player.canSeek
            ? [
                SkipButtonSpec(interval: -300, systemImage: "gobackward", label: "5 min", accessibilityLabel: "Back 5 minutes"),
                SkipButtonSpec(interval: -30, systemImage: "gobackward.30", label: "30 sec", accessibilityLabel: "Back 30 seconds"),
                SkipButtonSpec(interval: -5, systemImage: "gobackward.5", label: "5 sec", accessibilityLabel: "Back 5 seconds"),
                SkipButtonSpec(interval: 5, systemImage: "goforward.5", label: "5 sec", accessibilityLabel: "Forward 5 seconds"),
                SkipButtonSpec(interval: 30, systemImage: "goforward.30", label: "30 sec", accessibilityLabel: "Forward 30 seconds"),
                SkipButtonSpec(interval: 300, systemImage: "goforward", label: "5 min", accessibilityLabel: "Forward 5 minutes"),
            ]
            : []
    }

    private func skipButton(_ spec: SkipButtonSpec) -> some View {
        Button {
            player.skip(by: spec.interval)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: spec.systemImage)
                    .font(.title2)
                Text(spec.label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spec.accessibilityLabel)
    }

    // MARK: - Text

    private var title: String {
        switch player.source {
        case .live(let guide): return "Live — \(guide.displayName)"
        case .episode(_, let showName, _, let episodeTitle, _, _, _): return episodeTitle ?? showName
        case nil: return "Nothing playing"
        }
    }

    private var subtitle: String {
        switch player.source {
        case .live: return "4ZZZ Community Radio"
        case .episode(_, let showName, _, _, _, _, _): return showName
        case nil: return ""
        }
    }
}

struct RoutePickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = false
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
