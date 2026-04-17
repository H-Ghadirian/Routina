import CloudKit

enum SettingsFeedbackSupport {
    static func cloudDataResetErrorMessage(for error: Error) -> String {
        guard let cloudError = error as? CKError else {
            return "Data reset failed: \(error.localizedDescription)"
        }

        switch cloudError.code {
        case .notAuthenticated:
            return "Please sign in to iCloud and try again."
        case .networkUnavailable, .networkFailure:
            return "Network issue while deleting iCloud data. Please try again."
        case .serviceUnavailable, .requestRateLimited:
            return "iCloud is temporarily unavailable. Please try again shortly."
        default:
            return "Data reset failed: \(cloudError.localizedDescription)"
        }
    }

    static func renameTagSuccessMessage(
        updatedTagName: String,
        updatedRoutineCount: Int
    ) -> String {
        switch updatedRoutineCount {
        case ..<1:
            return "Updated tag to \(updatedTagName)."
        case 1:
            return "Updated tag to \(updatedTagName) in 1 routine."
        default:
            return "Updated tag to \(updatedTagName) in \(updatedRoutineCount) routines."
        }
    }

    static func deleteTagSuccessMessage(
        deletedTagName: String,
        updatedRoutineCount: Int
    ) -> String {
        switch updatedRoutineCount {
        case ..<1:
            return "Deleted \(deletedTagName)."
        case 1:
            return "Deleted \(deletedTagName) from 1 routine."
        default:
            return "Deleted \(deletedTagName) from \(updatedRoutineCount) routines."
        }
    }
}
