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
    }
}
