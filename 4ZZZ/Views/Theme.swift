import SwiftUI

/// Central place for visual tokens. Defaults to stock system styling; a future
/// 4ZZZ theme can be swapped in here without touching feature code.
struct Theme: Sendable {
    var live: Color = .red
    var cardCornerRadius: CGFloat = 16
    var artworkCornerRadius: CGFloat = 12

    static let system = Theme()
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.system
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
