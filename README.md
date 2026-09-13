# 4ZZZ iOS player

A native SwiftUI player for 4ZZZ community radio: the live 102.1FM and Zed Digital
streams, plus the on-demand recordings of past broadcasts. Built as a personal
project with a view to 4ZZZ releasing it through their own channels.

## Requirements

- Xcode 26 (Swift 6)
- iOS 17.0 or later
- No third-party dependencies

## Running

1. Open `4ZZZ.xcodeproj`.
2. Select the **4ZZZ** target → *Signing & Capabilities* → choose a Team.
3. Select a device or simulator and run (⌘R).

## Data sources

Everything comes from 4ZZZ's own public infrastructure. There is no backend of
ours and no API key.

| Purpose | Endpoint |
| --- | --- |
| Live audio (FM / Zed Digital) | `https://iheart.4zzz.org.au/4zzz`, `https://iheart.4zzz.org.au/zed-digital` |
| On-demand recording | `https://undead.4zzz.fm/4zzz/{date}-{hour}-00.mp3` (FM) / `https://undead.4zzz.fm/zed-digital/ZD-…` |
| Program directory, episodes, schedule | `https://airnet.org.au/rest/stations/4ZZZ/…` (`/programs`, `/programs/{slug}`, `/programs/{slug}/episodes`, `/guides/{fm,digital}`) |
| Program keyword tags | `https://4zzz.org.au/ondemand/grid.json` |
| Artwork | `https://amrap-pages-image.s3.amazonaws.com/…` |

The on-demand URL is derived from a broadcast's start date/hour; the recording
itself is a single ~250 MB MP3 that supports byte-range seeking. All schedule
times are interpreted in **Brisbane time (AEST, UTC+10)**, regardless of the
listener's location.

## Data flows and privacy

- **Outbound:** the app only contacts the hosts above — AirNet for catalogue and
  schedule JSON, the Icecast hosts for audio, and the image CDN for artwork.
  Audio is streamed directly; nothing is relayed through us.
- **On device:** favourites and "continue listening" positions are stored in a
  small JSON file in the app's Application Support directory. API responses are
  cached to the app's Caches directory to allow browsing offline.
- **Not collected:** no accounts, no analytics, no tracking, no advertising, no
  personal data. `NSPrivacyTracking` is false and no data types are collected
  (see `4ZZZ/PrivacyInfo.xcprivacy`).

## Handover notes

- Bundle identifier (development): `com.imr.fourzzz`; widget: `com.imr.fourzzz.Widgets`.
  These can be changed to a 4ZZZ-owned identifier before release.
- Swift module: `FourZZZ`.
- Visual styling is centralised in `4ZZZ/Views/Theme.swift` and defaults to stock
  system appearance, so a 4ZZZ brand theme can be applied in one place.
- App icon is a placeholder until 4ZZZ supplies artwork.
- Program keyword tags come from `4zzz.org.au/ondemand/grid.json`. Programs missing
  from that feed have locally derived tags in `4ZZZ/Networking/ProgramTagOverrides.swift`;
  grid tags take precedence, so 4ZZZ can replace the overrides by adding their own.
- Unit tests: `xcodebuild test -scheme 4ZZZ -destination 'platform=iOS Simulator,name=iPhone 17'`.
