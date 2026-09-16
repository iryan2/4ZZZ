# AGENTS.md

Native SwiftUI iOS app: the 4ZZZ community-radio player (live 102.1FM/Zed Digital
plus on-demand recordings). `README.md` covers the data sources, endpoint URLs and
data flows in detail.

## Build & test

```
# Simulator build
xcodebuild -project 4ZZZ.xcodeproj -scheme 4ZZZ -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build

# Tests (Swift Testing, not XCTest)
xcodebuild test -project 4ZZZ.xcodeproj -scheme 4ZZZ \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO

# Device build when no simulator runtime is installed
xcodebuild -project 4ZZZ.xcodeproj -target 4ZZZ -sdk iphoneos \
  CODE_SIGNING_ALLOWED=NO build
```

- `swiftc -typecheck` does **not** catch several Swift 6 concurrency errors that
  `xcodebuild` does. Verify changes with a real build, not just type-check.
- `-derivedDataPath` is only valid with `-scheme`, never with `-target`.
- Simulator names/OSes vary; see `xcrun simctl list devices available`.
- Device runs need a Signing Team set in Xcode (open `4ZZZ.xcodeproj`).

## Project layout / build system

- `4ZZZ.xcodeproj/project.pbxproj` is **hand-written** (no generator). Source
  folders use `PBXFileSystemSynchronizedRootGroup`, so new `.swift` files under
  `4ZZZ/`, `4ZZZWidgets/`, `4ZZZTests/` compile automatically — no pbxproj edit
  needed for ordinary files. New *targets* or build-setting changes must be
  edited by hand. There is currently no `Shared/` group; if shared app/widget
  code is needed again, migrate `PlaybackSource`/model types into one and add it
  to both targets' `fileSystemSynchronizedGroups`.
- The `4ZZZWidgets` extension target is retained for future widgets but its
  bundle is currently empty. `NSSupportsLiveActivities` stays declared so a Live
  Activity can be reintroduced without project changes; the previous
  implementation lives in git history (`2a3a2ea`).
- `Config/Info.plist` and `Config/Widgets-Info.plist` are partial plists merged
  with `GENERATE_INFOPLIST_FILE = YES`. Array-valued keys (`UIBackgroundModes`,
  `NSSupportsLiveActivities`) do **not** work via `INFOPLIST_KEY_*` — they must go
  in these files.
- Target `4ZZZ` is not a valid Swift module name, so `PRODUCT_MODULE_NAME = FourZZZ`;
  tests use `@testable import FourZZZ`.
- Bundle ids: app `com.imr.fourzzz`, widget `com.imr.fourzzz.Widgets` (must stay
  prefixed by the app id), tests `com.imr.fourzzzTests`.
- iOS 17 deployment target, Swift 6, **no third-party dependencies** — do not add
  packages.

## Conventions & gotchas

- All audio goes through `Playback/PlaybackCoordinator.swift` (single `AVPlayer`,
  audio session, interruptions, sleep timer, resume/progress). Views never touch
  `AVPlayer` directly.
- API times are naive station-local strings and must be interpreted in Brisbane
  time via `BroadcastURL` (it avoids `DateFormatter`, which isn't concurrency-safe).
- `Networking/AirNetClient.swift` decodes AirNet JSON and also fetches program
  keyword tags from `4zzz.org.au/ondemand/grid.json`; per-program fallbacks live in
  `Networking/ProgramTagOverrides.swift` (grid tags win over overrides).
- Swift 6 concurrency workarounds already in place — preserve them:
  - `MPMediaItemArtwork`'s handler is called on a MediaPlayer queue, so it is built
    by a `nonisolated` function (`PlaybackCoordinator.makeArtwork`).
  - Notification observers hop via `MainActor.assumeIsolated` and must only pass
    `Sendable` values across the boundary.
- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`) and launch the app
  (`TEST_HOST`); put pure logic in testable types (e.g. `ProgramKeywordCatalog`)
  rather than inside actors where possible.

## Troubleshooting

- "Unable to find a destination matching ... platform:iOS Simulator": Xcode's iOS
  platform/simulator runtime is not installed. Install it via Xcode → Settings →
  Components, or use the `-sdk iphoneos -target` build above.
