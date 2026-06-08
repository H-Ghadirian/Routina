import Foundation

enum CreationDraftKind: String, CaseIterable, Sendable {
    case task
    case goal
    case note
    case emotion
    case event

    var defaultsKey: String {
        "routina.creationDraft.\(rawValue).v1"
    }
}

struct CreationDraftClient: Sendable {
    var load: @Sendable (CreationDraftKind) -> String?
    var save: @Sendable (CreationDraftKind, String?) -> Void
    var clear: @Sendable (CreationDraftKind) -> Void
}

extension CreationDraftClient {
    static let live = CreationDraftClient(
        load: { kind in
            SharedDefaults.app.string(forKey: kind.defaultsKey)
        },
        save: { kind, rawValue in
            if let rawValue {
                SharedDefaults.app.set(rawValue, forKey: kind.defaultsKey)
            } else {
                SharedDefaults.app.removeObject(forKey: kind.defaultsKey)
            }
        },
        clear: { kind in
            SharedDefaults.app.removeObject(forKey: kind.defaultsKey)
        }
    )

    static let noop = CreationDraftClient(
        load: { _ in nil },
        save: { _, _ in },
        clear: { _ in }
    )
}
