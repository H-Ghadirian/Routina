import Foundation

struct HomeFlagFilterOption: Equatable, Identifiable {
    let name: String
    let allTaskCount: Int
    let routineCount: Int
    let todoCount: Int

    var id: String {
        RoutineFlag.normalized(name) ?? name
    }

    func taskCount(for taskListKind: HomeFilterTaskListKind) -> Int {
        switch taskListKind {
        case .all:
            return allTaskCount
        case .routines:
            return routineCount
        case .todos:
            return todoCount
        }
    }
}

enum HomeFlagFilterCatalog {
    private struct Counts {
        var all = 0
        var routines = 0
        var todos = 0
    }

    static func options<Display: HomeTaskListDisplay>(from displays: [Display]) -> [HomeFlagFilterOption] {
        var countsByNormalizedFlag: [String: (name: String, counts: Counts)] = [:]

        for display in displays {
            for flag in RoutineFlag.deduplicated(display.flags) {
                guard let normalizedFlag = RoutineFlag.normalized(flag) else { continue }
                var entry = countsByNormalizedFlag[normalizedFlag] ?? (flag, Counts())
                entry.counts.all += 1
                if display.isOneOffTask {
                    entry.counts.todos += 1
                } else {
                    entry.counts.routines += 1
                }
                countsByNormalizedFlag[normalizedFlag] = entry
            }
        }

        return countsByNormalizedFlag.values
            .map {
                HomeFlagFilterOption(
                    name: $0.name,
                    allTaskCount: $0.counts.all,
                    routineCount: $0.counts.routines,
                    todoCount: $0.counts.todos
                )
            }
            .sorted { lhs, rhs in
                if lhs.allTaskCount != rhs.allTaskCount {
                    return lhs.allTaskCount > rhs.allTaskCount
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }
}

enum HomeFlagFilterMutationSupport {
    static func contains(_ flag: String, in selectedFlags: Set<String>) -> Bool {
        selectedFlags.contains { RoutineFlag.contains($0, in: [flag]) }
    }

    static func toggled(_ flag: String, in selectedFlags: Set<String>) -> Set<String> {
        var updatedFlags = selectedFlags
        if let selectedFlag = updatedFlags.first(where: { RoutineFlag.contains($0, in: [flag]) }) {
            updatedFlags.remove(selectedFlag)
        } else if let cleanedFlag = RoutineFlag.cleaned(flag) {
            updatedFlags.insert(cleanedFlag)
        }
        return updatedFlags
    }
}
