import AndroidBridgeCore
import SwiftUI

struct ADBWirelessView: View {
    @Bindable var store: WirelessTransferStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ADB Wireless")
                .font(.title2.bold())

            Text("Use this for full file browser access over Wi-Fi.")
                .foregroundStyle(.secondary)

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
