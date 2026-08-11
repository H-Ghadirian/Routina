import Foundation

struct StatsFlagFilterMutation: Equatable {
    let selectedFlags: Set<String>
    let excludedFlags: Set<String>
}

enum StatsFlagFilterMutationSupport {
    static func contains(_ flag: String, in flags: Set<String>) -> Bool {
        flags.contains { RoutineFlag.contains($0, in: [flag]) }
    }

    static func toggledIncluded(
        _ flag: String,
        selectedFlags: Set<String>,
        excludedFlags: Set<String>
    ) -> StatsFlagFilterMutation {
        var selectedFlags = selectedFlags
        var excludedFlags = excludedFlags

        if let selectedFlag = selectedFlags.first(where: { RoutineFlag.contains($0, in: [flag]) }) {
            selectedFlags.remove(selectedFlag)
        } else if let cleanedFlag = RoutineFlag.cleaned(flag) {
            selectedFlags.insert(cleanedFlag)
            remove(cleanedFlag, from: &excludedFlags)
        }

        return StatsFlagFilterMutation(
            selectedFlags: selectedFlags,
            excludedFlags: excludedFlags
        )
    }

    static func toggledExcluded(
        _ flag: String,
        selectedFlags: Set<String>,
        excludedFlags: Set<String>
    ) -> StatsFlagFilterMutation {
        var selectedFlags = selectedFlags
        var excludedFlags = excludedFlags

        if let excludedFlag = excludedFlags.first(where: { RoutineFlag.contains($0, in: [flag]) }) {
            excludedFlags.remove(excludedFlag)
        } else if let cleanedFlag = RoutineFlag.cleaned(flag) {
            excludedFlags.insert(cleanedFlag)
            remove(cleanedFlag, from: &selectedFlags)
        }

        return StatsFlagFilterMutation(
            selectedFlags: selectedFlags,
            excludedFlags: excludedFlags
        )
    }

    private static func remove(_ flag: String, from flags: inout Set<String>) {
        if let existingFlag = flags.first(where: { RoutineFlag.contains($0, in: [flag]) }) {
            flags.remove(existingFlag)
        }
    }
}
