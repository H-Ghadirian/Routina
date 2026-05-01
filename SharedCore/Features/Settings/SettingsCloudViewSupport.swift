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

    var usageImagePayloadText: String {
        ByteCountFormatter.string(fromByteCount: cloudUsageEstimate.imagePayloadBytes, countStyle: .file)
    }

    var usageSummaryText: String {
        switch (cloudUsageEstimate.totalRecordCount, cloudUsageEstimate.imageCount) {
        case (0, 0):
            return cloudSyncAvailable
                ? "No Routina data is estimated to be using iCloud yet."
                : "No Routina data is available to estimate yet."
        case let (recordCount, 0):
            return "\(recordCount) synced records are included in this estimate."
        case let (recordCount, imageCount):
            return "\(recordCount) synced records and \(imageCount) image\(imageCount == 1 ? "" : "s") are included in this estimate."
        }
    }

    var usageFootnoteText: String {
        "Estimate based on local Routina data. Actual iCloud storage can be higher because CloudKit adds its own metadata and history."
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
            return "Importing or exporting JSON"
        }
        if !dataTransferStatusMessage.isEmpty {
            return dataTransferStatusMessage
        }
        return "Export or import your routine data"
    }

    var statusText: String {
        if isDataTransferInProgress {
            return "Processing JSON file..."
        }
        if !dataTransferStatusMessage.isEmpty {
            return dataTransferStatusMessage
        }
        return "Export or import all routine data as JSON."
    }
}
