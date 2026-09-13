import Foundation

/// Client for the public AirNet API that 4ZZZ's own website uses.
/// No authentication, no backend of our own. Responses are cached to disk and a
/// stale copy is served if the network request fails.
actor AirNetClient {
    static let shared = AirNetClient()

    private let baseURL = URL(string: "https://airnet.org.au/rest/stations/4ZZZ")!
    private let onDemandGridURL = URL(string: "https://4zzz.org.au/ondemand/grid.json")!
    private let session: URLSession
    private let cacheDirectory: URL
    private var memoryCache: [String: (stored: Date, data: Data)] = [:]

    private static let day: TimeInterval = 60 * 60 * 24
    private static let scheduleFreshness: TimeInterval = 60 * 10

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.timeoutIntervalForRequest = 20
        session = URLSession(configuration: configuration)

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = caches.appending(path: "AirNet", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func programs() async throws -> [Program] {
        try await get([Program].self, path: "programs", maxAge: Self.day)
    }

    func program(slug: String) async throws -> Program {
        try await get(Program.self, path: "programs/\(slug)", maxAge: Self.day)
    }

    func episodes(slug: String) async throws -> [Episode] {
        try await get([Episode].self, path: "programs/\(slug)/episodes", maxAge: Self.day)
    }

    func guide(_ guide: Guide) async throws -> [ScheduleEntry] {
        try await get([ScheduleEntry].self, path: "guides/\(guide.rawValue)", maxAge: Self.scheduleFreshness)
    }

    /// Keyword tags per program slug, from 4ZZZ's on-demand grid feed.
    /// This is the same source the 4ZZZ website uses for its program keywords.
    func programKeywords() async throws -> [String: [String]] {
        let data = try await data(url: onDemandGridURL, cacheKey: "ondemand-grid", maxAge: Self.day)
        return try ProgramKeywordCatalog.keywordsBySlug(from: data, decoder: Self.decoder)
    }

    // MARK: - Transport

    private func get<T: Decodable>(_ type: T.Type, path: String, maxAge: TimeInterval) async throws -> T {
        let data = try await data(path: path, maxAge: maxAge)
        return try Self.decoder.decode(T.self, from: data)
    }

    private func data(path: String, maxAge: TimeInterval) async throws -> Data {
        try await data(url: baseURL.appending(path: path), cacheKey: path, maxAge: maxAge)
    }

    private func data(url: URL, cacheKey: String, maxAge: TimeInterval) async throws -> Data {
        let cached = cachedData(path: cacheKey)
        if let cached, Date().timeIntervalSince(cached.stored) < maxAge {
            return cached.data
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw AirNetError.badResponse(path: cacheKey)
            }
            store(data: data, path: cacheKey)
            return data
        } catch {
            if let cached {
                return cached.data
            }
            throw error
        }
    }

    private func cachedData(path: String) -> (stored: Date, data: Data)? {
        if let entry = memoryCache[path] {
            return entry
        }
        let url = fileURL(for: path)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let stored = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            ?? .distantPast
        let entry = (stored, data)
        memoryCache[path] = entry
        return entry
    }

    private func store(data: Data, path: String) {
        memoryCache[path] = (Date(), data)
        try? data.write(to: fileURL(for: path), options: .atomic)
    }

    private func fileURL(for path: String) -> URL {
        let name = path.replacingOccurrences(of: "/", with: "_")
        return cacheDirectory.appending(path: name + ".json")
    }

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = BroadcastURL.parseStationDate(string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unrecognised station date: \(string)"
                )
            }
            return date
        }
        return decoder
    }()
}

enum AirNetError: LocalizedError {
    case badResponse(path: String)

    var errorDescription: String? {
        switch self {
        case .badResponse(let path):
            return "The station data could not be loaded (\(path))."
        }
    }
}
