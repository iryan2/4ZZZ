# Running 4ZZZ on a real iPhone (free Personal Team)

This app has **no entitlements files and no App Groups**, so it needs nothing
beyond standard automatic signing. Background audio works under a free Apple ID
(Personal Team).

Current repo state (already set up on this Mac):

- All targets use `CODE_SIGN_STYLE = Automatic`.
- The app and widget targets set `DEVELOPMENT_TEAM = P2FL6PKL52` (Personal Team,
  `iryan2@gmail.com`); the test target has no team because tests run on the
  simulator.
- Bundle IDs: app `com.imr.fourzzz`, widget `com.imr.fourzzz.Widgets`,
  tests `com.imr.fourzzzTests`.
- An `Apple Development: iryan2@gmail.com (4JTMT9Y383)` identity is installed
  (valid to Sep 2027) and Xcode is signed in to the same Apple ID.

The setup steps below are therefore already applied here; they are kept as
instructions for a fresh machine or a new developer.

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

## Then (already applied here)

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
   tap your developer certificate -> **Trust** (see below). Then launch the app.

## Trusting the developer certificate

The **only** manual step after a fresh install. Doing it via the command line is
not possible - the trust decision is made on-device.

1. On the iPhone, open **Settings -> General -> VPN & Device Management**.
2. Under *Developer App*, tap **Apple Development: iryan2@gmail.com (4JTMT9Y383)**.
3. Tap **Trust "Apple Development: …"**, then **Trust** again to confirm.
4. Launch 4ZZZ.

If the app refuses to launch with *"its profile has not been explicitly trusted
by the user"*, this is what is missing. Note the error says *profile*, but iOS
actually records trust against the **signing certificate**:

- Trust is per certificate, **not** per Apple ID or email. Using the same Apple ID
  from another Mac still needs the new certificate trusted.
- The Personal Team certificate is valid for **1 year** (this one to Sep 2027), so
  once trusted it survives the **weekly 7-day profile refreshes** without
  re-trusting - as long as Xcode reuses the same certificate.
- It must be redone only if Xcode rolls/reissues the certificate (e.g. after the
  old one expires or is revoked) or if you remove trust on the iPhone.

There is no way to trust a developer/email permanently. To remove the per-device
trust step entirely you need a **paid Apple Developer Program membership** and
distribution - e.g. TestFlight or an Ad Hoc build - which installs without the
"untrusted developer" prompt (TestFlight builds last 90 days, profiles 1 year).

## Free-account limits (important)

- **Provisioning profiles expire every 7 days**; re-run the build each week to
  re-sign the app - it stops launching once the profile expires ("4ZZZ is no
  longer available"). The signing **certificate** lasts 1 year.
- Up to **3 sideloaded apps** and **10 App IDs per 7 days** (app + widget = 2 IDs).
- Per `AGENTS.md`, `swiftc -typecheck` does **not** catch several Swift 6
  concurrency errors that a real build does. Use a real device build as the
  source of truth.

## Weekly refresh (the usual case)

Once the trust step above has been done, re-signing each week is one line - also
in the README under *Refreshing after the 7-day expiry*. Replace `Memex` with your
device name (`xcrun devicectl list devices`) and make sure the phone is unlocked
and reachable (Wi-Fi is fine once paired):

```sh
xcodebuild -project 4ZZZ.xcodeproj -scheme 4ZZZ -configuration Debug -destination 'platform=iOS,name=Memex' -derivedDataPath build-device -allowProvisioningUpdates build && xcrun devicectl device install app --device Memex build-device/Build/Products/Debug-iphoneos/4ZZZ.app && xcrun devicectl device process launch --device Memex com.imr.fourzzz
```

## Command-line alternative (after signing in to Xcode)

Build only:

```sh
xcodebuild -project 4ZZZ.xcodeproj -scheme 4ZZZ -configuration Debug \
  -destination 'platform=iOS,name=<iPhone name>' \
  -derivedDataPath build-device -allowProvisioningUpdates build
```

Then install and launch the built `.app`:

```sh
xcrun devicectl list devices
xcrun devicectl device install app --device <DEVICE_ID> \
  build-device/Build/Products/Debug-iphoneos/4ZZZ.app
xcrun devicectl device process launch --device <DEVICE_ID> com.imr.fourzzz
```

Notes:

- `-derivedDataPath` is only valid with `-scheme`, never with `-target`.
- `--device` accepts either the device **name** (`Memex`) or the CoreDevice
  identifier from `xcrun devicectl list devices`.
- The `-allowProvisioningUpdates` flag lets Xcode manage the free profile
  non-interactively, but you must already be signed in via Xcode Settings.
- `DEVELOPMENT_TEAM` is already set, so `-destination 'generic/platform=iOS'`
  also works for a device SDK build.

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
  -derivedDataPath build-device -allowProvisioningUpdates build

# Install over the network
xcrun devicectl device install app --device <CORE_DEVICE_ID> \
  build-device/Build/Products/Debug-iphoneos/4ZZZ.app

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

- **"4ZZZ is no longer available"** (profile expired; iOS drops the app) -> run the
  weekly refresh one-liner; the 7-day clock resets.
- **"Untrusted Developer"** / *"its profile has not been explicitly trusted"* on
  launch -> trust the developer certificate on the iPhone (see above).
- **"Unable to install ... requires a development team"** -> `DEVELOPMENT_TEAM`
  missing for the widget target too, not just the app.
- **Launch denied after a successful install** -> almost always the trust step,
  not a signing fault; the certificate is otherwise valid for a year.
- **Simulator build still works regardless** -> these signing changes do not
  affect simulator builds, which skip codesigning entirely.
