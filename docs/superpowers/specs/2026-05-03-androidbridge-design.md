# AndroidBridge Design

## Goal

Build a clean, minimal macOS SwiftUI app for USB file transfer with Android phones using `adb`.

## Scope

The first version supports Android devices connected over USB with USB debugging enabled. It lists connected devices, browses a selected Android path, downloads files or folders to the Mac, and pushes Mac files to the currently open Android folder.

This version does not implement raw MTP, Wi-Fi pairing, drag-and-drop file management, rename, delete, folder creation, or background transfer queues.

## Architecture

The app lives in `AndroidBridge/` and is separate from the existing DisplaySync files. It is a SwiftPM package with two targets:

- `AndroidBridgeCore`: models, path helpers, ADB output parsing, and the ADB client.
- `AndroidBridge`: the SwiftUI macOS app.

Core logic is tested independently from the UI. The app shells out to `adb` through a small process runner, so users can install Android platform-tools with Homebrew or Android Studio and keep the app itself small.

## User Flow

On launch, the app scans for devices with `adb devices`. If no authorized device is available, it shows setup guidance: connect by USB, enable developer options, enable USB debugging, unlock the phone, and approve the trust prompt.

When a device is selected, the app opens `/sdcard/Download`. The user can move through folders, go up a folder, refresh, download the selected item to Downloads, or choose a Mac file to push into the current Android folder.

## Error Handling

ADB missing, unauthorized devices, offline devices, command failures, and malformed listings are surfaced as plain status messages in the window. The app keeps the last usable UI state where possible and lets the user refresh after fixing the phone or cable state.

## Testing

Unit tests cover:

- `adb devices` parsing for device, unauthorized, and offline states.
- Android file listing parsing for files and folders with spaces in names.
- Android path joining and parent path behavior.

Manual verification covers building, launching the app bundle, and confirming the process starts.
