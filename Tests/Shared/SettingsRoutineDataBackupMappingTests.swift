import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct SettingsRoutineDataBackupMappingTests {
    @Test
    func taskMappingChoosesInlineImageOrAttachmentReference() {
        let taskID = UUID()
        let attachmentID = UUID()
        let imageData = Data([1, 2, 3])
        let task = RoutineTask(
            id: taskID,
            name: "Archive receipt",
            pressure: .high,
            imageData: imageData,
            interval: 0
        )

        let inline = SettingsRoutineDataBackupMapping.task(
            task,
            imageData: imageData,
            imageAttachmentID: nil,
            includesPressure: true
        )
        let packaged = SettingsRoutineDataBackupMapping.task(
            task,
            imageData: nil,
            imageAttachmentID: attachmentID,
            includesPressure: false
        )

        #expect(inline.id == taskID)
        #expect(inline.imageData == imageData)
        #expect(inline.imageAttachmentID == nil)
        #expect(inline.interval == 1)
        #expect(inline.pressure == .high)
        #expect(packaged.imageData == nil)
        #expect(packaged.imageAttachmentID == attachmentID)
        #expect(packaged.pressure == nil)
    }
}
