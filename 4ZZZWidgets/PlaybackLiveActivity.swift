import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

struct PlaybackLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PlaybackActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    artwork(context.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(context.state.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    statusIcon(context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.isLive ? "LIVE" : "4ZZZ")
                        .font(.caption2.bold())
                        .foregroundStyle(context.state.isLive ? .red : .secondary)
                }
            } compactLeading: {
                statusIcon(context.state)
            } compactTrailing: {
                Text(context.state.isLive ? "LIVE" : "4ZZZ")
                    .font(.caption2)
            } minimal: {
                statusIcon(context.state)
            }
            .keylineTint(.red)
        }
    }

    private func artwork(_ state: PlaybackActivityAttributes.ContentState) -> some View {
        Group {
            if let data = state.artworkData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.secondary.opacity(0.2)
                    .overlay {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func statusIcon(_ state: PlaybackActivityAttributes.ContentState) -> some View {
        Image(systemName: state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
            .font(.title3)
    }
}

private struct LockScreenView: View {
    let state: PlaybackActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let data = state.artworkData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.secondary.opacity(0.2)
                        .overlay {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(state.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(state.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if state.isLive {
                    Text("LIVE")
                        .font(.caption2.bold())
                        .foregroundStyle(.red)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.largeTitle)
        }
        .padding()
    }
}
