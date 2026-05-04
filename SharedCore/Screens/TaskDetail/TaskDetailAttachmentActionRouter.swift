import Foundation

struct TaskDetailAttachmentActionRouter {
    let task: RoutineTask
    let saveFile: (AttachmentItem) -> Void
    let openURL: (URL) -> Void

    func saveAttachment(_ item: AttachmentItem) {
        saveFile(item)
    }

    func openAttachment(data: Data, fileName: String) {
        guard let fileURL = TaskDetailAttachmentTempFileSupport.writeTemporaryAttachment(
            data: data,
            fileName: fileName
        ) else { return }
        openURL(fileURL)
    }

    func openTaskImage(data: Data) {
        let fileName = TaskDetailAttachmentPresentation.taskImageFileName(for: task, data: data)
        openAttachment(data: data, fileName: fileName)
    }
}
