import Foundation

struct RoutineDataTransferClient: Sendable {
    var selectExportURL: @MainActor @Sendable (_ suggestedFileName: String) async -> URL?
    var selectImportURL: @MainActor @Sendable () async -> URL?
    var recoveryDirectoryURL: @MainActor @Sendable () throws -> URL?
}

extension RoutineDataTransferClient {
    #if SWIFT_PACKAGE
    static let live = RoutineDataTransferClient(
        selectExportURL: { _ in nil },
        selectImportURL: { nil },
        recoveryDirectoryURL: {
            try SettingsRoutineDataRecoveryStore.defaultDirectoryURL()
        }
    )
    #else
    static let live = RoutineDataTransferClient(
        selectExportURL: { suggestedFileName in
            await PlatformSupport.selectRoutineDataExportURL(suggestedFileName: suggestedFileName)
        },
        selectImportURL: {
            await PlatformSupport.selectRoutineDataImportURL()
        },
        recoveryDirectoryURL: {
            try SettingsRoutineDataRecoveryStore.defaultDirectoryURL()
        }
    )
    #endif

    static let noop = RoutineDataTransferClient(
        selectExportURL: { _ in nil },
        selectImportURL: { nil },
        recoveryDirectoryURL: { nil }
    )
}
