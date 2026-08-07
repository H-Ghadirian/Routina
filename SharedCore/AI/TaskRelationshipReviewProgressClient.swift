import Foundation

/// Device-local negative feedback for a suggested relationship. The record is
/// valid only while both bounded task summaries are unchanged.
struct TaskRelationshipReviewDismissal: Codable, Equatable, Sendable {
    let firstTaskID: UUID
    let firstTaskFingerprint: String
    let secondTaskID: UUID
    let secondTaskFingerprint: String
    let dismissedAt: Date

    init(
        sourceTaskID: UUID,
        sourceTaskFingerprint: String,
        targetTaskID: UUID,
        targetTaskFingerprint: String,
        dismissedAt: Date
    ) {
        if sourceTaskID.uuidString.localizedCaseInsensitiveCompare(targetTaskID.uuidString)
            != .orderedDescending {
            firstTaskID = sourceTaskID
            firstTaskFingerprint = sourceTaskFingerprint
            secondTaskID = targetTaskID
            secondTaskFingerprint = targetTaskFingerprint
        } else {
            firstTaskID = targetTaskID
            firstTaskFingerprint = targetTaskFingerprint
            secondTaskID = sourceTaskID
            secondTaskFingerprint = sourceTaskFingerprint
        }
        self.dismissedAt = dismissedAt
    }

    var pairKey: String {
        Self.pairKey(firstTaskID, secondTaskID)
    }

    static func pairKey(_ firstTaskID: UUID, _ secondTaskID: UUID) -> String {
        [firstTaskID.uuidString.lowercased(), secondTaskID.uuidString.lowercased()]
            .sorted()
            .joined(separator: "|")
    }

    func matches(
        currentFingerprints: [UUID: String]
    ) -> Bool {
        currentFingerprints[firstTaskID] == firstTaskFingerprint
            && currentFingerprints[secondTaskID] == secondTaskFingerprint
    }

    func matches(fingerprintFor: (UUID) -> String?) -> Bool {
        fingerprintFor(firstTaskID) == firstTaskFingerprint
            && fingerprintFor(secondTaskID) == secondTaskFingerprint
    }

    func otherTaskID(for taskID: UUID) -> UUID? {
        if taskID == firstTaskID {
            return secondTaskID
        }
        if taskID == secondTaskID {
            return firstTaskID
        }
        return nil
    }
}

struct TaskRelationshipReviewProgressClient: Sendable {
    var loadFingerprints: @Sendable () -> [UUID: String]
    var saveFingerprints: @Sendable ([UUID: String]) -> Void
    var loadDismissals: @Sendable () -> [TaskRelationshipReviewDismissal] = { [] }
    var saveDismissals: @Sendable ([TaskRelationshipReviewDismissal]) -> Void = { _ in }

    static let live = TaskRelationshipReviewProgressClient(
        loadFingerprints: {
            TaskRelationshipReviewProgressStorage.load(from: SharedDefaults.app)
        },
        saveFingerprints: {
            TaskRelationshipReviewProgressStorage.save($0, to: SharedDefaults.app)
        },
        loadDismissals: {
            TaskRelationshipReviewProgressStorage.loadDismissals(from: SharedDefaults.app)
        },
        saveDismissals: {
            TaskRelationshipReviewProgressStorage.saveDismissals($0, to: SharedDefaults.app)
        }
    )

    static let noop = TaskRelationshipReviewProgressClient(
        loadFingerprints: { [:] },
        saveFingerprints: { _ in },
        loadDismissals: { [] },
        saveDismissals: { _ in }
    )
}

enum TaskRelationshipReviewProgressStorage {
    static let defaultsKey = "routina.taskRelationshipReviewFingerprints.v1"
    static let dismissalsDefaultsKey = "routina.taskRelationshipReviewDismissals.v1"

    private struct Payload: Codable {
        let version: Int
        let fingerprintsByTaskID: [String: String]
    }

    private struct DismissalsPayload: Codable {
        let version: Int
        let dismissals: [TaskRelationshipReviewDismissal]
    }

    static func load(from defaults: UserDefaults) -> [UUID: String] {
        guard let data = defaults.data(forKey: defaultsKey),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.version == 1 else {
            return [:]
        }
        return Dictionary(
            uniqueKeysWithValues: payload.fingerprintsByTaskID.compactMap { rawTaskID, fingerprint in
                guard let taskID = UUID(uuidString: rawTaskID), !fingerprint.isEmpty else {
                    return nil
                }
                return (taskID, fingerprint)
            }
        )
    }

    static func save(_ fingerprints: [UUID: String], to defaults: UserDefaults) {
        let entries: [(String, String)] = fingerprints.compactMap { taskID, fingerprint in
            guard !fingerprint.isEmpty else { return nil }
            return (taskID.uuidString.lowercased(), fingerprint)
        }
        let sanitized = Dictionary(uniqueKeysWithValues: entries)
        let payload = Payload(version: 1, fingerprintsByTaskID: sanitized)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(payload) else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    static func loadDismissals(from defaults: UserDefaults) -> [TaskRelationshipReviewDismissal] {
        guard let data = defaults.data(forKey: dismissalsDefaultsKey),
              let payload = try? JSONDecoder().decode(DismissalsPayload.self, from: data),
              payload.version == 1 else {
            return []
        }
        return sanitizedDismissals(payload.dismissals)
    }

    static func saveDismissals(
        _ dismissals: [TaskRelationshipReviewDismissal],
        to defaults: UserDefaults
    ) {
        let payload = DismissalsPayload(
            version: 1,
            dismissals: sanitizedDismissals(dismissals)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(payload) else { return }
        defaults.set(data, forKey: dismissalsDefaultsKey)
    }

    private static func sanitizedDismissals(
        _ dismissals: [TaskRelationshipReviewDismissal]
    ) -> [TaskRelationshipReviewDismissal] {
        let latestDismissalByPairKey = dismissals.reduce(into: [String: TaskRelationshipReviewDismissal]()) {
            result,
            dismissal in
            guard dismissal.firstTaskID != dismissal.secondTaskID,
                  !dismissal.firstTaskFingerprint.isEmpty,
                  !dismissal.secondTaskFingerprint.isEmpty else {
                return
            }
            if let existing = result[dismissal.pairKey], existing.dismissedAt >= dismissal.dismissedAt {
                return
            }
            result[dismissal.pairKey] = dismissal
        }
        return latestDismissalByPairKey.values.sorted { lhs, rhs in
            lhs.pairKey < rhs.pairKey
        }
    }
}
