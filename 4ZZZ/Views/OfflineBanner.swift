import SwiftUI

struct OfflineBanner: View {
    private var monitor = NetworkMonitor.shared

    var body: some View {
        if monitor.isOffline {
            Label("You're offline — showing saved content", systemImage: "wifi.slash")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(.yellow.opacity(0.18))
        }
    }
}
