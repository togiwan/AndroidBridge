import AndroidBridgeCore
import SwiftUI

struct FileBrowserView: View {
    @Bindable var store: AndroidBridgeStore

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if store.selectedDevice == nil {
                ContentUnavailableView(
                    "No Android Device",
                    systemImage: "cable.connector.slash",
                    description: Text("Connect your phone by USB, enable USB debugging, then refresh devices.")
                )
            } else if store.files.isEmpty && !store.isBusy {
                ContentUnavailableView(
                    "No Files",
                    systemImage: "folder",
                    description: Text(store.statusMessage)
                )
            } else {
                Table(store.files, selection: $store.selectedItemID) {
                    TableColumn("Name") { item in
                        HStack(spacing: 8) {
                            Image(systemName: item.kind == .folder ? "folder" : "doc")
                                .foregroundStyle(.secondary)
                                .frame(width: 18)

                            Text(item.name)
                                .lineLimit(1)
                        }
                    }

                    TableColumn("Kind") { item in
                        Text(item.kind == .folder ? "Folder" : "File")
                            .foregroundStyle(.secondary)
                    }
                    .width(90)

                    TableColumn("Size") { item in
                        Text(item.kind == .folder ? "--" : ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                            .foregroundStyle(.secondary)
                    }
                    .width(110)
                }
                .onSubmit {
                    if let item = store.selectedItem {
                        Task {
                            await store.open(item)
                        }
                    }
                }
                .contextMenu(forSelectionType: AndroidFileItem.ID.self) { _ in
                    Button("Open") {
                        if let item = store.selectedItem {
                            Task {
                                await store.open(item)
                            }
                        }
                    }

                    Button("Download to Downloads") {
                        Task {
                            await store.downloadSelected()
                        }
                    }
                } primaryAction: { _ in
                    if let item = store.selectedItem {
                        Task {
                            await store.open(item)
                        }
                    }
                }
            }

            Divider()

            statusBar
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            if store.isBusy {
                if let progress = store.transferProgress {
                    ProgressView(value: progress)
                        .frame(width: 150)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Text(store.transferDetailMessage ?? store.statusMessage)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                Task {
                    await store.goUp()
                }
            } label: {
                Image(systemName: "arrow.up")
            }
            .help("Go to parent folder")
            .disabled(store.isBusy || store.currentPath == "/")

            Text(store.currentPath)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button {
                Task {
                    await store.refreshFiles()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh folder")
            .disabled(store.isBusy || store.selectedDevice == nil)

            Button {
                Task {
                    await store.uploadFile()
                }
            } label: {
                Label("Upload", systemImage: "square.and.arrow.up")
            }
            .help("Upload a file or folder to Android")
            .disabled(store.isBusy || store.selectedDevice == nil)

            Button {
                Task {
                    await store.downloadSelected()
                }
            } label: {
                Label("Download", systemImage: "square.and.arrow.down")
            }
            .disabled(store.isBusy || store.selectedItem == nil)
        }
        .padding(14)
    }
}
