import Foundation

struct ReceivedUploadRecord: Identifiable, Equatable {
    let id = UUID()
    let fileURL: URL
    let byteCount: Int
    let receivedAt: Date

    var name: String {
        fileURL.lastPathComponent
    }
}
