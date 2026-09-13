import Foundation

/// Shape of https://4zzz.org.au/ondemand/grid.json — the schedule grid with
/// per-program keyword tags (the same source the 4ZZZ website uses).
struct OnDemandGrid: Decodable {
    let programs: [Slot]

    struct Slot: Decodable {
        let program: ProgramInfo?
    }

    struct ProgramInfo: Decodable {
        let slug: String?
        let keywords: [Keyword]?
    }

    struct Keyword: Decodable {
        let tag: String?
    }
}

enum ProgramKeywordCatalog {
    /// Builds a slug → tags map, merging repeated slots and de-duplicating.
    static func keywordsBySlug(from data: Data, decoder: JSONDecoder) throws -> [String: [String]] {
        let grid = try decoder.decode(OnDemandGrid.self, from: data)

        var result: [String: [String]] = [:]
        for slot in grid.programs {
            guard let slug = slot.program?.slug, !slug.isEmpty else { continue }
            result[slug, default: []].append(contentsOf: (slot.program?.keywords ?? []).compactMap(\.tag))
        }

        return result.mapValues { tags in
            var seen = Set<String>()
            return tags.filter { seen.insert($0).inserted }
        }
    }
}
