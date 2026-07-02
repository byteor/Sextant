<h1><img src="assets/about/about_icon.png" width="128" alt="" valign="middle"> Sextant</h1>

A lightweight LAN scanner for discovering and monitoring devices on your local network. Built with Flutter for macOS, Linux, and Windows.

## Features

### Device Discovery

Sextant runs six complementary discovery protocols in parallel, so it finds devices that block ping, have no open ports, or use private MAC addresses:

| Protocol            | What it finds                                        |
| ------------------- | ---------------------------------------------------- |
| **ICMP ping sweep** | Online hosts; measures round-trip latency            |
| **ARP table**       | Every L2-present device, including ICMP-silent ones  |
| **TCP port scan**   | Open ports and running services via banner grabbing  |
| **mDNS / Bonjour**  | Apple and other devices broadcasting a friendly name |
| **NetBIOS**         | Windows machine names                                |
| **SSDP / UPnP**     | Routers, smart TVs, printers, and IoT devices        |

Each protocol can be individually enabled or disabled in Settings.

### Device Table

The main view shows a resizable table with columns for:

- **Status** — online/offline dot with latency tooltip
- **IP address** — primary IP; multi-homed hosts show a `+N` badge for additional IPs
- **Name** — resolved hostname, user-assigned name (italic + bold), or IP fallback
- **MAC address** — hardware address
- **Vendor** — manufacturer from the IEEE OUI database
- **Open ports** — port chips colour-coded by service identification; hover for port name and banner
- **Found via** — icons for which protocols discovered the device
- **Latency** — most recent ICMP round-trip time

Column widths are resizable by dragging the dividers.

### Device Type Classification

Sextant automatically classifies devices into types based on hostname patterns, open ports, mDNS service labels, and OUI vendor: router, computer, laptop, phone, tablet, printer, NAS, TV, speaker, and IoT. You can override the classification per device from the context menu.

### Device Actions

Right-click (or long-press) any device row to:

- **Open in browser** — opens `http://` or `https://` (shown when port 80 or 443 is open)
- **Rename** — assign a custom name that persists across scans
- **Change type** — override the automatic device type
- **Copy IP / Copy MAC** — copies to clipboard
- **Wake on LAN** — sends a magic packet to the device's MAC address

### Live Monitoring

Enable background monitoring to re-scan automatically on a configurable interval (10 s – 5 min). When a re-scan finds a device that wasn't there before, a snackbar notification lists the new arrivals. Devices that stop responding are kept in the list and shown greyed-out rather than removed, so you can see what's gone offline.

Sextant also detects when the host machine moves between networks (Wi-Fi SSID change, cable plugged in, DHCP lease renewal) and resets automatically.

### Scan History

Optionally record every scan to a local SQLite database. The History screen shows a change log per network — new devices, removed devices, and changed attributes — diffed between consecutive snapshots. Retention is configurable (100 – 2000 snapshots). History can be cleared at any time.

### Export

Export the current device list as **CSV** or **JSON** via File → Export. Files are named `sextant-scan-YYYYMMDD-HHMMSS.{csv,json}`. JSON includes a structured per-device object with all fields; CSV is RFC-4180-compliant (fields with commas or quotes are properly escaped).

### Vendor Database

Sextant ships with a bundled snapshot of the IEEE OUI registry for offline MAC-to-vendor resolution. You can refresh the database manually from Settings or enable auto-refresh on a schedule (7, 14, 30, or 90 days) — it downloads the latest registry from the IEEE and rebuilds the lookup table in the background.

### Appearance

Supports Light, Dark, and System (follows OS setting) themes.

---

## Platform Notes

| Feature         | macOS | Linux                   | Windows |
| --------------- | ----- | ----------------------- | ------- |
| ICMP ping sweep | ✓     | ✓ (needs `cap_net_raw`) | ✓       |
| ARP table       | ✓     | ✓                       | ✓       |
| TCP port scan   | ✓     | ✓                       | ✓       |
| mDNS / Bonjour  | ✓     | ✓                       | ✓       |
| NetBIOS         | ✓     | ✓                       | ✓       |
| SSDP / UPnP     | ✓     | ✓                       | ✓       |
| Wake on LAN     | ✓     | ✓                       | ✓       |

**macOS:** The app sandbox is disabled because network scanning requires ARP-cache access and broad outbound connections. Sextant is not a Mac App Store candidate for this reason.

**Linux:** ICMP ping and ARP table access require elevated privileges. Either run as root or grant the binary the `cap_net_raw` capability:

```bash
sudo setcap cap_net_raw+ep build/linux/x64/release/bundle/sextant
```

**Windows:** ICMP and ARP use standard Windows system APIs available to non-admin users on modern Windows 10/11.

---

## Building from Source

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) 3.12 or later (tested with 3.44)
- **macOS:** Xcode 15+ with the macOS SDK
- **Linux:** `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`
- **Windows:** Visual Studio 2022 with the **Desktop development with C++** workload

```bash
# Clone and get dependencies
git clone <repo-url> NetScan
cd NetScan
flutter pub get
```

### Run in debug mode

```bash
flutter run -d macos    # macOS
flutter run -d linux    # Linux
flutter run -d windows  # Windows
```

### Build release binaries

Pass `--build-name` and `--build-number` so the bundle version metadata (`CFBundleShortVersionString` on macOS, etc.) matches what the app displays. The version is read from [lib/version.dart](lib/version.dart) — the single source of truth — so a version bump there propagates everywhere automatically.

**macOS / Linux (bash):**

