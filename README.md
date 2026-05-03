# AndroidBridge

AndroidBridge is a small free macOS app for transferring files between a Mac and an Android phone over USB using ADB.

It is intentionally simple: connect a phone, browse `/sdcard/Download`, download files to the Mac, and upload files back to the current Android folder.

## Features

- Lists Android devices connected over USB
- Browses Android folders through ADB
- Downloads files and folders to the Mac Downloads folder
- Uploads Mac files to the current Android folder
- Shows download progress and estimated time for files
- Includes an in-app setup guide for Android Platform-Tools and USB debugging
- Optional donation sheet with copyable wallet address

## Requirements

- macOS 14 or later
- Android SDK Platform-Tools, including `adb`
- An Android phone with USB debugging enabled
- A USB cable that supports data transfer

## Install ADB

The easiest install path on macOS is Homebrew:

```bash
brew install android-platform-tools
```

You can also download Android SDK Platform-Tools directly from Google:

https://developer.android.com/tools/releases/platform-tools

Verify that ADB sees your phone:

```bash
adb devices
```

If the device says `unauthorized`, unlock the phone and approve the USB debugging RSA prompt.

## Run From Source

```bash
swift run AndroidBridgeCoreTests
swift build
./script/build_and_run.sh
```

To build, package, and verify the app bundle:

```bash
./script/build_and_run.sh --verify
```

The packaged app is created at:

```text
dist/AndroidBridge.app
```

## Install Locally

After building:

```bash
ditto dist/AndroidBridge.app /Applications/AndroidBridge.app
```

Then open AndroidBridge from Finder, Spotlight, or Launchpad.

## Package A Release DMG

```bash
./script/package_dmg.sh
```

The script creates `dist/AndroidBridge.dmg` and prints its SHA256 checksum for Homebrew Cask.

This free release is ad-hoc signed but not notarized. If macOS blocks the first launch, right-click `AndroidBridge.app` and choose Open. If macOS says the app is damaged after downloading from a browser, remove the quarantine attribute:

```bash
xattr -dr com.apple.quarantine /Applications/AndroidBridge.app
```

## Donation

AndroidBridge is free. Donations are optional.

- Asset: USDT
- Network: TRC20
- Address: `TLXKfMgVzX1QYxtU9p5pidoNW2HiKjG6He`

Only send USDT on the TRC20 network to this address.

## License

MIT License. See [LICENSE](LICENSE).
