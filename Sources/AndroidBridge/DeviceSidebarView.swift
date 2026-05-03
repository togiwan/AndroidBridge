import AndroidBridgeCore
import SwiftUI

struct DeviceSidebarView: View {
    @Bindable var store: AndroidBridgeStore

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $store.selectedDeviceID) {
                Section("Devices") {
                    ForEach(store.devices) { device in
                        DeviceRow(device: device)
                            .tag(device.id)
                    }
                }
            }
            .listStyle(.sidebar)
            .onChange(of: store.selectedDeviceID) {
                Task {
                    await store.refreshFiles()
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label("USB debugging must be enabled on the phone.", systemImage: "cable.connector")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Button("Refresh Devices") {
                    Task {
                        await store.refreshDevices()
                    }
                }
                .disabled(store.isBusy)

                Button {
                    store.isShowingSetupGuide = true
                } label: {
                    Label("Setup Guide", systemImage: "questionmark.circle")
                }

                Button {
                    store.isShowingDonation = true
                } label: {
                    Label("Donate", systemImage: "heart")
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DeviceRow: View {
    let device: AndroidDevice

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: device.state == .device ? "iphone.gen3" : "exclamationmark.triangle")
                .foregroundStyle(device.state == .device ? Color.secondary : Color.orange)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.id)
                    .lineLimit(1)

                Text(device.displayState)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
