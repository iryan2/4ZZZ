# Running 4ZZZ on a real iPhone (free Personal Team)

This app has **no entitlements files and no App Groups**, so it needs nothing
beyond standard automatic signing. Background audio and Live Activities work
under a free Apple ID (Personal Team).

Current repo state this guide assumes:

- All targets use `CODE_SIGN_STYLE = Automatic`.
- No `DEVELOPMENT_TEAM` is set anywhere in `4ZZZ.xcodeproj/project.pbxproj`.
- Bundle IDs: app `com.imr.fourzzz`, widget `com.imr.fourzzz.Widgets`,
  tests `com.imr.fourzzzTests`.
- No Apple ID is signed into Xcode and there are no codesigning identities yet.

## Prerequisites (you, on Mac and iPhone)

1. **Enable Developer Mode on the iPhone**
   - Settings -> Privacy & Security -> Developer Mode -> On -> reboot the phone.
   - The toggle may only appear *after* the phone has been connected to Xcode once.

2. **Connect the iPhone by cable**
   - Tap **Trust This Computer** on the phone and enter the passcode.

3. **Sign in to Xcode**
   - Xcode -> Settings (Cmd-,) -> Accounts -> **+** -> add your Apple ID.
   - A free **Personal Team** appears automatically for that account.

4. **Connect the device and let Xcode see it**
   - In Xcode, open the run-destination menu; your iPhone should be listed.
   - If it shows as "unavailable", the Developer Mode step above still needs doing.

## Then (assistant / manual edits)

5. **Discover your Team ID** from the installed provisioning profile:

   ```sh
   security cms -D -i ~/Library/MobileDevice/Provisioning\ Profiles/*.mobileprovision \
     | plutil -extract TeamIdentifier.0 raw -
   ```

   Alternatively find it in Xcode -> Settings -> Accounts (the team is listed with
   its ID), or on the Apple Developer website.

6. **Bake `DEVELOPMENT_TEAM` into the project**
   - Add `DEVELOPMENT_TEAM = <YOUR_TEAM_ID>;` to all app/widget build
     configurations in `4ZZZ.xcodeproj/project.pbxproj`:
     - app: `1A000000000000000000000E` (Debug), `1A000000000000000000000F` (Release)
     - widget: `2B0000000000000000000009` (Debug), `2B000000000000000000000A` (Release)
   - Keep `CODE_SIGN_STYLE = Automatic`.
   - The test target only needs a team if you plan to run tests on the device;
     tests are otherwise run against the simulator.

7. **Handle a bundle-ID clash if it happens**
   - Apple bundle IDs are globally unique. If `com.imr.fourzzz` is already
     registered by someone else, Xcode's automatic signing will fail with an
     "app ID is not available" error.
   - Fix by switching the app to `com.imr.fourzzz.dev` and the widget to
     `com.imr.fourzzz.dev.Widgets`, updating both `project.pbxproj` and the README.
   - Also update the widget extension's `NSExtension` / embed config only if Xcode
     flags a mismatch; normally just the `PRODUCT_BUNDLE_IDENTIFIER` values change.

## Build & install

8. In Xcode, confirm the Team is your **Personal Team** for **both** the `4ZZZ`
   and `4ZZZWidgets` targets (Signing & Capabilities), select the iPhone as the
   run destination, and press **Cmd-R**.
   - The first build registers the device and creates the certificate and
     provisioning profiles. Xcode may prompt for the Mac login password.

9. On the iPhone: Settings -> General -> **VPN & Device Management** ->
   trust your developer certificate. Then launch the app.

## Free-account limits (important)

- Certificates/profiles **expire every 7 days**; re-run from Xcode each week to
  re-sign the app. It will stop launching once the profile expires.
- Up to **3 sideloaded apps** and **10 App IDs per 7 days** (app + widget = 2 IDs).
- Per `AGENTS.md`, `swiftc -typecheck` does **not** catch several Swift 6
  concurrency errors that a real build does. Use a real device build as the
  source of truth.

## Command-line alternative (after signing in to Xcode)

```sh
xcodebuild -project 4ZZZ.xcodeproj -scheme 4ZZZ -configuration Debug \
  -destination 'platform=iOS,name=<iPhone name>' \
  -allowProvisioningUpdates build
```

Then install the built `.app`:

```sh
xcrun devicectl list devices
xcrun devicectl device install app --device <DEVICE_ID> \
  build/Build/Products/Debug-iphoneos/4ZZZ.app
```

Notes:

- `-derivedDataPath` is only valid with `-scheme`, never with `-target`.
- The `-allowProvisioningUpdates` flag lets Xcode manage the free profile
  non-interactively, but you must already be signed in via Xcode Settings.
- If you set `DEVELOPMENT_TEAM` in step 6, you can add
  `-destination 'generic/platform=iOS'` for a device SDK build.

## Wireless install (no cable)

The iPhone must have been paired over cable **once**, with **Connect via network**
enabled (Xcode -> Window -> Devices and Simulators -> select the iPhone ->
check *Connect via network*). After that it can be built to and installed over
Wi-Fi. Confirm the Mac can reach it:

```sh
xcrun devicectl list devices --verbose | grep -A 3 connectionProperties
```

You want `transportType: localNetwork` and `tunnelState: connected`. Then build,
install and launch entirely wirelessly:

```sh
# Build for the device (id is the UDID, not the CoreDevice identifier)
xcodebuild -project 4ZZZ.xcodeproj -scheme 4ZZZ -configuration Debug \
  -destination 'platform=iOS,id=<UDID>' \
  -derivedDataPath build -allowProvisioningUpdates build

# Install over the network
xcrun devicectl device install app --device <CORE_DEVICE_ID> \
  build/Build/Products/Debug-iphoneos/4ZZZ.app

# Launch it
xcrun devicectl device process launch --device <CORE_DEVICE_ID> com.imr.fourzzz
```

Finding the two IDs:

- `<UDID>` is the `id` shown by
  `xcodebuild -project 4ZZZ.xcodeproj -scheme 4ZZZ -showdestinations`.
- `<CORE_DEVICE_ID>` is the `Identifier` column of `xcrun devicectl list devices`.

Notes:

- The build destination uses the phone's **UDID**, while `devicectl` uses the
  **CoreDevice identifier** — these are different values.
- Do **not** pass `CODE_SIGNING_ALLOWED=NO` for a device install; the build must
  be signed (the command above signs automatically with the configured team).
- With the iPhone selected as the run destination in Xcode, **Cmd-R** also
  installs wirelessly, so the commands above are only needed for scripted builds.

## Troubleshooting

- **"Untrusted Developer"** on launch -> do step 9.
- **"Unable to install ... requires a development team"** -> `DEVELOPMENT_TEAM`
  missing for the widget target too, not just the app.
- **Profile expired** -> plug in and Cmd-R again; 7-day clock resets.
- **Simulator build still works regardless** -> these signing changes do not
  affect simulator builds, which skip codesigning entirely.
