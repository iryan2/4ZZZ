import SwiftUI

/// A compact, non-interactive line of program keyword tags.
struct KeywordLine: View {
    let keywords: [String]

    var body: some View {
        if !keywords.isEmpty {
            Text(keywords.joined(separator: "  ·  "))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
