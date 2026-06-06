import Foundation

extension SettingsCloudState {
    var usageTotalText: String {
        ByteCountFormatter.string(fromByteCount: cloudUsageEstimate.totalPayloadBytes, countStyle: .file)
    }

    var usageTaskPayloadText: String {
        ByteCountFormatter.string(fromByteCount: cloudUsageEstimate.taskPayloadBytes, countStyle: .file)
    }

    var usageLogPayloadText: String {
        ByteCountFormatter.string(fromByteCount: cloudUsageEstimate.logPayloadBytes, countStyle: .file)
    }

    var usagePlacePayloadText: String {
        ByteCountFormatter.string(fromByteCount: cloudUsageEstimate.placePayloadBytes, countStyle: .file)
    }

    var usageGoalPayloadText: String {
        ByteCountFormatter.string(fromByteCount: cloudUsageEstimate.goalPayloadBytes, countStyle: .file)
    }

    var usageEmotionPayloadText: String {
        ByteCountFormatter.string(fromByteCount: cloudUsageEstimate.emotionLogPayloadBytes, countStyle: .file)
    }

    var usageNotePayloadText: String {
        ByteCountFormatter.string(fromByteCount: cloudUsageEstimate.notePayloadBytes, countStyle: .file)
    }

    var usageEventPayloadText: String {
        ByteCountFormatter.string(fromByteCount: cloudUsageEstimate.eventPayloadBytes, countStyle: .file)
    }

    var usageImagePayloadText: String {
        ByteCountFormatter.string(fromByteCount: cloudUsageEstimate.imagePayloadBytes, countStyle: .file)
    }

    var usageVoiceNotePayloadText: String {
        ByteCountFormatter.string(fromByteCount: cloudUsageEstimate.voiceNotePayloadBytes, countStyle: .file)
    }

    var usageSummaryText: String {
        let mediaCount = cloudUsageEstimate.imageCount + cloudUsageEstimate.voiceNoteCount
        switch (cloudUsageEstimate.totalRecordCount, mediaCount) {
        case (0, 0):
            return cloudSyncAvailable
                ? "No Routina data is estimated to be using iCloud yet."
                : "No Routina data is available to estimate yet."
        case let (recordCount, 0):
            return "\(recordCount) synced records are included in this estimate."
        case let (recordCount, mediaCount):
            return "\(recordCount) synced records and \(mediaCount) media item\(mediaCount == 1 ? "" : "s") are included in this estimate."
        }
    }

    var usageFootnoteText: String {
        "Estimate based on local Routina data. Actual iCloud storage can be higher because CloudKit adds its own metadata and history."
    }

    var isCloudDataResetPasswordReady: Bool {
        cloudDataResetPasswordDraft.count >= SettingsCloudEditor.dataResetMinimumPasswordLength &&
            cloudDataResetPasswordDraft == cloudDataResetPasswordConfirmationDraft
    }

    var cloudDataResetPasswordStatusText: String {
        if cloudDataResetPasswordDraft.isEmpty && cloudDataResetPasswordConfirmationDraft.isEmpty {
            return "Create a one-time deletion password, then re-enter it to unlock deletion."
        }
        if cloudDataResetPasswordDraft.count < SettingsCloudEditor.dataResetMinimumPasswordLength {
            return "Use at least \(SettingsCloudEditor.dataResetMinimumPasswordLength) characters."
        }
        if cloudDataResetPasswordConfirmationDraft.isEmpty {
            return "Re-enter the deletion password."
        }
        if cloudDataResetPasswordDraft != cloudDataResetPasswordConfirmationDraft {
            return "Passwords do not match."
        }
        return "Deletion password matched. The password will not be saved."
    }

    var overviewSubtitle: String {
        if isCloudSyncInProgress {
            return "Syncing with iCloud"
        }
        if isCloudDataResetInProgress {
            return "Deleting iCloud data"
        }
        if !cloudStatusMessage.isEmpty {
            return cloudStatusMessage
        }
        if !cloudSyncAvailable {
            return "Unavailable in this build"
        }
        return "Sync routines across devices"
    }

    var syncStatusText: String {
        if isCloudDataResetInProgress {
            return "Deleting iCloud data..."
        }
        if isCloudSyncInProgress {
            return "Syncing..."
        }
        if !cloudStatusMessage.isEmpty {
            return cloudStatusMessage
        }
        if !cloudSyncAvailable {
            return "iCloud sync is disabled in this build."
        }
        return "Ready to sync."
    }
}

extension SettingsDataTransferState {
    var overviewSubtitle: String {
        if isDataTransferInProgress {
            return "Importing or exporting backup"
        }
        if !dataTransferStatusMessage.isEmpty {
            return dataTransferStatusMessage
        }
        return "Export or import your routine data"
    }

    var statusText: String {
        if isDataTransferInProgress {
            return "Processing backup..."
        }
        if !dataTransferStatusMessage.isEmpty {
            return dataTransferStatusMessage
        }
        return "Export a full backup package, or import a package or legacy JSON file."
    }
}
