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

### Refreshing after the 7-day expiry

A free Personal Team signs the app for only 7 days; once it expires iOS shows
"4ZZZ is no longer available" and it won't launch. Rebuild, reinstall and relaunch
in one line (replace `Memex` with the device name from
`xcrun devicectl list devices`; the device must be unlocked and reachable):

```sh
xcodebuild -project 4ZZZ.xcodeproj -scheme 4ZZZ -configuration Debug -destination 'platform=iOS,name=Memex' -derivedDataPath build-device -allowProvisioningUpdates build && xcrun devicectl device install app --device Memex build-device/Build/Products/Debug-iphoneos/4ZZZ.app && xcrun devicectl device process launch --device Memex com.imr.fourzzz
```

After a reinstall iOS may refuse to launch with *"profile has not been explicitly
trusted by the user"*. Trust the developer once on the iPhone:

1. **Settings → General → VPN & Device Management**.
2. Under *Developer App*, tap **Apple Development: iryan2@gmail.com (…)**.
3. Tap **Trust "Apple Development: …"**, then **Trust** again to confirm.
4. Launch the app.

Trust is recorded per signing certificate, not per Apple ID, so it survives the
weekly 7-day profile refreshes as long as the same Apple Development certificate
is reused (yours is valid until Sep 2027). It only needs redoing if Xcode issues a
new certificate or you remove trust. See `docs/run-on-device.md` for the full
signing walkthrough.

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
