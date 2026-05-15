# Wireless Transfer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Wireless Transfer tab with browser-based app-free transfer and advanced ADB Wireless full-access transfer.

**Architecture:** Keep the existing USB ADB browser intact. Add focused core types for browser sessions, shared downloads, upload destinations, local HTTP serving, QR generation, and ADB Wireless pair/connect/discovery. Add SwiftUI views that switch between USB Transfer and Wireless Transfer, with Browser Transfer as the default wireless mode.

**Tech Stack:** SwiftPM, SwiftUI, AppKit panels, Foundation, Network.framework `NWListener`/`NWBrowser`, CoreImage QR generation, `/usr/bin/ditto` ZIP creation, existing `ProcessRunning`, existing `adb`.

---

## Scope Check

The spec contains two related subsystems: Browser Transfer and ADB Wireless. Keep one implementation plan because both live under the same Wireless Transfer tab and share app-level state, but implement in order:

1. Browser Transfer vertical slice.
2. ADB Wireless pair/connect/discovery.
3. Final integration and docs.

## File Structure

Create core browser transfer files:

- `Sources/AndroidBridgeCore/WirelessTransferToken.swift`: generates and validates random URL tokens and numeric PINs.
- `Sources/AndroidBridgeCore/WirelessTransferSession.swift`: owns session identity, receive folder, shared downloads, and upload naming.
- `Sources/AndroidBridgeCore/SharedDownloadItem.swift`: models Mac files/folders exposed to the phone browser.
- `Sources/AndroidBridgeCore/WirelessUploadDestination.swift`: resolves safe auto-renamed upload paths inside the receive folder.
- `Sources/AndroidBridgeCore/WirelessHTMLRenderer.swift`: renders the phone browser page as static HTML.
- `Sources/AndroidBridgeCore/WirelessHTTPServer.swift`: lightweight local HTTP server using `Network`.
- `Sources/AndroidBridgeCore/WirelessZipArchive.swift`: creates folder ZIP archives with `/usr/bin/ditto`.
- `Sources/AndroidBridgeCore/ADBWirelessClient.swift`: wraps `adb pair`, `adb connect`, and `adb disconnect`.
- `Sources/AndroidBridgeCore/ADBWirelessDiscovery.swift`: discovers `_adb-tls-pairing._tcp` and `_adb-tls-connect._tcp` services using `Network`.

Create app files:

- `Sources/AndroidBridge/TransferMode.swift`: USB/Wireless and browser/ADB wireless mode enums.
- `Sources/AndroidBridge/WirelessTransferStore.swift`: SwiftUI-facing state and actions for browser and ADB wireless flows.
- `Sources/AndroidBridge/WirelessTransferView.swift`: Wireless tab shell.
- `Sources/AndroidBridge/BrowserTransferView.swift`: Browser Transfer UI.
- `Sources/AndroidBridge/ADBWirelessView.swift`: ADB Wireless UI.
- `Sources/AndroidBridge/QRCodeView.swift`: CoreImage QR rendering.

Modify existing files:

- `Sources/AndroidBridge/ContentView.swift`: add top-level USB/Wireless tab selection.
- `Sources/AndroidBridge/AndroidBridgeStore.swift`: add ADB wireless helper calls only where needed; avoid browser server state here.
- `Sources/AndroidBridgeCore/ADBClient.swift`: expose pair/connect helpers through `ADBWirelessClient`, not by expanding file browsing methods.
- `Sources/AndroidBridgeCoreTests/main.swift`: append focused tests for new core units.
- `README.md`: document Browser Transfer and ADB Wireless.

---

### Task 1: Add Transfer Mode Shell

**Files:**
- Create: `Sources/AndroidBridge/TransferMode.swift`
- Modify: `Sources/AndroidBridge/ContentView.swift`

- [ ] **Step 1: Add transfer mode enums**

Create `Sources/AndroidBridge/TransferMode.swift`:

```swift
import Foundation

enum TransferMode: String, CaseIterable, Identifiable {
    case usb
    case wireless

    var id: String { rawValue }

    var title: String {
        switch self {
        case .usb:
            "USB Transfer"
        case .wireless:
            "Wireless Transfer"
        }
    }
}

enum WirelessTransferMode: String, CaseIterable, Identifiable {
    case browser
    case adbWireless

    var id: String { rawValue }

    var title: String {
        switch self {
        case .browser:
            "Browser Transfer"
        case .adbWireless:
            "ADB Wireless"
        }
    }
}
```

- [ ] **Step 2: Add the initial Wireless view**

Create `Sources/AndroidBridge/WirelessTransferView.swift`:

```swift
import SwiftUI

struct WirelessTransferView: View {
    var body: some View {
        ContentUnavailableView(
            "Wireless Transfer",
            systemImage: "wifi",
            description: Text("Browser Transfer and ADB Wireless will appear here.")
        )
    }
}
```

- [ ] **Step 3: Wrap existing USB UI in a top-level tab selector**

Modify `Sources/AndroidBridge/ContentView.swift` to keep the current `NavigationSplitView` for USB and add a wireless tab:

```swift
import SwiftUI

struct ContentView: View {
    @Bindable var store: AndroidBridgeStore
    @State private var transferMode: TransferMode = .usb

    var body: some View {
        VStack(spacing: 0) {
            Picker("Transfer Mode", selection: $transferMode) {
                ForEach(TransferMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top], 14)
            .padding(.bottom, 10)

            Divider()

            Group {
                switch transferMode {
                case .usb:
                    usbTransferView
                case .wireless:
                    WirelessTransferView()
                }
            }
        }
        .sheet(isPresented: $store.isShowingSetupGuide) {
            SetupGuideView()
        }
        .sheet(isPresented: $store.isShowingDonation) {
            DonationView()
        }
    }

    private var usbTransferView: some View {
        NavigationSplitView {
            DeviceSidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            FileBrowserView(store: store)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await store.refreshDevices() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh devices")
                .disabled(store.isBusy)

                Button {
                    Task { await store.uploadFile() }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .help("Upload files or folders to Android")
                .disabled(store.isBusy || store.selectedDevice == nil)

                Button {
                    Task { await store.downloadSelected() }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("Choose where to save the selected Android items")
                .disabled(store.isBusy || store.selectedItems.isEmpty)

                Button {
                    store.cancelCurrentOperation()
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .help("Cancel current operation")
                .disabled(!store.isBusy)

                Button {
                    store.isShowingSetupGuide = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .help("Open setup guide")

                Button {
                    store.isShowingDonation = true
                } label: {
                    Image(systemName: "heart")
                }
                .help("Donate")
            }
        }
    }
}
```

- [ ] **Step 4: Build**

Run:

