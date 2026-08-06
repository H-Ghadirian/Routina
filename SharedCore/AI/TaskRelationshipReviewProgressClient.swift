import Foundation

struct TaskRelationshipReviewProgressClient: Sendable {
    var loadFingerprints: @Sendable () -> [UUID: String]
    var saveFingerprints: @Sendable ([UUID: String]) -> Void

    static let live = TaskRelationshipReviewProgressClient(
        loadFingerprints: {
            TaskRelationshipReviewProgressStorage.load(from: SharedDefaults.app)
        },
        saveFingerprints: {
            TaskRelationshipReviewProgressStorage.save($0, to: SharedDefaults.app)
        }
    )

    static let noop = TaskRelationshipReviewProgressClient(
        loadFingerprints: { [:] },
        saveFingerprints: { _ in }
    )
}

enum TaskRelationshipReviewProgressStorage {
    static let defaultsKey = "routina.taskRelationshipReviewFingerprints.v1"

    private struct Payload: Codable {
        let version: Int
        let fingerprintsByTaskID: [String: String]
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
}
