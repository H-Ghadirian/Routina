import Foundation
import SwiftData

enum RoutinaDevicePlatform: String, Codable, CaseIterable, Equatable, Sendable {
    case iPhone
    case iPad
    case mac
    case appleWatch
    case unknown

    var title: String {
        switch self {
        case .iPhone:
            return "iPhone"
        case .iPad:
            return "iPad"
        case .mac:
            return "Mac"
        case .appleWatch:
            return "Apple Watch"
        case .unknown:
            return "Device"
        }
    }

    var systemImage: String {
        switch self {
        case .iPhone:
            return "iphone"
        case .iPad:
            return "ipad"
        case .mac:
            return "macbook.and.iphone"
        case .appleWatch:
            return "applewatch"
        case .unknown:
            return "display"
        }
    }
}

enum RoutinaDeviceActionKind: String, Codable, Equatable, Sendable {
    case created
    case updated
    case deleted
    case completed
    case canceled
    case missed
    case started
    case ended
    case paused
    case resumed
    case snoozed
}

enum RoutinaDeviceActionEntity: String, Codable, Equatable, Sendable {
    case task
    case routineLog
    case place
    case placeCheckIn
    case focusSession
    case sleepSession
    case dayPlan
    case goal
    case tag
    case attachment
    case unknown
}

struct RoutinaDeviceActivitySource: Equatable, Sendable {
    var installationID: String
    var displayName: String
    var platform: RoutinaDevicePlatform
    var modelName: String
    var systemName: String
    var systemVersion: String
    var appVersion: String
    var bundleIdentifier: String

    init(
        installationID: String,
        displayName: String,
        platform: RoutinaDevicePlatform,
        modelName: String,
        systemName: String,
        systemVersion: String,
        appVersion: String,
        bundleIdentifier: String
    ) {
        self.installationID = Self.cleaned(installationID, fallback: UUID().uuidString)
        self.displayName = Self.cleaned(displayName, fallback: platform.title)
        self.platform = platform
        self.modelName = Self.cleaned(modelName, fallback: platform.title)
        self.systemName = Self.cleaned(systemName, fallback: platform.title)
        self.systemVersion = Self.cleaned(systemVersion, fallback: "")
        self.appVersion = Self.cleaned(appVersion, fallback: "")
        self.bundleIdentifier = Self.cleaned(bundleIdentifier, fallback: "")
    }

    init?(payload: [String: Any]?) {
        guard let payload,
              let installationID = payload["installationID"] as? String,
              !installationID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        let platformRawValue = payload["platform"] as? String ?? RoutinaDevicePlatform.unknown.rawValue
        let platform = RoutinaDevicePlatform(rawValue: platformRawValue) ?? .unknown
        self.init(
            installationID: installationID,
            displayName: payload["displayName"] as? String ?? platform.title,
            platform: platform,
            modelName: payload["modelName"] as? String ?? platform.title,
            systemName: payload["systemName"] as? String ?? platform.title,
            systemVersion: payload["systemVersion"] as? String ?? "",
            appVersion: payload["appVersion"] as? String ?? "",
            bundleIdentifier: payload["bundleIdentifier"] as? String ?? ""
        )
    }

    var payload: [String: Any] {
        [
            "installationID": installationID,
            "displayName": displayName,
            "platform": platform.rawValue,
            "modelName": modelName,
            "systemName": systemName,
            "systemVersion": systemVersion,
            "appVersion": appVersion,
            "bundleIdentifier": bundleIdentifier
        ]
    }

