import SwiftUI

struct MiniPlayerBar: View {
    @Environment(PlaybackCoordinator.self) private var player
    @Environment(\.theme) private var theme
    @State private var isShowingNowPlaying = false

    var body: some View {
        if player.source != nil {
            HStack(spacing: 12) {
                artwork

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.state == .playing ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(player.state == .playing ? "Pause" : "Play")
            }
            .padding(.leading, 10)
            .padding(.trailing, 4)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: theme.cardCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                    .strokeBorder(.separator.opacity(0.5))
            }
            .contentShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius))
            .onTapGesture { isShowingNowPlaying = true }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens the player")
            .sheet(isPresented: $isShowingNowPlaying) {
                NowPlayingView()
            }
        }
    }

    private var artwork: some View {
        Group {
            if let url = player.source?.artworkURL {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    artworkPlaceholder
                }
            } else {
                artworkPlaceholder
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var artworkPlaceholder: some View {
        Color.secondary.opacity(0.15)
            .overlay {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundStyle(.secondary)
            }
    }

    private var title: String {
        switch player.source {
        case .live(let guide): return "Live — \(guide.displayName)"
        case .episode(_, let showName, _, let episodeTitle, _, _, _): return episodeTitle ?? showName
        case nil: return ""
        }
    }

    private var subtitle: String {
        switch player.source {
        case .live: return "4ZZZ"
        case .episode(_, let showName, _, _, _, _, _): return showName
        case nil: return ""
        }
    }
}