```bash
BUILD_NAME=$(grep 'kAppVersionMajor' lib/version.dart | grep -oE '[0-9]+').$(grep 'kAppVersionMinor' lib/version.dart | grep -oE '[0-9]+')
BUILD_NUM=$(git rev-list --count HEAD)

flutter build macos --release \
  --build-name=$BUILD_NAME --build-number=$BUILD_NUM --dart-define=BUILD_NUMBER=$BUILD_NUM

flutter build linux --release \
  --build-name=$BUILD_NAME --build-number=$BUILD_NUM --dart-define=BUILD_NUMBER=$BUILD_NUM
```

**Windows (PowerShell):**

```powershell
$Major    = (Select-String 'kAppVersionMajor = (\d+)' lib/version.dart).Matches[0].Groups[1].Value
$Minor    = (Select-String 'kAppVersionMinor = (\d+)' lib/version.dart).Matches[0].Groups[1].Value
$BuildName = "$Major.$Minor"
$BuildNum  = git rev-list --count HEAD

flutter build windows --release `
  --build-name=$BuildName --build-number=$BuildNum --dart-define=BUILD_NUMBER=$BuildNum
```

---

## Installation Packages

### macOS — DMG

The release build produces `build/macos/Build/Products/Release/sextant.app`. Use [`create-dmg`](https://github.com/create-dmg/create-dmg) to produce a traditional drag-to-Applications installer — it places the app icon and an Applications folder alias side by side in a clean window:

```bash
brew install create-dmg

create-dmg \
  --volname "Sextant" \
  --window-pos 200 120 \
  --window-size 540 380 \
  --icon-size 128 \
  --icon "sextant.app" 140 190 \
  --app-drop-link 400 190 \
  "Sextant.dmg" \
  "build/macos/Build/Products/Release/sextant.app"
```

> **Important:** the last argument must point to the `.app` bundle itself, not its parent directory.

For distribution outside your own machine, sign and notarize the app with your Apple Developer certificate before packaging.

> **Troubleshooting:** if the installed app doesn't appear in Spotlight, or the DMG looks wrong, see [docs/macos-distribution.md](docs/macos-distribution.md) for a full diagnosis guide covering signing setup, `CFBundleDisplayName`, `LSApplicationCategoryType`, the expired WWDR intermediate CA, and rebuilding the Spotlight index.

### Linux — tar.gz / AppImage / deb

The release build produces a self-contained bundle at `build/linux/x64/release/bundle/`. It can be distributed as:

**Compressed archive:**

```bash
tar -czf sextant-linux-x64.tar.gz \
  -C build/linux/x64/release/ bundle
# Unpack and run: ./bundle/sextant
```

**AppImage** — using [`appimagetool`](https://github.com/AppImage/AppImageKit):

```bash
# Install appimagetool
wget -O appimagetool https://github.com/AppImage/AppImageKit/releases/latest/download/appimagetool-x86_64.AppImage
chmod +x appimagetool

# Lay out an AppDir
mkdir -p AppDir/usr/bin AppDir/usr/lib AppDir/usr/share/applications
cp -r build/linux/x64/release/bundle/* AppDir/usr/bin/

# Add a .desktop file and an icon, then package
ARCH=x86_64 ./appimagetool AppDir Sextant.AppImage
```

**Debian package** — using [`dpkg-deb`](https://www.debian.org/doc/manuals/debian-faq/pkg-basics.en.html):

```bash
# Create package structure
mkdir -p sextant_pkg/opt/sextant sextant_pkg/DEBIAN
cp -r build/linux/x64/release/bundle/. sextant_pkg/opt/sextant/

cat > sextant_pkg/DEBIAN/control <<'EOF'
Package: sextant
Version: 1.0
Architecture: amd64
Maintainer: IonJet
Description: Lightweight LAN scanner
 Discovers and monitors devices on your local network.
EOF

dpkg-deb --build sextant_pkg sextant_amd64.deb
```

### Windows — MSIX installer

Add the [`msix`](https://pub.dev/packages/msix) package and configure it in `pubspec.yaml`, then:

```bash
flutter pub add --dev msix
flutter build windows --release
flutter pub run msix:create
```

This produces an MSIX installer that can be sideloaded or submitted to the Microsoft Store. For sideloading, enable Developer Mode in Windows Settings or sign the package with a trusted code-signing certificate.

Alternatively, create a traditional setup wizard with [Inno Setup](https://jrsoftware.org/isinfo.php) by pointing its source directory at `build/windows/x64/runner/Release/`.

---

## Development

### Versioning

The displayed version has two parts:

- **`major.minor`** (e.g. `1.17`) — shown in the toolbar. Both components are constants in [lib/version.dart](lib/version.dart) and bumped manually at release time.
- **Build number** — shown in the About dialog as `Version 1.17 build 42`. This is the total git commit count (`git rev-list --count HEAD`), baked in by CI at build time via `--dart-define=BUILD_NUMBER=N`. Local debug runs display `dev` in place of the number.

**To cut a release:** increment `kAppVersionMinor` in [lib/version.dart](lib/version.dart) and merge to `main`. The CI workflow computes the build number automatically from the commit history.

**CI workflows** (`.github/workflows/`):

- `test.yml` — runs `flutter analyze` and `flutter test` on every push and pull request.
- `release.yml` — triggers on every merge to `main`; builds macOS, Linux, and Windows in parallel and uploads the resulting artifacts.

### Update the vendor (OUI) database

```bash
# Download the latest IEEE registry
curl -o /tmp/oui.csv https://standards-oui.ieee.org/oui/oui.csv

# Rebuild the bundled assets/oui.tsv
dart run tool/build_oui.dart
```

### Headless scan harness

Run a real two-phase scan from the command line without the Flutter UI:

```bash
dart run tool/live_scan.dart
```

### Code generation (Drift database)

```bash
dart run build_runner build
```
