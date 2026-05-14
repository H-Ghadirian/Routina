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
        updatedRoutineCount: Int,
        updatedGoalCount: Int = 0
    ) -> String {
        let updatedParts = tagUpdateParts(
            routineCount: updatedRoutineCount,
            goalCount: updatedGoalCount
        )
        guard !updatedParts.isEmpty else {
            return "Updated tag to \(updatedTagName)."
        }
        return "Updated tag to \(updatedTagName) in \(updatedParts.joined(separator: " and "))."
    }

    static func deleteTagSuccessMessage(
        deletedTagName: String,
        updatedRoutineCount: Int,
        updatedGoalCount: Int = 0
    ) -> String {
        let updatedParts = tagUpdateParts(
            routineCount: updatedRoutineCount,
            goalCount: updatedGoalCount
        )
        guard !updatedParts.isEmpty else {
            return "Deleted \(deletedTagName)."
        }
        return "Deleted \(deletedTagName) from \(updatedParts.joined(separator: " and "))."
    }

    private static func tagUpdateParts(routineCount: Int, goalCount: Int) -> [String] {
        var parts: [String] = []
        if routineCount > 0 {
            parts.append(routineCount == 1 ? "1 routine" : "\(routineCount) routines")
        }
        if goalCount > 0 {
            parts.append(goalCount == 1 ? "1 goal" : "\(goalCount) goals")
        }
        return parts
    }
}
