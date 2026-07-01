# macOS Distribution Troubleshooting

Hard-won notes from getting a Flutter macOS app correctly distributed and indexed on macOS Sequoia. Covers DMG packaging, code signing, and Spotlight.

---

## DMG Packaging

### Use create-dmg, not hdiutil

`hdiutil create -srcfolder <dir>` packs the directory verbatim — no Applications alias, and any mispointed path dumps the project root into the image. Use `create-dmg` instead:

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

**The last argument must be the `.app` bundle itself**, not the directory that contains it. If you point it at the `Release/` folder, all build artefacts end up in the image.

The `--icon "sextant.app" X Y` flag places the app icon at pixel coordinates `(X, Y)` in the DMG window. Without it, `create-dmg` still runs but the layout is unpredictable.

---

## Code Signing

Proper code signing is required for Spotlight to index the app on macOS Sequoia. An ad-hoc signature (`-`) is not enough.

### Why signing matters for Spotlight

macOS Sequoia's `mds` (Spotlight indexer) silently skips apps that lack a real `TeamIdentifier` in their code signature. The app will install and run, but `mdfind` returns nothing and Spotlight never surfaces it.

### Diagnosing your signature

```bash
codesign -dv /Applications/YourApp.app 2>&1 | grep "Signature\|Team\|flags"
```

What each output means:

| Output | Meaning |
|---|---|
| `Signature=adhoc` | Ad-hoc signed — no Team ID, Spotlight ignores it |
| `TeamIdentifier=not set` | Same problem |
| `flags=0x2(adhoc)` | Ad-hoc |
| `flags=0x10000(runtime)` | Hardened Runtime — required alongside a real Team ID |
| `TeamIdentifier=XXXXXXXXXX` | Real certificate — Spotlight will index the app |

### Setting up a signing certificate (free, no paid membership required)

1. Open Xcode → **Settings** (⌘,) → **Accounts**
2. Add your Apple ID if not present
3. Select the account → click **Manage Certificates…**
4. Click **+** → **Apple Development**
5. Verify the certificate landed in the keychain:

```bash
security find-identity -v -p codesigning
```

If this prints `0 valid identities found` even though a certificate exists, the Apple WWDR intermediate CA in your keychain is expired. The old G1 CA expired February 2023. Download the current G3:

```bash
curl -O https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer
security import AppleWWDRCAG3.cer -k ~/Library/Keychains/login.keychain-db
```

Re-run `security find-identity` — the Apple Development identity should now appear as valid.

### Configuring the Xcode project to use the certificate

Even with a valid certificate in the keychain, `flutter build macos` can still produce an ad-hoc binary if the project-level build settings have `CODE_SIGN_IDENTITY = "-"` hardcoded. This overrides the target's `CODE_SIGN_STYLE = Automatic`.

Fix: add explicit overrides to the Runner target's **Release** configuration in `macos/Runner.xcodeproj/project.pbxproj`, inside the block that has `CODE_SIGN_ENTITLEMENTS = Runner/Release.entitlements`:

```
CODE_SIGN_IDENTITY = "Apple Development";
ENABLE_HARDENED_RUNTIME = YES;
```

After this change, `flutter build macos --release` picks up the real certificate automatically.

Verify after building:

```bash
codesign -dv build/macos/Build/Products/Release/sextant.app 2>&1 | grep "Signature\|Team\|flags"
```

Expected output:
```
flags=0x10000(runtime)
Signature size=4790        ← non-zero, not "adhoc"
TeamIdentifier=XXXXXXXXXX  ← your Team ID
```

---

## Spotlight Not Indexing the App

Work through these in order. Each step builds on the previous.

### 1. Verify the Info.plist has the required keys

Two keys are required for Spotlight to surface the app in the Applications category on macOS Sequoia:

```bash
plutil -p /Applications/YourApp.app/Contents/Info.plist | grep -E "CFBundleDisplay|LSApplication"
```

Required:

| Key | Value |
|---|---|
| `CFBundleDisplayName` | `"Sextant"` (the human-readable name Spotlight indexes) |
| `LSApplicationCategoryType` | `"public.app-category.utilities"` (or another valid category) |

