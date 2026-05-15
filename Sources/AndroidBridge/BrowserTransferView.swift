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
                receivedUploadsTable
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
            Text("Shared with Phone")
                .font(.headline)

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

            if store.sharedItems.isEmpty {
                Text("Files added here appear on the phone after tapping Refresh List.")
                    .foregroundStyle(.secondary)
            } else {
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

            if !store.pendingFolderArchiveNames.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Preparing ZIP")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(store.pendingFolderArchiveNames, id: \.self) { name in
                        Label(name, systemImage: "archivebox")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var receivedUploadsTable: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Received from Phone")
                .font(.headline)

            if store.receivedUploads.isEmpty {
                Text("Files sent from the phone will appear here and save to the receive folder above.")
                    .foregroundStyle(.secondary)
            } else {
                Table(store.receivedUploads) {
                    TableColumn("Name") { upload in
                        Button(upload.name) {
                            store.revealReceivedUpload(upload)
                        }
                        .buttonStyle(.link)
                    }
                    TableColumn("Size") { upload in
                        Text(ByteCountFormatter.string(fromByteCount: Int64(upload.byteCount), countStyle: .file))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minHeight: 120)
            }
        }
    }
}