    private static func cleaned(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

struct RoutinaDeviceSessionSummary: Equatable, Identifiable, Sendable {
    var id: UUID
    var installationID: String
    var displayName: String
    var platform: RoutinaDevicePlatform
    var modelName: String
    var systemName: String
    var systemVersion: String
    var appVersion: String
    var firstSeenAt: Date
    var lastSeenAt: Date
    var lastActiveAt: Date
    var lastMutationAt: Date?
    var isCurrentDevice: Bool
}

@Model
final class RoutinaDeviceSession {
    var id: UUID = UUID()
    var installationID: String = ""
    var displayName: String = ""
    var platformRawValue: String = RoutinaDevicePlatform.unknown.rawValue
    var modelName: String = ""
    var systemName: String = ""
    var systemVersion: String = ""
    var appVersion: String = ""
    var bundleIdentifier: String = ""
    var firstSeenAt: Date = Date()
    var lastSeenAt: Date = Date()
    var lastActiveAt: Date = Date()
    var lastMutationAt: Date?

    var platform: RoutinaDevicePlatform {
        get { RoutinaDevicePlatform(rawValue: platformRawValue) ?? .unknown }
        set { platformRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        installationID: String,
        displayName: String,
        platform: RoutinaDevicePlatform,
        modelName: String,
        systemName: String,
        systemVersion: String,
        appVersion: String,
        bundleIdentifier: String,
        firstSeenAt: Date = Date(),
        lastSeenAt: Date = Date(),
        lastActiveAt: Date = Date(),
        lastMutationAt: Date? = nil
    ) {
        self.id = id
        self.installationID = installationID
        self.displayName = displayName
        self.platformRawValue = platform.rawValue
        self.modelName = modelName
        self.systemName = systemName
        self.systemVersion = systemVersion
        self.appVersion = appVersion
        self.bundleIdentifier = bundleIdentifier
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.lastActiveAt = lastActiveAt
        self.lastMutationAt = lastMutationAt
    }

    func update(
        from source: RoutinaDeviceActivitySource,
        seenAt: Date,
        isMutation: Bool
    ) {
        installationID = source.installationID
        displayName = source.displayName
        platform = source.platform
        modelName = source.modelName
        systemName = source.systemName
        systemVersion = source.systemVersion
        appVersion = source.appVersion
        bundleIdentifier = source.bundleIdentifier
        lastSeenAt = seenAt
        lastActiveAt = seenAt
        if isMutation {
            lastMutationAt = seenAt
        }
    }

    func summary(currentInstallationID: String) -> RoutinaDeviceSessionSummary {
        RoutinaDeviceSessionSummary(
            id: id,
            installationID: installationID,
            displayName: displayName,
            platform: platform,
            modelName: modelName,
            systemName: systemName,
            systemVersion: systemVersion,
            appVersion: appVersion,
            firstSeenAt: firstSeenAt,
            lastSeenAt: lastSeenAt,
            lastActiveAt: lastActiveAt,
            lastMutationAt: lastMutationAt,
            isCurrentDevice: installationID == currentInstallationID
        )
    }
}

@Model
final class RoutinaDeviceActionLog {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var actionRawValue: String = RoutinaDeviceActionKind.updated.rawValue
    var entityRawValue: String = RoutinaDeviceActionEntity.unknown.rawValue
    var entityID: String = ""
    var entityTitle: String?
    var deviceInstallationID: String = ""
    var deviceDisplayName: String = ""
    var devicePlatformRawValue: String = RoutinaDevicePlatform.unknown.rawValue
    var deviceModelName: String = ""
    var systemName: String = ""
    var systemVersion: String = ""
    var appVersion: String = ""
    var details: String?

    var action: RoutinaDeviceActionKind {
        get { RoutinaDeviceActionKind(rawValue: actionRawValue) ?? .updated }
        set { actionRawValue = newValue.rawValue }
    }

    var entity: RoutinaDeviceActionEntity {
        get { RoutinaDeviceActionEntity(rawValue: entityRawValue) ?? .unknown }
        set { entityRawValue = newValue.rawValue }
    }

    var devicePlatform: RoutinaDevicePlatform {
        get { RoutinaDevicePlatform(rawValue: devicePlatformRawValue) ?? .unknown }
        set { devicePlatformRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        action: RoutinaDeviceActionKind,
        entity: RoutinaDeviceActionEntity,
        entityID: String,
        entityTitle: String? = nil,
        source: RoutinaDeviceActivitySource,
        details: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.actionRawValue = action.rawValue
        self.entityRawValue = entity.rawValue
        self.entityID = entityID
        self.entityTitle = entityTitle
        self.deviceInstallationID = source.installationID
        self.deviceDisplayName = source.displayName
        self.devicePlatformRawValue = source.platform.rawValue
        self.deviceModelName = source.modelName
        self.systemName = source.systemName
        self.systemVersion = source.systemVersion
        self.appVersion = source.appVersion
        self.details = details
    }
}