```bash
swift build
```

Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/AndroidBridge/TransferMode.swift Sources/AndroidBridge/WirelessTransferView.swift Sources/AndroidBridge/ContentView.swift
git commit -m "Add wireless transfer tab shell"
```

---

### Task 2: Add Browser Session Core

**Files:**
- Create: `Sources/AndroidBridgeCore/WirelessTransferToken.swift`
- Create: `Sources/AndroidBridgeCore/SharedDownloadItem.swift`
- Create: `Sources/AndroidBridgeCore/WirelessUploadDestination.swift`
- Create: `Sources/AndroidBridgeCore/WirelessTransferSession.swift`
- Modify: `Sources/AndroidBridgeCoreTests/main.swift`

- [ ] **Step 1: Add failing tests**

Append these tests before the runner calls in `Sources/AndroidBridgeCoreTests/main.swift`:

```swift
func wirelessTokenCreatesUsableURLTokenAndPIN() {
    let token = WirelessTransferToken(urlToken: "abcdef1234567890", pin: "123456")

    check(expectEqual(token.urlToken, "abcdef1234567890", "wireless token keeps url token"))
    check(expectEqual(token.pin, "123456", "wireless token keeps pin"))
    check(expectEqual(WirelessTransferToken.isValidPIN("123456"), true, "six digit pin is valid"))
    check(expectEqual(WirelessTransferToken.isValidPIN("12345"), false, "short pin is invalid"))
    check(expectEqual(WirelessTransferToken.isValidPIN("abcdef"), false, "non numeric pin is invalid"))
}

func sharedDownloadItemUsesFriendlyMetadata() {
    let fileURL = URL(fileURLWithPath: "/Users/me/Desktop/photo.jpg")
    let folderURL = URL(fileURLWithPath: "/Users/me/Desktop/Camera", isDirectory: true)

    let file = SharedDownloadItem(url: fileURL, kind: .file, byteCount: 1024)
    let folder = SharedDownloadItem(url: folderURL, kind: .folder, byteCount: nil)

    check(expectEqual(file.name, "photo.jpg", "file shared item name"))
    check(expectEqual(file.downloadName, "photo.jpg", "file download name"))
    check(expectEqual(folder.name, "Camera", "folder shared item name"))
    check(expectEqual(folder.downloadName, "Camera.zip", "folder download name"))
}

func uploadDestinationAutoRenamesCollisionsInsideReceiveFolder() {
    let receiveFolder = URL(fileURLWithPath: "/tmp/AndroidBridgeReceive", isDirectory: true)
    let existingNames: Set<String> = ["photo.jpg", "photo 2.jpg"]

    let destination = WirelessUploadDestination.destination(
        originalFilename: "photo.jpg",
        receiveFolder: receiveFolder,
        existingFilenames: existingNames
    )

    check(expectEqual(destination.lastPathComponent, "photo 3.jpg", "upload collision is auto-renamed"))
    check(expectEqual(destination.deletingLastPathComponent().path, receiveFolder.path, "upload stays in receive folder"))
}

func wirelessSessionAddsAndClearsSharedItems() {
    let session = WirelessTransferSession(
        token: WirelessTransferToken(urlToken: "abcdef1234567890", pin: "123456"),
        receiveFolder: URL(fileURLWithPath: "/tmp/AndroidBridgeReceive", isDirectory: true)
    )
    let fileURL = URL(fileURLWithPath: "/Users/me/Desktop/photo.jpg")

    session.addSharedItems([SharedDownloadItem(url: fileURL, kind: .file, byteCount: 1024)])
    check(expectEqual(session.sharedItems.count, 1, "session adds shared item"))

    session.clearSharedItems()
    check(expectEqual(session.sharedItems.isEmpty, true, "session clears shared items"))
}
```

Add runner calls near the bottom:

```swift
wirelessTokenCreatesUsableURLTokenAndPIN()
sharedDownloadItemUsesFriendlyMetadata()
uploadDestinationAutoRenamesCollisionsInsideReceiveFolder()
wirelessSessionAddsAndClearsSharedItems()
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
swift run AndroidBridgeCoreTests
```

Expected: FAIL with missing `WirelessTransferToken`, `SharedDownloadItem`, `WirelessUploadDestination`, and `WirelessTransferSession`.

- [ ] **Step 3: Implement token**

Create `Sources/AndroidBridgeCore/WirelessTransferToken.swift`:

```swift
import Foundation

public struct WirelessTransferToken: Equatable, Sendable {
    public let urlToken: String
    public let pin: String

    public init(urlToken: String, pin: String) {
        self.urlToken = urlToken
        self.pin = pin
    }

    public static func generate() -> WirelessTransferToken {
        let tokenBytes = (0..<24).map { _ in UInt8.random(in: 0...255) }
        let urlToken = tokenBytes.map { String(format: "%02x", $0) }.joined()
        let pin = String(format: "%06d", Int.random(in: 0...999_999))
        return WirelessTransferToken(urlToken: urlToken, pin: pin)
    }

    public static func isValidPIN(_ value: String) -> Bool {
        value.count == 6 && value.allSatisfy(\.isNumber)
    }
}
```

- [ ] **Step 4: Implement shared item**

Create `Sources/AndroidBridgeCore/SharedDownloadItem.swift`:

```swift
import Foundation

public struct SharedDownloadItem: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case file
        case folder
    }

    public let id: UUID
    public let url: URL
    public let kind: Kind
    public let byteCount: Int64?

    public init(id: UUID = UUID(), url: URL, kind: Kind, byteCount: Int64?) {
        self.id = id
        self.url = url
        self.kind = kind
        self.byteCount = byteCount
    }

    public var name: String {
        url.lastPathComponent
    }

    public var downloadName: String {
        switch kind {
        case .file:
            name
        case .folder:
            "\(name).zip"
        }
    }
}
```

- [ ] **Step 5: Implement upload destination**

Create `Sources/AndroidBridgeCore/WirelessUploadDestination.swift`:

```swift
import Foundation

public enum WirelessUploadDestination {
    public static func destination(
        originalFilename: String,
        receiveFolder: URL,
        existingFilenames: Set<String>
    ) -> URL {
        let sanitized = sanitizedFilename(originalFilename)
        var candidate = sanitized
        var index = 2

        let nsName = sanitized as NSString
        let base = nsName.deletingPathExtension
        let ext = nsName.pathExtension

        while existingFilenames.contains(candidate) {
            candidate = ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)"
            index += 1
        }

        return receiveFolder.appendingPathComponent(candidate)
    }

    public static func sanitizedFilename(_ filename: String) -> String {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "upload" : trimmed
        return fallback
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }
}
```

- [ ] **Step 6: Implement session**

Create `Sources/AndroidBridgeCore/WirelessTransferSession.swift`:

```swift
import Foundation

public final class WirelessTransferSession: @unchecked Sendable {
    public let token: WirelessTransferToken
    public let receiveFolder: URL

    private let lock = NSLock()
    private var items: [SharedDownloadItem] = []

    public init(token: WirelessTransferToken = .generate(), receiveFolder: URL) {
        self.token = token
        self.receiveFolder = receiveFolder
    }

    public var sharedItems: [SharedDownloadItem] {
        lock.lock()
        defer { lock.unlock() }
        return items
    }

    public func addSharedItems(_ newItems: [SharedDownloadItem]) {
        lock.lock()
        items.append(contentsOf: newItems)
        lock.unlock()
    }

    public func removeSharedItem(id: SharedDownloadItem.ID) {
        lock.lock()
        items.removeAll { $0.id == id }
        lock.unlock()
    }

