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
                ADBWirelessView(store: store)
            }
        }
    }
}
