import Foundation

enum TransferMode: String, CaseIterable, Identifiable {
    case usb
    case wireless

    var id: String { rawValue }

    var title: String {
        switch self {
        case .usb:
            "USB Transfer"
        case .wireless:
            "Wireless Transfer"
        }
    }
}

enum WirelessTransferMode: String, CaseIterable, Identifiable {
    case browser
    case adbWireless

    var id: String { rawValue }

    var title: String {
        switch self {
        case .browser:
            "Browser Transfer"
        case .adbWireless:
            "ADB Wireless"
        }
    }
}