    public func clearSharedItems() {
        lock.lock()
        items.removeAll()
        lock.unlock()
    }

    public func sharedItem(id: SharedDownloadItem.ID) -> SharedDownloadItem? {
        lock.lock()
        defer { lock.unlock() }
        return items.first { $0.id == id }
    }
}
```

- [ ] **Step 7: Run tests**

Run:

```bash
swift run AndroidBridgeCoreTests
```

Expected: `AndroidBridgeCoreTests passed`.

- [ ] **Step 8: Commit**

```bash
git add Sources/AndroidBridgeCore/WirelessTransferToken.swift Sources/AndroidBridgeCore/SharedDownloadItem.swift Sources/AndroidBridgeCore/WirelessUploadDestination.swift Sources/AndroidBridgeCore/WirelessTransferSession.swift Sources/AndroidBridgeCoreTests/main.swift
git commit -m "Add wireless browser session core"
```

---

### Task 3: Render Phone Browser Page

**Files:**
- Create: `Sources/AndroidBridgeCore/WirelessHTMLRenderer.swift`
- Modify: `Sources/AndroidBridgeCoreTests/main.swift`

- [ ] **Step 1: Add failing HTML tests**

Append:

```swift
func wirelessHTMLRendererEscapesNamesAndShowsActions() {
    let item = SharedDownloadItem(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        url: URL(fileURLWithPath: "/Users/me/Desktop/a&b.jpg"),
        kind: .file,
        byteCount: 42
    )

    let html = WirelessHTMLRenderer.pageHTML(sharedItems: [item], authenticated: true)

    check(expectEqual(html.contains("Send to Mac"), true, "html includes send section"))
    check(expectEqual(html.contains("Get from Mac"), true, "html includes get section"))
    check(expectEqual(html.contains("a&amp;b.jpg"), true, "html escapes item name"))
    check(expectEqual(html.contains("/download/11111111-1111-1111-1111-111111111111"), true, "html links shared item"))
}
```

Add call:

```swift
wirelessHTMLRendererEscapesNamesAndShowsActions()
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
swift run AndroidBridgeCoreTests
```

Expected: FAIL because `WirelessHTMLRenderer` does not exist.

- [ ] **Step 3: Implement renderer**

Create `Sources/AndroidBridgeCore/WirelessHTMLRenderer.swift`:

```swift
import Foundation

