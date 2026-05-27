import Foundation
import SwiftData

#if os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)
import FamilyControls
import ManagedSettings
#endif

enum FocusShieldAuthorizationState: Equatable {
    case unavailable
    case notDetermined
    case denied
    case approved
}

enum FocusShieldSupport {
    static var isSupported: Bool {
        #if os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)
        true
        #else
        false
        #endif
    }

    @MainActor
    static func authorizationState() -> FocusShieldAuthorizationState {
        #if os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)
        switch AuthorizationCenter.shared.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .approved, .approvedWithDataAccess:
            return .approved
        @unknown default:
            return .denied
        }
        #else
        return .unavailable
        #endif
    }

    @MainActor
    static func requestAuthorization() async throws {
        #if os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        #endif
    }

    @MainActor
    static func syncFocusShield(using context: ModelContext) {
        #if os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)
        guard hasActiveFocusSession(in: context) else {
            clearShield()
            return
        }

        _ = applyShieldForCurrentSelection()
        #endif
    }

    @MainActor
    private static func hasActiveFocusSession(in context: ModelContext) -> Bool {
        let predicate = #Predicate<FocusSession> { session in
            session.completedAt == nil && session.abandonedAt == nil
        }
        var descriptor = FetchDescriptor<FocusSession>(predicate: predicate)
        descriptor.fetchLimit = 1

        do {
            return try context.fetch(descriptor).first != nil
        } catch {
            NSLog("Focus shield active-session check failed: \(error.localizedDescription)")
            return false
        }
    }
}

#if os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)
extension FocusShieldSupport {
    @MainActor private static let store = ManagedSettingsStore()

    static func loadSelection() -> FamilyActivitySelection {
        guard let encodedSelection = SharedDefaults.app[.appSettingFocusShieldSelection],
              let data = Data(base64Encoded: encodedSelection),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else {
            return FamilyActivitySelection()
        }

        return selection
    }

    static func saveSelection(_ selection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        SharedDefaults.app[.appSettingFocusShieldSelection] = data.base64EncodedString()
    }

    @MainActor
    static func applyShieldForCurrentSelection() -> Bool {
        guard SharedDefaults.app[.appSettingFocusShieldEnabled],
              authorizationState() == .approved else {
            clearShield()
            return false
        }

        let selection = loadSelection()
        guard !selection.routinaIsEmpty else {
            clearShield()
            return false
        }

        store.shield.applications = selection.applicationTokens.nilIfEmpty
        store.shield.webDomains = selection.webDomainTokens.nilIfEmpty
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        store.shield.webDomainCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        return true
    }

    @MainActor
    static func clearShield() {
        store.shield.applications = nil
        store.shield.webDomains = nil
        store.shield.applicationCategories = nil
        store.shield.webDomainCategories = nil
    }
}

extension FamilyActivitySelection {
    var routinaIsEmpty: Bool {
        applicationTokens.isEmpty
            && categoryTokens.isEmpty
            && webDomainTokens.isEmpty
    }

    var routinaSummaryText: String {
        var parts: [String] = []

        if !applicationTokens.isEmpty {
            parts.append(applicationTokens.count == 1 ? "1 app" : "\(applicationTokens.count) apps")
        }
        if !webDomainTokens.isEmpty {
            parts.append(webDomainTokens.count == 1 ? "1 website" : "\(webDomainTokens.count) websites")
        }
        if !categoryTokens.isEmpty {
            parts.append(categoryTokens.count == 1 ? "1 category" : "\(categoryTokens.count) categories")
        }

        return parts.isEmpty ? "No apps or websites selected" : parts.joined(separator: ", ")
    }
}

private extension Set {
    var nilIfEmpty: Set<Element>? {
        isEmpty ? nil : self
    }
}
#endif
