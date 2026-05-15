import AndroidBridgeCore
import Foundation
import Observation

@MainActor
@Observable
final class WirelessTransferStore {
    var adbWirelessStatusMessage = "Scan for wireless debugging devices or connect manually."
    var adbPairingAddress = ""
    var adbPairingCode = ""
    var adbConnectionAddress = ""
    var discoveredADBServices: [ADBWirelessService] = []

    private let adbWirelessClient = ADBWirelessClient()
    private let adbDiscovery = ADBWirelessDiscovery()

    func pairADBWireless() async {
        do {
            try await adbWirelessClient.pair(address: adbPairingAddress, code: adbPairingCode)
            if adbConnectionAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                adbWirelessStatusMessage = "Paired. Enter the connection address, then connect."
            } else {
                try await adbWirelessClient.connect(address: adbConnectionAddress)
                adbWirelessStatusMessage = "Paired and connected. Go to USB Transfer and refresh devices."
            }
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
        discoveredADBServices = []
        adbWirelessStatusMessage = "Scan stopped."
    }
}
