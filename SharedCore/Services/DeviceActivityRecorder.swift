import Foundation
import SwiftData

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum DeviceActivityRecorder {
    private static let installationIDDefaultsKey = "routina.device.installationID.v1"

    @MainActor
    static func currentInstallationID(defaults: UserDefaults = SharedDefaults.app) -> String {
        if let existing = defaults.string(forKey: installationIDDefaultsKey),
           !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return existing
        }

        let installationID = UUID().uuidString
        defaults.set(installationID, forKey: installationIDDefaultsKey)
        return installationID
    }

    @MainActor
    static func currentSource(defaults: UserDefaults = SharedDefaults.app) -> RoutinaDeviceActivitySource {
        RoutinaDeviceActivitySource(
            installationID: currentInstallationID(defaults: defaults),
            displayName: currentDeviceName,
            platform: currentPlatform,
            modelName: currentModelName,
            systemName: currentSystemName,
            systemVersion: currentSystemVersion,
            appVersion: currentAppVersion,
            bundleIdentifier: Bundle.main.bundleIdentifier ?? ""
        )
    }

    @discardableResult
    @MainActor
    static func recordCurrentDeviceSession(
        in context: ModelContext,
        at date: Date = Date()
    ) -> RoutinaDeviceSession? {
        recordDeviceSession(currentSource(), in: context, at: date, saves: true)
    }

    @discardableResult
    @MainActor
    static func recordDeviceSession(
        _ source: RoutinaDeviceActivitySource,
        in context: ModelContext,
        at date: Date = Date(),
        saves: Bool = true
    ) -> RoutinaDeviceSession? {
        do {
            let session = try upsertSession(
                from: source,
                in: context,
                at: date,
                isMutation: false
            )
            if saves {
                try context.save()
            }
            return session
        } catch {
            NSLog("Device session recording failed: \(error.localizedDescription)")
            return nil
        }
    }

    @MainActor
    static func recordAction(
        _ action: RoutinaDeviceActionKind,
        entity: RoutinaDeviceActionEntity,
        entityID: UUID? = nil,
        entityTitle: String? = nil,
        details: String? = nil,
        sourceDevice: RoutinaDeviceActivitySource? = nil,
        at timestamp: Date = Date(),
        in context: ModelContext,
        saves: Bool = false
    ) {
        do {
            let source = sourceDevice ?? currentSource()
            _ = try upsertSession(
                from: source,
                in: context,
                at: timestamp,
                isMutation: true
            )
            context.insert(
                RoutinaDeviceActionLog(
                    timestamp: timestamp,
                    action: action,
                    entity: entity,
                    entityID: entityID?.uuidString ?? "",
                    entityTitle: cleanedOptional(entityTitle),
                    source: source,
                    details: cleanedOptional(details)
                )
            )
            if saves {
                try context.save()
            }
        } catch {
            NSLog("Device action recording failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    private static func upsertSession(
        from source: RoutinaDeviceActivitySource,
        in context: ModelContext,
        at date: Date,
        isMutation: Bool
    ) throws -> RoutinaDeviceSession {
        let installationID = source.installationID
        var descriptor = FetchDescriptor<RoutinaDeviceSession>(
            predicate: #Predicate { session in
                session.installationID == installationID
            }
        )
        descriptor.fetchLimit = 1

        if let session = try context.fetch(descriptor).first {
            session.update(from: source, seenAt: date, isMutation: isMutation)
            return session
        }

        let session = RoutinaDeviceSession(
            installationID: source.installationID,
            displayName: source.displayName,
            platform: source.platform,
            modelName: source.modelName,
            systemName: source.systemName,
            systemVersion: source.systemVersion,
            appVersion: source.appVersion,
            bundleIdentifier: source.bundleIdentifier,
            firstSeenAt: date,
            lastSeenAt: date,
            lastActiveAt: date,
            lastMutationAt: isMutation ? date : nil
        )
        context.insert(session)
        return session
    }

    private static func cleanedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    @MainActor
    private static var currentPlatform: RoutinaDevicePlatform {
        #if os(iOS)
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            return .iPad
        case .phone:
            return .iPhone
        default:
            return .unknown
        }
        #elseif os(macOS)
        return .mac
        #else
        return .unknown
        #endif
    }

    @MainActor
    private static var currentDeviceName: String {
        #if os(iOS)
        return UIDevice.current.name
        #elseif os(macOS)
        return Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        #else
        return currentPlatform.title
        #endif
    }

    @MainActor
    private static var currentModelName: String {
        #if os(iOS)
        return UIDevice.current.model
        #elseif os(macOS)
        return "Mac"
        #else
        return currentPlatform.title
        #endif
    }

    @MainActor
    private static var currentSystemName: String {
        #if os(iOS)
        return UIDevice.current.systemName
        #elseif os(macOS)
        return "macOS"
        #else
        return ""
        #endif
    }

    @MainActor
    private static var currentSystemVersion: String {
        #if os(iOS)
        return UIDevice.current.systemVersion
        #elseif os(macOS)
        return ProcessInfo.processInfo.operatingSystemVersionString
        #else
        return ""
        #endif
    }

    private static var currentAppVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        switch (version, build) {
        case let (.some(version), .some(build)) where !build.isEmpty:
            return "\(version) (\(build))"
        case let (.some(version), _):
            return version
        case let (_, .some(build)):
            return build
        default:
            return ""
        }
    }
}
