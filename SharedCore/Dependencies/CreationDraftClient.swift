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

enum CreationDraftScheduledWrite: Equatable, Sendable {
    case save(String)
    case clear
    case none
}

struct CreationDraftClient: Sendable {
    var load: @Sendable (CreationDraftKind) -> String?
    var save: @Sendable (CreationDraftKind, String?) -> Void
    var clear: @Sendable (CreationDraftKind) -> Void
    var scheduleSave: @Sendable (
        CreationDraftKind,
        @escaping @Sendable () -> CreationDraftScheduledWrite
    ) -> Void
    var cancelScheduledSave: @Sendable (CreationDraftKind) -> Void
}

extension CreationDraftClient {
    private static let autosaveScheduler = CreationDraftAutosaveScheduler()

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
        },
        scheduleSave: { kind, makeWrite in
            autosaveScheduler.schedule(kind: kind, makeWrite: makeWrite)
        },
        cancelScheduledSave: { kind in
            autosaveScheduler.cancel(kind: kind)
        }
    )

    static let noop = CreationDraftClient(
        load: { _ in nil },
        save: { _, _ in },
        clear: { _ in },
        scheduleSave: { _, _ in },
        cancelScheduledSave: { _ in }
    )
}

private final class CreationDraftAutosaveScheduler: @unchecked Sendable {
    private let queue = DispatchQueue(
        label: "com.routina.creation-draft-autosave",
        qos: .utility
    )
    private let lock = NSLock()
    private var generations: [CreationDraftKind: UInt64] = [:]

    func schedule(
        kind: CreationDraftKind,
        makeWrite: @escaping @Sendable () -> CreationDraftScheduledWrite
    ) {
        let generation = advanceGeneration(for: kind)
        queue.asyncAfter(deadline: .now() + .milliseconds(180)) { [weak self] in
            guard let self, isCurrent(generation, for: kind) else { return }
            let write = makeWrite()
            guard isCurrent(generation, for: kind) else { return }

            switch write {
            case let .save(rawValue):
                SharedDefaults.app.set(rawValue, forKey: kind.defaultsKey)
            case .clear:
                SharedDefaults.app.removeObject(forKey: kind.defaultsKey)
            case .none:
                break
            }
        }
    }

    func cancel(kind: CreationDraftKind) {
        _ = advanceGeneration(for: kind)
    }

    private func advanceGeneration(for kind: CreationDraftKind) -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        let generation = generations[kind, default: 0] &+ 1
        generations[kind] = generation
        return generation
    }

    private func isCurrent(
        _ generation: UInt64,
        for kind: CreationDraftKind
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return generations[kind] == generation
    }
}
