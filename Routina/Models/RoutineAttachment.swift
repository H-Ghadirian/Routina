import Foundation
import SwiftData

@Model
final class RoutineAttachment {
    var id: UUID = UUID()
    var taskID: UUID = UUID()
    var fileName: String = ""
    @Attribute(.externalStorage) var data: Data = Data()
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        taskID: UUID,
        fileName: String,
        data: Data,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.taskID = taskID
        self.fileName = fileName
        self.data = data
        self.createdAt = createdAt
    }
}
