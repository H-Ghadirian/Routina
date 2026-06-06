import Foundation
import SwiftData

enum SettingsRoutineDataImportStoreResetter {
    @MainActor
    static func deleteExistingData(in context: ModelContext) throws {
        try LocalUserDataResetService.wipeAllUserData(in: context)
    }
}