Without `CFBundleDisplayName`, Spotlight falls back to `CFBundleName`. Without `LSApplicationCategoryType`, the app is excluded from the Applications result group entirely on Sequoia.

Add both to `macos/Runner/Info.plist`:

```xml
<key>CFBundleDisplayName</key>
<string>Sextant</string>
<key>LSApplicationCategoryType</key>
<string>public.app-category.utilities</string>
```

### 2. Check for quarantine

```bash
xattr /Applications/YourApp.app
```

If `com.apple.quarantine` appears:

```bash
xattr -r -d com.apple.quarantine /Applications/YourApp.app
```

### 3. Check whether Spotlight has indexed the app at all

```bash
mdfind "kMDItemCFBundleIdentifier == 'net.ionjet.sextant'"
```

If this returns nothing, the indexer never processed the bundle. The importer may still be able to read it in test mode:

```bash
mdimport -t -d2 /Applications/YourApp.app 2>&1 | head -20
```

If test mode works but live import doesn't, the `mds` daemon is rejecting the entry (see below).

### 4. Verify the code signature has a real Team ID

See the [Code Signing](#code-signing) section above. An ad-hoc signature causes `mds` on Sequoia to silently skip the app regardless of all other metadata.

### 5. Force immediate indexing

```bash
mdimport /Applications/YourApp.app
sleep 5
mdfind "kMDItemCFBundleIdentifier == 'net.ionjet.sextant'"
```

### 6. Wipe and rebuild the Spotlight index (nuclear option)

If all the above are correct but `mdfind` still returns nothing, `mds` has a stale or corrupted state for this bundle — typically from earlier failed import attempts with an incomplete or ad-hoc-signed version of the app. The only reliable fix is a full index rebuild:

```bash
sudo mdutil -E /
```

This erases and rebuilds the index for the boot volume. A progress indicator appears in the Spotlight menu bar icon. Wait 5–10 minutes, then search again. This resolved the issue after all other steps had been applied.

### 7. SDK version mismatch (Xcode beta)

If you're building with an Xcode beta that targets a future macOS SDK version (e.g. Xcode 26 on macOS 15 Sequoia), the app's Info.plist is stamped with `DTPlatformVersion = "26.2"` (or similar). The `mds` daemon on the older OS doesn't recognise the future platform version and silently skips the bundle.

Check:

```bash
plutil -p /Applications/YourApp.app/Contents/Info.plist | grep DTSDKName
```

If the SDK version is ahead of the running OS, `sudo mdutil -E /` is required after each install to force a clean reindex — or switch to a stable Xcode release for distribution builds:

```bash
xcode-select -p                          # see which Xcode is active
sudo xcode-select -s /Applications/Xcode.app   # switch to stable Xcode
```

---

## Summary of Root Causes Found

| Symptom | Root cause | Fix |
|---|---|---|
| Cluttered DMG with project files | Wrong source path in `hdiutil` / missing `--icon` in `create-dmg` | Use `create-dmg` with explicit `--icon` and point at the `.app` bundle |
| Spotlight doesn't find the app | Missing `CFBundleDisplayName` | Add key to Info.plist |
| Spotlight doesn't find the app | Missing `LSApplicationCategoryType` | Add `public.app-category.utilities` to Info.plist |
| Spotlight doesn't find the app | Ad-hoc signature, no Team ID | Set up Apple Development certificate |
| `security find-identity` shows 0 valid | Expired Apple WWDR G1 intermediate CA | Install WWDR G3 from apple.com/certificateauthority |
| Build still produces ad-hoc despite valid cert | `CODE_SIGN_IDENTITY = "-"` at project level overrides target's Automatic signing | Add `CODE_SIGN_IDENTITY = "Apple Development"` + `ENABLE_HARDENED_RUNTIME = YES` to Runner Release target |
| All metadata/signing correct, still not indexed | `mds` has stale state from earlier failed imports | `sudo mdutil -E /` |
| `mdutil -E` required after every install | Xcode beta SDK version ahead of running macOS | Switch to stable Xcode for distribution builds |
