import UIKit

@MainActor
final class ArtworkLoader {
    private var cache: [URL: UIImage] = [:]

    func image(for url: URL) async -> UIImage? {
        if let cached = cache[url] {
            return cached
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            cache[url] = image
            return image
        } catch {
            return nil
        }
    }
}
