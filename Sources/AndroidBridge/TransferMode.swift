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
