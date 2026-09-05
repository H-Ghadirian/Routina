import SwiftUI

struct StatsFlagFilterPicker: View {
    @Binding var selectedFlags: Set<String>
    @Binding var includeFlagMatchMode: RoutineTagMatchMode
    @Binding var excludedFlags: Set<String>
    @Binding var excludeFlagMatchMode: RoutineTagMatchMode
    let availableFlags: [String]

    var body: some View {
        Section {
            Picker("Show stats with", selection: $includeFlagMatchMode) {
                ForEach(RoutineTagMatchMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if selectedFlags.isEmpty {
                Text("All flags included")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedSelectedFlags, id: \.self) { flag in
                    Button("Remove \(flag)") {
                        apply(
                            StatsFlagFilterMutationSupport.toggledIncluded(
                                flag,
                                selectedFlags: selectedFlags,
                                excludedFlags: excludedFlags
                            ))
                    }
                }
            }
        } header: {
            Text("Show stats with")
        } footer: {
            Text("Only task activity with every selected Flag or any selected Flag is included.")
        }

        Section {
            Picker("Hide stats with", selection: $excludeFlagMatchMode) {
                ForEach(RoutineTagMatchMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if excludedFlags.isEmpty {
                Text("No flags excluded")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedExcludedFlags, id: \.self) { flag in
                    Button("Stop hiding \(flag)") {
                        apply(
                            StatsFlagFilterMutationSupport.toggledExcluded(
                                flag,
                                selectedFlags: selectedFlags,
                                excludedFlags: excludedFlags
                            ))
                    }
                }
            }
        } header: {
            Text("Hide stats with")
        } footer: {
            Text("Exclude every task with any selected Flag, or only tasks that have all selected Flags.")
        }

        Section {
            ForEach(availableFlags, id: \.self) { flag in
                Menu {
                    Button(isIncluded(flag) ? "Stop showing \(flag)" : "Show stats with \(flag)") {
                        apply(
                            StatsFlagFilterMutationSupport.toggledIncluded(
                                flag,
                                selectedFlags: selectedFlags,
                                excludedFlags: excludedFlags
                            ))
                    }
                    Button(isExcluded(flag) ? "Stop hiding \(flag)" : "Hide stats with \(flag)") {
                        apply(
                            StatsFlagFilterMutationSupport.toggledExcluded(
                                flag,
                                selectedFlags: selectedFlags,
                                excludedFlags: excludedFlags
                            ))
                    }
                    if isIncluded(flag) || isExcluded(flag) {
                        Divider()
                        Button("Clear \(flag) filter", role: .destructive) {
                            if isIncluded(flag) {
                                apply(
                                    StatsFlagFilterMutationSupport.toggledIncluded(
                                        flag,
                                        selectedFlags: selectedFlags,
                                        excludedFlags: excludedFlags
                                    ))
                            } else {
                                apply(
                                    StatsFlagFilterMutationSupport.toggledExcluded(
                                        flag,
                                        selectedFlags: selectedFlags,
                                        excludedFlags: excludedFlags
                                    ))
                            }
                        }
                    }
                } label: {
                    Label(flag, systemImage: statusIcon(for: flag))
                }
            }
        } header: {
            Text("All Flags")
        }
    }

    private var sortedSelectedFlags: [String] {
        selectedFlags.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var sortedExcludedFlags: [String] {
        excludedFlags.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func isIncluded(_ flag: String) -> Bool {
        StatsFlagFilterMutationSupport.contains(flag, in: selectedFlags)
    }

    private func isExcluded(_ flag: String) -> Bool {
        StatsFlagFilterMutationSupport.contains(flag, in: excludedFlags)
    }

    private func statusIcon(for flag: String) -> String {
        if isIncluded(flag) { return "checkmark.circle.fill" }
        if isExcluded(flag) { return "minus.circle.fill" }
        return "flag"
    }

    private func apply(_ mutation: StatsFlagFilterMutation) {
        selectedFlags = mutation.selectedFlags
        excludedFlags = mutation.excludedFlags
    }
}
