import Foundation
import SwiftData

enum SettingsRoutineDataImportStoreResetter {
    @MainActor
    static func deleteExistingData(
        in context: ModelContext,
        clearsCloudKitTokens: Bool = true,
        savesChanges: Bool = true
    ) throws {
        if clearsCloudKitTokens {
            CloudKitDirectPullTokenStore.clearAll()
        }
        try LocalUserDataResetService.wipeAllUserData(
            in: context,
            savesChanges: savesChanges
        )
    }
}
