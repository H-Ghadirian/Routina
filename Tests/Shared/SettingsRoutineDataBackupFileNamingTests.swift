import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct SettingsRoutineDataBackupFileNamingTests {
    @Test
    func defaultBackupFileNameUsesTimestampAndExtension() {
        let now = DateComponents(
            calendar: gregorianUTC,
            timeZone: gregorianUTC.timeZone,
            year: 2026,
            month: 5,
            day: 4,
            hour: 8,
            minute: 12,
            second: 30
        ).date!

        #expect(
            SettingsRoutineDataBackupFileNaming.defaultBackupFileName(
                now: now,
                fileExtension: "routinabackup",
                timeZone: gregorianUTC.timeZone
            ) == "routina-backup-2026-05-04-081230.routinabackup"
        )
    }

    @Test
    func packageAttachmentFileNameSanitizesUnsafeNames() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        #expect(
            SettingsRoutineDataBackupFileNaming.packageAttachmentFileName(
                id: id,
                fileName: " invoices/2026\\may:receipt\n.pdf "
            ) == "00000000-0000-0000-0000-000000000001-invoices-2026-may-receipt-.pdf"
        )
        #expect(
            SettingsRoutineDataBackupFileNaming.packageAttachmentFileName(
                id: id,
                fileName: "   "
            ) == "00000000-0000-0000-0000-000000000001-attachment"
        )
    }
}

private let gregorianUTC: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}()
