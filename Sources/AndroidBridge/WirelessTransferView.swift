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
