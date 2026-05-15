import SwiftUI

struct WirelessTransferView: View {
    @Bindable var androidStore: AndroidBridgeStore
    @State private var store = WirelessTransferStore()

    var body: some View {
        ADBWirelessView(store: store, androidStore: androidStore)
    }
}