public enum WirelessHTMLRenderer {
    public static func pageHTML(sharedItems: [SharedDownloadItem], authenticated: Bool) -> String {
        let list = sharedItems.map { item in
            """
            <li>
              <span>\(escape(item.name))</span>
              <a href="/download/\(item.id.uuidString)">Download</a>
            </li>
            """
        }.joined(separator: "\n")

        let authBlock = authenticated ? "" : """
        <section>
          <h2>Enter PIN</h2>
          <form method="POST" action="/pin">
            <input name="pin" inputmode="numeric" autocomplete="one-time-code" maxlength="6">
            <button type="submit">Unlock</button>
          </form>
        </section>
        """

        let transferBlock = authenticated ? """
        <section>
          <h2>Send to Mac</h2>
          <form method="POST" action="/upload" enctype="multipart/form-data">
            <input type="file" name="files" multiple>
            <button type="submit">Send</button>
          </form>
        </section>
        <section>
          <h2>Get from Mac</h2>
          <ul>
            \(list.isEmpty ? "<li>No files shared from Mac.</li>" : list)
          </ul>
        </section>
        """ : ""

        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>AndroidBridge</title>
          <style>
            body { font-family: system-ui, sans-serif; margin: 24px; color: #171717; }
            h1 { font-size: 24px; }
            section { border-top: 1px solid #ddd; padding: 18px 0; }
            button, input { font: inherit; }
            li { margin: 10px 0; }
          </style>
        </head>
        <body>
          <h1>AndroidBridge</h1>
          \(authBlock)
          \(transferBlock)
        </body>
        </html>
        """
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
```

- [ ] **Step 4: Run tests**

Run:

```bash
swift run AndroidBridgeCoreTests
```

Expected: `AndroidBridgeCoreTests passed`.

- [ ] **Step 5: Commit**

```bash
git add Sources/AndroidBridgeCore/WirelessHTMLRenderer.swift Sources/AndroidBridgeCoreTests/main.swift
git commit -m "Add wireless browser page renderer"
```

---

### Task 4: Add Browser Transfer UI State

**Files:**
- Create: `Sources/AndroidBridge/WirelessTransferStore.swift`
- Create: `Sources/AndroidBridge/BrowserTransferView.swift`
- Create: `Sources/AndroidBridge/QRCodeView.swift`
- Modify: `Sources/AndroidBridge/WirelessTransferView.swift`

- [ ] **Step 1: Add store skeleton**

Create `Sources/AndroidBridge/WirelessTransferStore.swift`:

```swift
import AndroidBridgeCore
import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class WirelessTransferStore {
    var selectedMode: WirelessTransferMode = .browser
    var browserSession: WirelessTransferSession?
    var browserURL: URL?
    var browserStatusMessage = "Start a Browser Transfer session to send files over Wi-Fi."
    var sharedItems: [SharedDownloadItem] = []
    var adbWirelessStatusMessage = "Scan for wireless debugging devices or connect manually."

    var isBrowserSessionRunning: Bool {
        browserSession != nil
    }

    func startBrowserSession() {
        guard let receiveFolder = pickReceiveFolder() else {
            return
        }

        let session = WirelessTransferSession(receiveFolder: receiveFolder)
        browserSession = session
        browserURL = URL(string: "http://localhost:8123/\(session.token.urlToken)")
        sharedItems = []
        browserStatusMessage = "Browser Transfer session is ready."
    }

    func stopBrowserSession() {
        browserSession = nil
        browserURL = nil
        sharedItems = []
        browserStatusMessage = "Browser Transfer session stopped."
    }

    func addSharedFiles() {
        guard let session = browserSession else {
            browserStatusMessage = "Start a Browser Transfer session first."
            return
        }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Add Files"

        guard panel.runModal() == .OK else {
            return
        }

        let items = panel.urls.map { url in
            SharedDownloadItem(url: url, kind: .file, byteCount: fileSize(url))
        }
        session.addSharedItems(items)
        sharedItems = session.sharedItems
    }

    func addSharedFolder() {
        guard let session = browserSession else {
            browserStatusMessage = "Start a Browser Transfer session first."
            return
        }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Add Folders"

        guard panel.runModal() == .OK else {
            return
        }

        let items = panel.urls.map { url in
            SharedDownloadItem(url: url, kind: .folder, byteCount: nil)
        }
        session.addSharedItems(items)
        sharedItems = session.sharedItems
    }

    func removeSharedItems(ids: Set<SharedDownloadItem.ID>) {
        guard let session = browserSession else {
            return
        }

        ids.forEach { session.removeSharedItem(id: $0) }
        sharedItems = session.sharedItems
    }

    func clearSharedItems() {
        browserSession?.clearSharedItems()
        sharedItems = []
    }

    private func pickReceiveFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Choose where AndroidBridge should save files sent from your phone."
        panel.prompt = "Use Folder"
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func fileSize(_ url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else {
            return nil
        }
        return size.int64Value
    }
}
```

- [ ] **Step 2: Add QR view**

Create `Sources/AndroidBridge/QRCodeView.swift`:

```swift
import CoreImage.CIFilterBuiltins
import SwiftUI

struct QRCodeView: View {
    let text: String

    var body: some View {
        if let image = qrImage(for: text) {
            Image(nsImage: image)
                .interpolation(.none)
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .frame(width: 180, height: 180)
                .accessibilityLabel("Wireless transfer QR code")
        } else {
            ContentUnavailableView("QR unavailable", systemImage: "qrcode")
                .frame(width: 180, height: 180)
        }
    }

    private func qrImage(for text: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else {
            return nil
        }

        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let rep = NSCIImageRep(ciImage: scaled)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }
}
```

- [ ] **Step 3: Add Browser Transfer view**

Create `Sources/AndroidBridge/BrowserTransferView.swift`:

```swift
import AndroidBridgeCore
import SwiftUI

struct BrowserTransferView: View {
    @Bindable var store: WirelessTransferStore
    @State private var selectedSharedItemIDs: Set<SharedDownloadItem.ID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let url = store.browserURL, let session = store.browserSession {
                HStack(alignment: .top, spacing: 18) {
                    QRCodeView(text: url.absoluteString)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(url.absoluteString)
                            .textSelection(.enabled)
                            .lineLimit(2)
                        Text("PIN: \(session.token.pin)")
                            .font(.title3.monospacedDigit())
                        Text("Receive Folder: \(session.receiveFolder.path)")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                sharedItemsTable
            } else {
                ContentUnavailableView(
                    "Browser Transfer",
                    systemImage: "qrcode",
                    description: Text("Start a local session, scan the QR code with your Android phone, then send or receive files in the browser.")
                )
            }

            Spacer()
            Text(store.browserStatusMessage)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(18)
    }

    private var header: some View {
        HStack {
            Text("Browser Transfer")
                .font(.title2.bold())

            Spacer()

            Button("Start Session") {
                store.startBrowserSession()
            }
            .disabled(store.isBrowserSessionRunning)

            Button("Stop") {
                store.stopBrowserSession()
            }
            .disabled(!store.isBrowserSessionRunning)
        }
    }

    private var sharedItemsTable: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button("Add Files") {
                    store.addSharedFiles()
                }
                Button("Add Folder") {
                    store.addSharedFolder()
                }
                Button("Remove") {
                    store.removeSharedItems(ids: selectedSharedItemIDs)
                    selectedSharedItemIDs = []
                }
                .disabled(selectedSharedItemIDs.isEmpty)
                Button("Clear") {
                    store.clearSharedItems()
                    selectedSharedItemIDs = []
                }
                .disabled(store.sharedItems.isEmpty)
            }

            Table(store.sharedItems, selection: $selectedSharedItemIDs) {
                TableColumn("Name") { item in
                    Text(item.name)
                }
                TableColumn("Kind") { item in
                    Text(item.kind == .file ? "File" : "Folder ZIP")
                        .foregroundStyle(.secondary)
                }
                TableColumn("Size") { item in
                    Text(item.byteCount.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "--")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 180)
        }
    }
}
```

- [ ] **Step 4: Wire wireless mode picker**

Replace `Sources/AndroidBridge/WirelessTransferView.swift`:

```swift
import SwiftUI

struct WirelessTransferView: View {
    @State private var store = WirelessTransferStore()

    var body: some View {
        VStack(spacing: 0) {
            Picker("Wireless Mode", selection: $store.selectedMode) {
                ForEach(WirelessTransferMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(14)

            Divider()

            switch store.selectedMode {
            case .browser:
                BrowserTransferView(store: store)
            case .adbWireless:
                ContentUnavailableView(
                    "ADB Wireless",
                    systemImage: "antenna.radiowaves.left.and.right",
                    description: Text("Wireless debugging pairing will appear here.")
                )
            }
        }
    }
}
```

- [ ] **Step 5: Build**

Run:

```bash
swift build
```

Expected: build succeeds.

- [ ] **Step 6: Commit**

```bash
git add Sources/AndroidBridge/WirelessTransferStore.swift Sources/AndroidBridge/BrowserTransferView.swift Sources/AndroidBridge/QRCodeView.swift Sources/AndroidBridge/WirelessTransferView.swift
git commit -m "Add browser transfer interface"
```

---

### Task 5: Add Local Browser HTTP Server

**Files:**
- Create: `Sources/AndroidBridgeCore/WirelessHTTPServer.swift`
- Modify: `Sources/AndroidBridge/WirelessTransferStore.swift`

- [ ] **Step 1: Implement server skeleton**

Create `Sources/AndroidBridgeCore/WirelessHTTPServer.swift`:

```swift
import Foundation
import Network

public final class WirelessHTTPServer: @unchecked Sendable {
    public struct Configuration: Sendable {
        public let port: UInt16

        public init(port: UInt16 = 8123) {
            self.port = port
        }
    }

    private let configuration: Configuration
    private let queue = DispatchQueue(label: "AndroidBridge.WirelessHTTPServer")
    private var listener: NWListener?
    private var session: WirelessTransferSession?

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    public func start(session: WirelessTransferSession) throws -> URL {
        self.session = session
        let parameters = NWParameters.tcp
        let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: configuration.port)!)
        self.listener = listener

        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.start(queue: queue)

        return URL(string: "http://\(Self.bestLocalAddress()):\(configuration.port)/\(session.token.urlToken)")!
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        session = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self] data, _, _, _ in
            guard let self, let data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            let response = self.response(for: request)
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private func response(for request: String) -> Data {
        guard let session else {
            return httpResponse(status: "503 Service Unavailable", body: "No active session")
        }

        let firstLine = request.components(separatedBy: "\r\n").first ?? ""
        let parts = firstLine.split(separator: " ")
        let path = parts.count >= 2 ? String(parts[1]) : "/"

        guard path.contains(session.token.urlToken) || path == "/" else {
            return httpResponse(status: "404 Not Found", body: "Session not found")
        }

        let html = WirelessHTMLRenderer.pageHTML(sharedItems: session.sharedItems, authenticated: true)
        return httpResponse(status: "200 OK", body: html, contentType: "text/html; charset=utf-8")
    }

    private func httpResponse(status: String, body: String, contentType: String = "text/plain; charset=utf-8") -> Data {
        let bodyData = Data(body.utf8)
        let header = """
        HTTP/1.1 \(status)\r
        Content-Type: \(contentType)\r
        Content-Length: \(bodyData.count)\r
        Connection: close\r
        \r

        """
        return Data(header.utf8) + bodyData
    }

    private static func bestLocalAddress() -> String {
        var address = "127.0.0.1"
        var ifaddrPointer: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddrPointer) == 0, let firstAddress = ifaddrPointer else {
            return address
        }
        defer { freeifaddrs(ifaddrPointer) }

        for pointer in sequence(first: firstAddress, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            let family = interface.ifa_addr.pointee.sa_family
            guard family == UInt8(AF_INET) else {
                continue
            }

            let name = String(cString: interface.ifa_name)
            guard name == "en0" || name == "en1" else {
                continue
            }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(
                interface.ifa_addr,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            address = String(cString: hostname)
            break
        }

        return address
    }
}
```

- [ ] **Step 2: Wire server into store**

Modify `Sources/AndroidBridge/WirelessTransferStore.swift`:

```swift
private let browserServer = WirelessHTTPServer()
```

Add it near other stored properties.

Replace the URL assignment inside `startBrowserSession()`:

```swift
do {
    browserURL = try browserServer.start(session: session)
    browserStatusMessage = "Browser Transfer session is ready."
} catch {
    browserSession = nil
    browserURL = nil
    browserStatusMessage = "Could not start Browser Transfer: \(error.localizedDescription)"
}
```

Add server stop in `stopBrowserSession()`:

```swift
browserServer.stop()
```

- [ ] **Step 3: Build**

Run:

```bash
swift build
```

Expected: build succeeds.

- [ ] **Step 4: Manual smoke test**

Run:

```bash
./script/build_and_run.sh --verify
```

Expected: app bundle verifies. Open app, Wireless Transfer, Start Session. QR and URL show a local network IP.

- [ ] **Step 5: Commit**

```bash
git add Sources/AndroidBridgeCore/WirelessHTTPServer.swift Sources/AndroidBridge/WirelessTransferStore.swift
git commit -m "Start browser transfer web server"
```

---

### Task 6: Implement Phone To Mac Uploads

**Files:**
- Modify: `Sources/AndroidBridgeCore/WirelessHTTPServer.swift`
- Modify: `Sources/AndroidBridgeCore/WirelessHTMLRenderer.swift`
- Modify: `Sources/AndroidBridge/WirelessTransferStore.swift`

- [ ] **Step 1: Add upload callback to server**

Add to `WirelessHTTPServer`:

```swift
public typealias UploadHandler = @Sendable (_ filename: String, _ data: Data) -> Void
private var uploadHandler: UploadHandler?

public func setUploadHandler(_ handler: UploadHandler?) {
    uploadHandler = handler
}
```

- [ ] **Step 2: Add request routing for multipart upload**

Inside `response(for:)`, before rendering HTML:

```swift
if firstLine.hasPrefix("POST /upload") {
    return handleUpload(request: request, session: session)
}
```

Add helpers:

```swift
private func handleUpload(request: String, session: WirelessTransferSession) -> Data {
    guard let boundary = multipartBoundary(from: request),
          let bodyRange = request.range(of: "\r\n\r\n") else {
        return httpResponse(status: "400 Bad Request", body: "Invalid upload")
    }

    let body = String(request[bodyRange.upperBound...])
    let parts = body.components(separatedBy: "--\(boundary)")
    var savedCount = 0

    for part in parts {
        guard let filename = filename(from: part),
              let dataRange = part.range(of: "\r\n\r\n") else {
            continue
        }
        var payload = String(part[dataRange.upperBound...])
        if payload.hasSuffix("\r\n") {
            payload.removeLast(2)
        }
        uploadHandler?(filename, Data(payload.utf8))
        savedCount += 1
    }

    return httpResponse(status: "200 OK", body: "Uploaded \(savedCount) file(s).")
}

private func multipartBoundary(from request: String) -> String? {
    request
        .components(separatedBy: "\r\n")
        .first { $0.lowercased().hasPrefix("content-type: multipart/form-data;") }?
        .components(separatedBy: "boundary=")
        .last
}

private func filename(from part: String) -> String? {
    guard let disposition = part
        .components(separatedBy: "\r\n")
        .first(where: { $0.lowercased().contains("content-disposition:") }),
          let range = disposition.range(of: "filename=\"") else {
        return nil
    }
    let suffix = disposition[range.upperBound...]
    guard let end = suffix.firstIndex(of: "\"") else {
        return nil
    }
    return String(suffix[..<end])
}
```

- [ ] **Step 3: Save uploads inside receive folder**

In `WirelessTransferStore.startBrowserSession()`, after server starts:

```swift
browserServer.setUploadHandler { [weak self] filename, data in
    Task { @MainActor in
        self?.saveUploadedFile(filename: filename, data: data)
    }
}
```

Add method:

```swift
private func saveUploadedFile(filename: String, data: Data) {
    guard let session = browserSession else {
        return
    }

    do {
        try FileManager.default.createDirectory(
            at: session.receiveFolder,
            withIntermediateDirectories: true
        )

        let existing = Set((try? FileManager.default.contentsOfDirectory(atPath: session.receiveFolder.path)) ?? [])
        let destination = WirelessUploadDestination.destination(
            originalFilename: filename,
            receiveFolder: session.receiveFolder,
            existingFilenames: existing
        )
        try data.write(to: destination, options: .atomic)
        browserStatusMessage = "Received \(destination.lastPathComponent)."
    } catch {
        browserStatusMessage = "Could not save upload: \(error.localizedDescription)"
    }
}
```

In `stopBrowserSession()`:

```swift
browserServer.setUploadHandler(nil)
```

- [ ] **Step 4: Build**

Run:

```bash
swift build
```

Expected: build succeeds.

- [ ] **Step 5: Manual upload test**

Run:

```bash
./script/build_and_run.sh --verify
```

Expected: Start Browser Transfer, open shown URL from Android Chrome or local browser, upload a small text file, verify file appears in selected receive folder.

- [ ] **Step 6: Commit**

```bash
git add Sources/AndroidBridgeCore/WirelessHTTPServer.swift Sources/AndroidBridgeCore/WirelessHTMLRenderer.swift Sources/AndroidBridge/WirelessTransferStore.swift
git commit -m "Receive browser uploads from Android"
```

---

### Task 7: Implement Mac To Phone Downloads And Folder ZIPs

**Files:**
- Create: `Sources/AndroidBridgeCore/WirelessZipArchive.swift`
- Modify: `Sources/AndroidBridgeCore/WirelessHTTPServer.swift`
- Modify: `Sources/AndroidBridge/WirelessTransferStore.swift`
- Modify: `Sources/AndroidBridgeCoreTests/main.swift`

- [ ] **Step 1: Add ZIP naming test**

Append:

```swift
func wirelessZipArchiveUsesFolderDownloadName() {
    let item = SharedDownloadItem(
        url: URL(fileURLWithPath: "/Users/me/Desktop/Camera", isDirectory: true),
        kind: .folder,
        byteCount: nil
    )

    check(expectEqual(WirelessZipArchive.archiveFilename(for: item), "Camera.zip", "folder archive filename"))
}
```

Add call:

```swift
wirelessZipArchiveUsesFolderDownloadName()
```

- [ ] **Step 2: Implement ZIP helper**

Create `Sources/AndroidBridgeCore/WirelessZipArchive.swift`:

```swift
import Foundation

public enum WirelessZipArchive {
    public static func archiveFilename(for item: SharedDownloadItem) -> String {
        item.downloadName
    }

    public static func createArchive(for item: SharedDownloadItem, runner: ProcessRunning = FoundationProcessRunner()) async throws -> URL {
        let archiveURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AndroidBridgeWireless")
            .appendingPathComponent(item.id.uuidString)
            .appendingPathComponent(archiveFilename(for: item))

        try FileManager.default.createDirectory(
            at: archiveURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        _ = try await runner.run("/usr/bin/ditto", arguments: [
            "-c",
            "-k",
            "--sequesterRsrc",
            "--keepParent",
            item.url.path,
            archiveURL.path
        ])

        return archiveURL
    }
}
```

- [ ] **Step 3: Add download routing**

In `WirelessHTTPServer.response(for:)`, before HTML render:

```swift
if path.hasPrefix("/download/") {
    return handleDownload(path: path, session: session)
}
```

Add:

```swift
private func handleDownload(path: String, session: WirelessTransferSession) -> Data {
    let idString = path.replacingOccurrences(of: "/download/", with: "")
    guard let id = UUID(uuidString: idString),
          let item = session.sharedItem(id: id) else {
        return httpResponse(status: "404 Not Found", body: "Shared item not found")
    }

    switch item.kind {
    case .file:
        return fileResponse(url: item.url, downloadName: item.downloadName)
    case .folder:
        return httpResponse(status: "409 Conflict", body: "Folder ZIP is being prepared. Refresh and try again.")
    }
}

private func fileResponse(url: URL, downloadName: String) -> Data {
    guard let data = try? Data(contentsOf: url) else {
        return httpResponse(status: "404 Not Found", body: "File not found")
    }

    let header = """
    HTTP/1.1 200 OK\r
    Content-Type: application/octet-stream\r
    Content-Disposition: attachment; filename="\(downloadName)"\r
    Content-Length: \(data.count)\r
    Connection: close\r
    \r

    """
    return Data(header.utf8) + data
}
```

- [ ] **Step 4: First pass supports direct file download**

Run:

```bash
swift build
```

Expected: build succeeds. Manual test can download shared files from phone browser.

- [ ] **Step 5: Add folder ZIP generation before sharing folder**

Modify `WirelessTransferStore.addSharedFolder()` to create ZIP items before adding:

```swift
let selectedURLs = panel.urls
Task {
    var items: [SharedDownloadItem] = []
    for url in selectedURLs {
        let folderItem = SharedDownloadItem(url: url, kind: .folder, byteCount: nil)
        do {
            let archiveURL = try await WirelessZipArchive.createArchive(for: folderItem)
            let archiveItem = SharedDownloadItem(
                id: folderItem.id,
                url: archiveURL,
                kind: .file,
                byteCount: fileSize(archiveURL)
            )
            items.append(archiveItem)
        } catch {
            browserStatusMessage = "Could not prepare \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    session.addSharedItems(items)
    sharedItems = session.sharedItems
}
```

- [ ] **Step 6: Run tests and build**

Run:

```bash
swift run AndroidBridgeCoreTests
swift build
```

Expected: tests pass and build succeeds.

- [ ] **Step 7: Commit**

```bash
git add Sources/AndroidBridgeCore/WirelessZipArchive.swift Sources/AndroidBridgeCore/WirelessHTTPServer.swift Sources/AndroidBridge/WirelessTransferStore.swift Sources/AndroidBridgeCoreTests/main.swift
git commit -m "Share Mac files and folders with browser clients"
```

---

### Task 8: Add ADB Wireless Pair And Connect

**Files:**
- Create: `Sources/AndroidBridgeCore/ADBWirelessClient.swift`
- Modify: `Sources/AndroidBridgeCoreTests/main.swift`
- Modify: `Sources/AndroidBridge/ADBWirelessView.swift`
- Modify: `Sources/AndroidBridge/WirelessTransferView.swift`
- Modify: `Sources/AndroidBridge/WirelessTransferStore.swift`

- [ ] **Step 1: Add failing ADB wireless tests**

Append:

```swift
@MainActor
func adbWirelessPairAndConnectUseExpectedCommands() async throws {
    let runner = FakeProcessRunner(results: [
        ProcessResult(stdout: "Successfully paired to 192.168.1.20:37123\n", stderr: "", exitCode: 0),
        ProcessResult(stdout: "connected to 192.168.1.20:40125\n", stderr: "", exitCode: 0)
    ])
    let client = ADBWirelessClient(command: ADBCommand(executable: "/usr/bin/adb"), runner: runner)

    try await client.pair(address: "192.168.1.20:37123", code: "123456")
    try await client.connect(address: "192.168.1.20:40125")

    let runs = await runner.recordedRuns
    check(expectEqual(runs.map(\.arguments), [
        ["pair", "192.168.1.20:37123", "123456"],
        ["connect", "192.168.1.20:40125"]
    ], "adb wireless pair/connect arguments"))
}
```

Add call:

```swift
try await adbWirelessPairAndConnectUseExpectedCommands()
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
swift run AndroidBridgeCoreTests
```

Expected: FAIL because `ADBWirelessClient` does not exist.

- [ ] **Step 3: Implement ADB wireless client**

Create `Sources/AndroidBridgeCore/ADBWirelessClient.swift`:

```swift
import Foundation

public struct ADBWirelessClient: Sendable {
    private let command: ADBCommand
    private let runner: ProcessRunning

    public init(command: ADBCommand = ADBExecutableResolver.resolve(), runner: ProcessRunning = FoundationProcessRunner()) {
        self.command = command
        self.runner = runner
    }

    public func pair(address: String, code: String) async throws {
        _ = try await run(arguments: ["pair", address, code])
    }

    public func connect(address: String) async throws {
        _ = try await run(arguments: ["connect", address])
    }

    public func disconnect(address: String) async throws {
        _ = try await run(arguments: ["disconnect", address])
    }

    private func run(arguments: [String]) async throws -> ProcessResult {
        let result = try await runner.run(command.executable, arguments: command.leadingArguments + arguments)

        guard result.exitCode == 0 else {
            throw ADBClientError.commandFailed(helpfulErrorMessage(stderr: result.stderr, stdout: result.stdout, exitCode: result.exitCode))
        }

        return result
    }

    private func helpfulErrorMessage(stderr: String, stdout: String, exitCode: Int32) -> String {
        let combined = "\(stderr)\n\(stdout)".lowercased()

        if combined.contains("failed to authenticate") || combined.contains("wrong") {
            return "Pairing failed. Check the pairing code on your Android phone and try again."
        }

        if combined.contains("unable to connect") || combined.contains("connection refused") || combined.contains("timed out") {
            return "Could not connect to the phone. Make sure Mac and Android are on the same Wi-Fi and Wireless debugging is enabled."
        }

        let message = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? "adb wireless command exited with code \(exitCode)" : message
    }
}
```

- [ ] **Step 4: Add ADB Wireless UI**

Create `Sources/AndroidBridge/ADBWirelessView.swift`:

```swift
import SwiftUI

struct ADBWirelessView: View {
    @Bindable var store: WirelessTransferStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ADB Wireless")
                .font(.title2.bold())

            Text("Use this for full file browser access over Wi-Fi.")
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Pairing Address")
                    TextField("192.168.1.20:37123", text: $store.adbPairingAddress)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Pairing Code")
                    TextField("123456", text: $store.adbPairingCode)
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Connection Address")
                    TextField("192.168.1.20:40125", text: $store.adbConnectionAddress)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .frame(maxWidth: 520)

            HStack {
                Button("Pair") {
                    Task { await store.pairADBWireless() }
                }
                Button("Connect") {
                    Task { await store.connectADBWireless() }
                }
                Button("Disconnect") {
                    Task { await store.disconnectADBWireless() }
                }
            }

            Text(store.adbWirelessStatusMessage)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(18)
    }
}
```

Add properties and methods to `WirelessTransferStore`:

```swift
var adbPairingAddress = ""
var adbPairingCode = ""
var adbConnectionAddress = ""
private let adbWirelessClient = ADBWirelessClient()

func pairADBWireless() async {
    do {
        try await adbWirelessClient.pair(address: adbPairingAddress, code: adbPairingCode)
        adbWirelessStatusMessage = "Paired. Connecting next."
    } catch {
        adbWirelessStatusMessage = error.localizedDescription
    }
}

func connectADBWireless() async {
    do {
        try await adbWirelessClient.connect(address: adbConnectionAddress)
        adbWirelessStatusMessage = "Connected. Go to USB Transfer and refresh devices."
    } catch {
        adbWirelessStatusMessage = error.localizedDescription
    }
}

func disconnectADBWireless() async {
    do {
        try await adbWirelessClient.disconnect(address: adbConnectionAddress)
        adbWirelessStatusMessage = "Disconnected."
    } catch {
        adbWirelessStatusMessage = error.localizedDescription
    }
}
```

Replace the ADB shell in `WirelessTransferView`:

```swift
case .adbWireless:
    ADBWirelessView(store: store)
```

- [ ] **Step 5: Run tests and build**

Run:

```bash
swift run AndroidBridgeCoreTests
swift build
```

Expected: tests pass and build succeeds.

- [ ] **Step 6: Commit**

```bash
git add Sources/AndroidBridgeCore/ADBWirelessClient.swift Sources/AndroidBridge/ADBWirelessView.swift Sources/AndroidBridge/WirelessTransferView.swift Sources/AndroidBridge/WirelessTransferStore.swift Sources/AndroidBridgeCoreTests/main.swift
git commit -m "Add ADB wireless pair and connect"
```

---

### Task 9: Add ADB Wireless Discovery

**Files:**
- Create: `Sources/AndroidBridgeCore/ADBWirelessDiscovery.swift`
- Modify: `Sources/AndroidBridge/ADBWirelessView.swift`
- Modify: `Sources/AndroidBridge/WirelessTransferStore.swift`

- [ ] **Step 1: Add discovery model**

Create `Sources/AndroidBridgeCore/ADBWirelessDiscovery.swift`:

```swift
import Foundation
import Network

public struct ADBWirelessService: Identifiable, Equatable, Sendable {
    public enum Kind: Sendable {
        case pairing
        case connect
    }

    public let id: String
    public let name: String
    public let host: String
    public let port: UInt16
    public let kind: Kind

    public init(name: String, host: String, port: UInt16, kind: Kind) {
        self.id = "\(host):\(port):\(kind)"
        self.name = name
        self.host = host
        self.port = port
        self.kind = kind
    }

    public var address: String {
        "\(host):\(port)"
    }
}

public final class ADBWirelessDiscovery: @unchecked Sendable {
    private var pairingBrowser: NWBrowser?
    private var connectBrowser: NWBrowser?
    private let queue = DispatchQueue(label: "AndroidBridge.ADBWirelessDiscovery")

    public init() {}

    public func start(onUpdate: @escaping @Sendable ([ADBWirelessService]) -> Void) {
        var services: [ADBWirelessService] = []

        func startBrowser(type: String, kind: ADBWirelessService.Kind) -> NWBrowser {
            let descriptor = NWBrowser.Descriptor.bonjour(type: type, domain: nil)
            let browser = NWBrowser(for: descriptor, using: .tcp)
            browser.browseResultsChangedHandler = { results, _ in
                let mapped = results.compactMap { result -> ADBWirelessService? in
                    guard case let NWEndpoint.service(name, type: _, domain: _, interface: _) = result.endpoint else {
                        return nil
                    }
                    return ADBWirelessService(name: name, host: name, port: 0, kind: kind)
                }
                services.removeAll { $0.kind == kind }
                services.append(contentsOf: mapped)
                onUpdate(services)
            }
            browser.start(queue: queue)
            return browser
        }

        pairingBrowser = startBrowser(type: "_adb-tls-pairing._tcp", kind: .pairing)
        connectBrowser = startBrowser(type: "_adb-tls-connect._tcp", kind: .connect)
    }

    public func stop() {
        pairingBrowser?.cancel()
        connectBrowser?.cancel()
        pairingBrowser = nil
        connectBrowser = nil
    }
}
```

- [ ] **Step 2: Add discovery state and scan action**

In `WirelessTransferStore`:

```swift
var discoveredADBServices: [ADBWirelessService] = []
private let adbDiscovery = ADBWirelessDiscovery()

func scanADBWireless() {
    adbWirelessStatusMessage = "Scanning for wireless debugging devices..."
    adbDiscovery.start { [weak self] services in
        Task { @MainActor in
            self?.discoveredADBServices = services
            self?.adbWirelessStatusMessage = services.isEmpty
                ? "No wireless debugging devices found yet."
                : "Found \(services.count) wireless debugging service(s)."
        }
    }
}

func stopADBWirelessScan() {
    adbDiscovery.stop()
    adbWirelessStatusMessage = "Scan stopped."
}
```

- [ ] **Step 3: Show scan controls**

In `ADBWirelessView`, add before manual fields:

```swift
HStack {
    Button("Scan") {
        store.scanADBWireless()
    }
    Button("Stop Scan") {
        store.stopADBWirelessScan()
    }
}

List(store.discoveredADBServices) { service in
    Button {
        switch service.kind {
        case .pairing:
            store.adbPairingAddress = service.address
        case .connect:
            store.adbConnectionAddress = service.address
        }
    } label: {
        HStack {
            Text(service.name)
            Spacer()
            Text(service.kind == .pairing ? "Pair" : "Connect")
                .foregroundStyle(.secondary)
        }
    }
}
.frame(minHeight: 120, maxHeight: 180)
```

- [ ] **Step 4: Build**

Run:

```bash
swift build
```

Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/AndroidBridgeCore/ADBWirelessDiscovery.swift Sources/AndroidBridge/ADBWirelessView.swift Sources/AndroidBridge/WirelessTransferStore.swift
git commit -m "Discover ADB wireless services"
```

---

### Task 10: Integrate ADB Wireless With Existing File Browser

**Files:**
- Modify: `Sources/AndroidBridge/WirelessTransferStore.swift`
- Modify: `Sources/AndroidBridge/ADBWirelessView.swift`
- Modify: `Sources/AndroidBridge/ContentView.swift`
- Modify: `Sources/AndroidBridge/AndroidBridgeStore.swift`

- [ ] **Step 1: Make ADB Wireless refresh devices after connect**

Pass `AndroidBridgeStore` into `WirelessTransferView`:

```swift
WirelessTransferView(androidStore: store)
```

Update `WirelessTransferView`:

```swift
struct WirelessTransferView: View {
    @Bindable var androidStore: AndroidBridgeStore
    @State private var store = WirelessTransferStore()
    ...
    ADBWirelessView(store: store, androidStore: androidStore)
}
```

Update `ADBWirelessView`:

```swift
struct ADBWirelessView: View {
    @Bindable var store: WirelessTransferStore
    @Bindable var androidStore: AndroidBridgeStore
    ...
}
```

- [ ] **Step 2: Refresh devices from ADB Wireless UI**

In `ADBWirelessView`, after Connect button:

```swift
Button("Refresh Devices") {
    Task { await androidStore.refreshDevices() }
}
```

- [ ] **Step 3: Add guidance text**

In `ADBWirelessView`, add:

```swift
Text("After connecting, switch to USB Transfer and use the same file browser. ADB lists wireless debugging devices beside USB devices.")
    .font(.callout)
    .foregroundStyle(.secondary)
```

- [ ] **Step 4: Build**

Run:

```bash
swift build
```

Expected: build succeeds.

- [ ] **Step 5: Manual ADB Wireless test**

Run:

```bash
./script/build_and_run.sh --verify
```

Expected:

- Pairing succeeds with Android Wireless debugging.
- Connect succeeds.
- Refresh Devices shows wireless device in USB Transfer sidebar.
- Existing browse/download/upload/open flows work for the wireless device.

- [ ] **Step 6: Commit**

```bash
git add Sources/AndroidBridge/ContentView.swift Sources/AndroidBridge/WirelessTransferView.swift Sources/AndroidBridge/ADBWirelessView.swift Sources/AndroidBridge/WirelessTransferStore.swift Sources/AndroidBridge/AndroidBridgeStore.swift
git commit -m "Reuse file browser for ADB wireless devices"
```

---

### Task 11: Harden Browser Transfer Session

**Files:**
- Modify: `Sources/AndroidBridgeCore/WirelessHTTPServer.swift`
- Modify: `Sources/AndroidBridge/WirelessTransferStore.swift`
- Modify: `Sources/AndroidBridgeCoreTests/main.swift`

- [ ] **Step 1: Require token path and PIN cookie**

Implement simple browser auth:

- GET `/<token>` shows PIN form.
- POST `/pin` with correct PIN returns `Set-Cookie: AndroidBridgePIN=<token>`.
- Authenticated requests may upload and download.

Use this cookie check:

```swift
private func isAuthenticated(request: String, session: WirelessTransferSession) -> Bool {
    request.contains("Cookie: AndroidBridgePIN=\(session.token.urlToken)")
}
```

Use this PIN check:

```swift
private func postedPIN(from request: String) -> String? {
    guard let bodyRange = request.range(of: "\r\n\r\n") else {
        return nil
    }
    let body = String(request[bodyRange.upperBound...])
    return body
        .components(separatedBy: "&")
        .first { $0.hasPrefix("pin=") }?
        .replacingOccurrences(of: "pin=", with: "")
}
```

- [ ] **Step 2: Add idle timeout**

In `WirelessTransferStore`:

```swift
private var browserTimeoutTask: Task<Void, Never>?

private func restartBrowserTimeout() {
    browserTimeoutTask?.cancel()
    browserTimeoutTask = Task { [weak self] in
        try? await Task.sleep(for: .minutes(30))
        await MainActor.run {
            self?.stopBrowserSession()
            self?.browserStatusMessage = "Browser Transfer session stopped after 30 minutes."
        }
    }
}
```

Call `restartBrowserTimeout()` after successful session start and after each upload save.

Cancel in `stopBrowserSession()`:

```swift
browserTimeoutTask?.cancel()
browserTimeoutTask = nil
```

- [ ] **Step 3: Build and manually verify**

Run:

```bash
swift build
./script/build_and_run.sh --verify
```

Expected:

- Phone page asks for PIN.
- Wrong PIN stays locked.
- Correct PIN unlocks transfer page.
- Stop Session invalidates page.

- [ ] **Step 4: Commit**

```bash
git add Sources/AndroidBridgeCore/WirelessHTTPServer.swift Sources/AndroidBridge/WirelessTransferStore.swift Sources/AndroidBridgeCoreTests/main.swift
git commit -m "Harden browser transfer sessions"
```

---

### Task 12: Update README And Final Verification

**Files:**
- Modify: `README.md`
- Create: `docs/releases/v1.2.0.md`

- [ ] **Step 1: Update README feature list**

Add wireless bullets:

```markdown
- Transfers files wirelessly through an Android browser with no Android app required
- Shares Mac files or folders to a phone over the local network
- Receives phone uploads into a Mac folder you choose
- Supports ADB Wireless for full file browser access over Wi-Fi
```

- [ ] **Step 2: Update requirements**

Add:

```markdown
For Browser Transfer, the Mac and Android phone must be on the same local network.

For ADB Wireless, Android SDK Platform-Tools and Android Wireless debugging are required.
```

- [ ] **Step 3: Add release notes**

Create `docs/releases/v1.2.0.md`:

```markdown
# AndroidBridge 1.2.0

## Highlights

- Adds Wireless Transfer.
- Adds Browser Transfer with QR-based local sharing and no Android app requirement.
- Receives Android browser uploads into a selected Mac folder.
- Shares Mac files and folder ZIPs to Android browsers.
- Adds ADB Wireless pair/connect flow for full file browser access over Wi-Fi.

## Verification

- `swift run AndroidBridgeCoreTests`
- `swift build`
- `./script/build_and_run.sh --verify`
- `./script/package_dmg.sh`
```

- [ ] **Step 4: Run full verification**

Run:

```bash
swift run AndroidBridgeCoreTests
swift build
./script/build_and_run.sh --verify
```

Expected:

- Tests print `AndroidBridgeCoreTests passed`.
- Build succeeds.
- Bundle verification succeeds.

- [ ] **Step 5: Package**

Run:

```bash
./script/package_dmg.sh
```

Expected: script creates `dist/AndroidBridge.dmg` and prints SHA256.

- [ ] **Step 6: Commit**

```bash
git add README.md docs/releases/v1.2.0.md
git commit -m "Document wireless transfer"
```

---

## Self-Review

Spec coverage:

- USB/Wireless tabs: Task 1.
- Browser Transfer default: Tasks 1 and 4.
- Receive folder and automatic upload save: Tasks 4 and 6.
- QR/URL/PIN: Tasks 4 and 11.
- Add files/folders during session: Tasks 4 and 7.
- Folder ZIP downloads: Task 7.
- Token-gated temporary server: Tasks 5 and 11.
- ADB Wireless discovery and manual fallback: Tasks 8 and 9.
- Reuse existing ADB browser: Task 10.
- Docs and release notes: Task 12.

Execution rule:

- Implement each task with tests/build before commit.
- Do not start Task 8 until Browser Transfer works end to end.
- Keep `HANDOFF.md` untracked unless the user asks to commit it.
