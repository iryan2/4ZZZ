import Foundation

extension String {
    /// AirNet returns HTML fragments for descriptions and broadcaster lists.
    /// The app renders plain text, so tags are stripped and common entities decoded.
    var htmlStripped: String {
        let withoutTags = replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        let entities = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#x27;": "'",
            "&#39;": "'",
            "&apos;": "'",
            "&nbsp;": " ",
            "&ndash;": "–",
            "&mdash;": "—",
            "&hellip;": "…",
        ]
        return entities.reduce(withoutTags) { text, pair in
            text.replacingOccurrences(of: pair.key, with: pair.value)
        }
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
