import Foundation

/// Keyword tags for programs that are missing from 4ZZZ's on-demand grid feed.
///
/// These were derived from each program's own description. The grid feed always
/// wins when it has tags for a slug, so if 4ZZZ later adds their own keywords the
/// entries here are simply ignored.
enum ProgramTagOverrides {
    static let tagsBySlug: [String: [String]] = [
        "a-new-jazz-soul": ["Jazz", "Soul", "Electronic", "Local"],
        "afternooons-on-4zzz": ["Music", "Variety"],
        "anarchist-world-this-week": ["Activism", "Current Affairs", "Politics", "Discussion"],
        "balkan-beats": ["Dance", "Worldwide"],
        "brizzzbane-batcave": ["Post Punk", "Alternative", "Underground"],
        "brisfinte-zed": ["Brisbane", "Local", "Music"],
        "generation-zzz": ["Community", "Music", "Discussion"],
        "gravy-train": ["Variety", "Eclectic", "Diverse"],
        "i-promise-i-am-not-crazy": ["History", "Culture", "Curiosity"],
        "incubatorzzz": ["Community", "Diverse", "Disability"],
        "interludezzz": ["Variety", "Eclectic", "Community"],
        "las-gidi-vybes": ["Worldwide", "Dance", "Culture", "Afrobeat"],
        "le-sound": ["Worldwide", "Hip-hop", "Indie", "Diverse"],
        "locked-in-sessions": ["Prison", "Requests", "Social Justice", "Community"],
        "lofi-beats-to-chill-and-overthrow-the-government-to": ["Beats", "Electronic", "Political", "Ambient"],
        "molotov-cocktail-random-tracks": ["Interviews", "Local", "Arts", "Community"],
        "proletarians-transition": ["Spiritual", "Experimental", "Discussion"],
        "protis-reviews": ["Reviews", "Local", "Brisbane", "New Music Reviews"],
        "randomizzzed-extended-wake-up": ["Random", "Variety", "Mornings"],
        "regurged-radio": ["Nostalgia", "Rock", "90s"],
        "special-selections": ["Eclectic", "Music", "Variety"],
        "static-mindzzz": ["Mental Health", "Music", "Interviews", "Community"],
        "table-top-talkz": ["Discussion", "Banter", "Culture"],
        "talker-space": ["Local", "Brisbane", "Youth", "Music"],
        "the-lobster-trick": ["Experimental", "Worldwide", "Eclectic"],
        "the-proper-gander": ["Banter", "Fun", "Music", "Alternative"],
        "velvet-squawkback": ["Mornings", "Ambient", "Eclectic"],
        "where-its-at": ["Local", "Brisbane", "New Music Reviews", "Music"],
        "whispers-from-the-star-river": ["Literature", "Science", "Culture"],
        "zed-youth": ["Youth", "Local", "Music", "Community"],
        "shoegrazzze": ["Shoegaze", "Indie", "Ambient", "Dream Pop"],
    ]

    /// Grid keywords take precedence; overrides fill the gaps.
    static func tags(for slug: String, grid: [String: [String]]) -> [String] {
        if let gridTags = grid[slug], !gridTags.isEmpty {
            return gridTags
        }
        return tagsBySlug[slug] ?? []
    }
}
