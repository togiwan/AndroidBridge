import SwiftUI

struct ContentView: View {
    @Bindable var store: AndroidBridgeStore

    var body: some View {
        NavigationSplitView {
            DeviceSidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            FileBrowserView(store: store)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task {
                        await store.refreshDevices()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh devices")
                .disabled(store.isBusy)

                Button {
                    Task {
                        await store.uploadFile()
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .help("Upload files or folders to Android")
                .disabled(store.isBusy || store.selectedDevice == nil)

                Button {
                    Task {
                        await store.downloadSelected()
                    }
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
        .sheet(isPresented: $store.isShowingSetupGuide) {
            SetupGuideView()
        }
        .sheet(isPresented: $store.isShowingDonation) {
            DonationView()
        }
    }
}
