# AndroidBridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a minimal macOS SwiftUI app that transfers files to and from Android devices over USB using `adb`.

**Architecture:** Create a clean SwiftPM app in `AndroidBridge/`. Put parsing, process execution, path handling, and ADB commands in `AndroidBridgeCore`, then build a small SwiftUI window app on top.

**Tech Stack:** SwiftPM, SwiftUI, AppKit file panels, Foundation `Process`, XCTest, `adb`.

---

### Task 1: SwiftPM Scaffold And Core Tests

**Files:**
- Create: `AndroidBridge/Package.swift`
- Create: `AndroidBridge/Tests/AndroidBridgeCoreTests/ADBOutputParserTests.swift`
- Create: `AndroidBridge/Tests/AndroidBridgeCoreTests/AndroidPathTests.swift`

- [ ] Write tests for device parsing, file listing parsing, and path helpers.
- [ ] Run `swift test` in `AndroidBridge/` and verify the tests fail because the core types do not exist.

### Task 2: Core Models And Parsers

**Files:**
- Create: `AndroidBridge/Sources/AndroidBridgeCore/AndroidDevice.swift`
- Create: `AndroidBridge/Sources/AndroidBridgeCore/AndroidFileItem.swift`
- Create: `AndroidBridge/Sources/AndroidBridgeCore/AndroidPath.swift`
- Create: `AndroidBridge/Sources/AndroidBridgeCore/ADBOutputParser.swift`

- [ ] Implement the minimal core types and parsers needed for the failing tests.
- [ ] Run `swift test` and verify the core tests pass.

### Task 3: ADB Client

**Files:**
- Create: `AndroidBridge/Sources/AndroidBridgeCore/ProcessRunning.swift`
- Create: `AndroidBridge/Sources/AndroidBridgeCore/ADBClient.swift`

- [ ] Add a process runner protocol and a Foundation-backed implementation.
- [ ] Add async ADB operations for listing devices, listing files, pulling, and pushing.
- [ ] Run `swift test` to guard parser behavior after adding the client.

### Task 4: SwiftUI App

**Files:**
- Create: `AndroidBridge/Sources/AndroidBridge/AndroidBridgeApp.swift`
- Create: `AndroidBridge/Sources/AndroidBridge/AppDelegate.swift`
- Create: `AndroidBridge/Sources/AndroidBridge/AndroidBridgeStore.swift`
- Create: `AndroidBridge/Sources/AndroidBridge/ContentView.swift`
- Create: `AndroidBridge/Sources/AndroidBridge/DeviceSidebarView.swift`
- Create: `AndroidBridge/Sources/AndroidBridge/FileBrowserView.swift`

- [ ] Build a regular macOS window app.
- [ ] Wire device refresh, folder navigation, download, and upload actions to the ADB client.
- [ ] Keep controls compact and desktop-native.

### Task 5: Build And Run Wiring

**Files:**
- Create: `AndroidBridge/script/build_and_run.sh`
- Create: `AndroidBridge/.codex/environments/environment.toml`

- [ ] Add a project-local build/run script that stages the SwiftPM GUI executable into `dist/AndroidBridge.app`.
- [ ] Add a Codex Run action pointing at the script.
- [ ] Run `swift test`.
- [ ] Run `./script/build_and_run.sh --verify`.
