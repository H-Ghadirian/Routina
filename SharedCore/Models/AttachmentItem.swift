import Foundation

struct AttachmentItem: Equatable, Identifiable, Codable, Sendable {
    var id: UUID
    var fileName: String
    var data: Data

    init(id: UUID = UUID(), fileName: String, data: Data) {
        self.id = id
        self.fileName = fileName
        self.data = data
    }
}
