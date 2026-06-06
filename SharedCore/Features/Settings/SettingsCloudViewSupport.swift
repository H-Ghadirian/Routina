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

    var overviewSubtitle: String {
        if isCloudSyncInProgress {
            return "Syncing with iCloud"
        }
        if isCloudDataResetAuthenticationInProgress {
            return "Confirming App Lock"
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
        if isCloudDataResetAuthenticationInProgress {
            return "Confirming App Lock..."
        }
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
    static let recentBackupWindow: TimeInterval = 24 * 60 * 60

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

    func hasRecentSuccessfulBackup(referenceDate: Date = Date()) -> Bool {
        guard let lastSuccessfulBackupDate else { return false }
        let age = referenceDate.timeIntervalSince(lastSuccessfulBackupDate)
        return age >= 0 && age <= Self.recentBackupWindow
    }

    func backupFreshnessText(referenceDate: Date = Date()) -> String {
        guard let lastSuccessfulBackupDate else {
            return "No recent backup saved on this device."
        }

        let formattedDate = lastSuccessfulBackupDate.formatted(
            date: .abbreviated,
            time: .shortened
        )
        if hasRecentSuccessfulBackup(referenceDate: referenceDate) {
            return "Recent backup saved \(formattedDate)."
        }
        return "Last backup was \(formattedDate), more than 24 hours ago."
    }

    func cloudResetBackupRequirementText(referenceDate: Date = Date()) -> String {
        if hasRecentSuccessfulBackup(referenceDate: referenceDate) {
            return backupFreshnessText(referenceDate: referenceDate)
        }
        return "\(backupFreshnessText(referenceDate: referenceDate)) Save a backup within the last 24 hours before deleting iCloud data."
    }
}
