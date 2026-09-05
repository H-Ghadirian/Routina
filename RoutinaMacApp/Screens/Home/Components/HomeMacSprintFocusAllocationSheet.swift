import SwiftUI

struct HomeMacSprintFocusAllocationSheet: View {
    private enum ColumnFilter: String, CaseIterable, Identifiable {
        case all
        case ready
        case inProgress
        case blocked
        case done

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "All"
            case .ready: return "Ready / Paused"
            case .inProgress: return "In Progress"
            case .blocked: return "Blocked"
            case .done: return "Done"
            }
        }

        var pickerTitle: String {
            switch self {
            case .all: return "All"
            case .ready: return "Ready"
            case .inProgress: return "In Progress"
            case .blocked: return "Blocked"
            case .done: return "Done"
            }
        }

        func includes(_ state: TodoState?) -> Bool {
            switch self {
            case .all:
                return true
            case .ready:
                return state == .ready || state == .paused
            case .inProgress:
                return state == .inProgress
            case .blocked:
                return state == .blocked
            case .done:
                return state == .done
            }
        }
    }

    let session: SprintFocusSession?
    let allocationDrafts: [SprintFocusAllocationDraft]
    let onMinutesChanged: (UUID, Int) -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    let taskTitle: (UUID) -> String
    let todoState: (UUID) -> TodoState?

    @State private var columnFilter: ColumnFilter = .all

    @ViewBuilder
    var body: some View {
        if let session {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Allocate Sprint Focus")
                        .font(.title3.weight(.semibold))
                    Text(
                        "\(FocusSessionFormatting.compactDurationText(seconds: session.durationSeconds)) recorded. Assign minutes to tasks in this sprint."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                if allocationDrafts.isEmpty {
                    Text("This sprint has no tasks yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    allocationList(session: session)
                    allocationSummary(session: session)
                }

                HStack {
                    Spacer()

                    Button("Cancel", action: onCancel)
                        .keyboardShortcut(.cancelAction)

                    Button("Save", action: onSave)
                        .keyboardShortcut(.defaultAction)
                        .disabled(allocationDrafts.isEmpty)
                }
            }
            .padding(24)
            .onAppear {
                columnFilter = .all
            }
        }
    }

    private func allocationList(session: SprintFocusSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Column",
                options: ColumnFilter.allCases,
                selection: $columnFilter,
                fillsAvailableWidth: true
            ) { filter in
                Text(filter.pickerTitle)
            }
            .controlSize(.small)

            if filteredDrafts.isEmpty {
                Text("No tasks in \(columnFilter.title).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List {
                    ForEach(filteredDrafts) { draft in
                        allocationRow(draft, session: session)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private func allocationSummary(session: SprintFocusSession) -> some View {
        HStack {
            Text("Allocated")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text(
                "\(minutesText(totalAllocatedMinutes)) of \(minutesText(session.roundedDurationMinutes))"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
        }
    }

    private func allocationRow(
        _ draft: SprintFocusAllocationDraft,
        session: SprintFocusSession
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(taskTitle(draft.taskID))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(todoState(draft.taskID)?.displayTitle ?? "Sprint task")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Stepper(
                value: minutesBinding(for: draft.taskID),
                in: 0...maximumMinutes(for: draft, session: session),
                step: 1
            ) {
                Text("\(draft.minutes)m")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .frame(width: 52, alignment: .trailing)
            }
            .frame(width: 150)
        }
        .padding(.vertical, 4)
    }

    private var totalAllocatedMinutes: Int {
        allocationDrafts.reduce(0) { $0 + max(0, $1.minutes) }
    }

    private var filteredDrafts: [SprintFocusAllocationDraft] {
        allocationDrafts.filter { draft in
            columnFilter.includes(todoState(draft.taskID))
        }
    }

    private func maximumMinutes(
        for draft: SprintFocusAllocationDraft,
        session: SprintFocusSession
    ) -> Int {
        let otherAllocatedMinutes = allocationDrafts.reduce(0) { total, otherDraft in
            otherDraft.taskID == draft.taskID ? total : total + max(0, otherDraft.minutes)
        }
        return max(0, session.roundedDurationMinutes - otherAllocatedMinutes + draft.minutes)
    }

    private func minutesText(_ minutes: Int) -> String {
        minutes == 0 ? "0m" : RoutineTimeSpentFormatting.compactMinutesText(minutes)
    }

    private func minutesBinding(for taskID: UUID) -> Binding<Int> {
        Binding(
            get: { allocationDrafts.first(where: { $0.taskID == taskID })?.minutes ?? 0 },
            set: { onMinutesChanged(taskID, $0) }
        )
    }
}
