import Foundation
import SwiftData

enum SettingsRoutineDataImportStoreResetter {
    @MainActor
    static func deleteExistingData(in context: ModelContext) throws {
        CloudKitDirectPullTokenStore.clearAll()
        try LocalUserDataResetService.wipeAllUserData(in: context)
    }
}
