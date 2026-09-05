import SwiftUI

struct TaskTemporalThinkingSentenceEditor: View {
    @Binding var thinking: RoutineTaskThinkingNeeded
    let usesAfterDoneLanguage: Bool

    var body: some View {
        TaskTemporalWeightFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
            if usesAfterDoneLanguage {
                Text("After done,")
            }
            Text("Thinking is")
                .fontWeight(.medium)
            Picker("Thinking after done", selection: $thinking) {
                ForEach(RoutineTaskThinkingNeeded.allCases, id: \.self) { value in
                    Text(value.title).tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            if usesAfterDoneLanguage {
                Text("and does not change.")
            } else {
                Text(".")
            }
        }
        .font(.subheadline)
    }
}

struct TaskTemporalWeightRuleSheet: View {
    let task: RoutineTask
    let onSave:
        (
            RoutineTaskImportance,
            RoutineTaskUrgency,
            RoutineTaskPressure,
            RoutineTaskTemporalWeightRule?
        ) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftImportance: RoutineTaskImportance
    @State private var draftUrgency: RoutineTaskUrgency
    @State private var draftPressure: RoutineTaskPressure
    @State private var draftRule: RoutineTaskTemporalWeightRule?

    init(
        task: RoutineTask,
        onSave:
            @escaping (
                RoutineTaskImportance,
                RoutineTaskUrgency,
                RoutineTaskPressure,
                RoutineTaskTemporalWeightRule?
            ) -> Void
    ) {
        self.task = task
        self.onSave = onSave
        _draftImportance = State(initialValue: task.importance)
        _draftUrgency = State(initialValue: task.urgency)
        _draftPressure = State(initialValue: task.pressure)
        _draftRule = State(initialValue: task.temporalWeightRule)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Task Ladder values")
                    .font(.title2.weight(.semibold))
                Text("\(task.emoji ?? "✨") \(task.name ?? "Untitled task")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Define the value after completion and the independent due-date behavior for each metric.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TaskTemporalWeightRuleEditor(
                rule: $draftRule,
                importance: $draftImportance,
                urgency: $draftUrgency,
                pressure: $draftPressure,
                maximumBeforeDueDays: maximumBeforeDueDays
            )

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(draftImportance, draftUrgency, draftPressure, savedRule)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(minWidth: 430, idealWidth: 650, minHeight: 380, idealHeight: 520)
    }

    private var maximumBeforeDueDays: Int? {
        RoutineTaskTemporalWeightResolver.maximumBeforeDueDays(for: task.recurrenceRule)
    }

    private var savedRule: RoutineTaskTemporalWeightRule? {
        draftRule?.sanitized(
            baseImportance: draftImportance,
            baseUrgency: draftUrgency,
            basePressure: draftPressure,
            maximumBeforeDueDays: maximumBeforeDueDays
        )
    }
}

struct TaskTemporalWeightSummaryCard: View {
    let task: RoutineTask
    let referenceDate: Date
    var calendar: Calendar = .current

    var body: some View {
        let summaries = RoutineTaskTemporalWeightPresentation.metricSummaries(
            rule: task.temporalWeightRule,
            importance: task.importance,
            urgency: task.urgency,
            pressure: task.pressure,
            maximumBeforeDueDays: RoutineTaskTemporalWeightResolver.maximumBeforeDueDays(
                for: task.recurrenceRule
            )
        )

        if !summaries.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Changes over time", systemImage: "flame.fill")
                    .font(.caption.weight(.semibold))

                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        RoutineTaskTemporalWeightPresentation.baseSummary(
                            importance: task.importance,
                            urgency: task.urgency,
                            pressure: task.pressure
                        ))
                    if let nowSummary = RoutineTaskTemporalWeightPresentation.nowSummary(
                        for: task,
                        referenceDate: referenceDate,
                        calendar: calendar
                    ) {
                        Text(nowSummary)
                    }
                    ForEach(summaries, id: \.self) { summary in
                        Text(summary)
                    }
                    if let timing = RoutineTaskTemporalWeightResolver.timingLabel(
                        for: task,
                        referenceDate: referenceDate,
                        calendar: calendar
                    ) {
                        Text(timing)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.orange.opacity(0.22), lineWidth: 1)
            )
        }
    }
}

struct TaskTemporalWeightFlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        layout(subviews: subviews, width: proposal.width ?? .infinity).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = layout(subviews: subviews, width: bounds.width)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                anchor: .topLeading,
                proposal: .unspecified
            )
        }
    }

    private func layout(subviews: Subviews, width: CGFloat) -> (size: CGSize, points: [CGPoint]) {
        var points: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
            usedWidth = max(usedWidth, max(x - horizontalSpacing, 0))
        }

        return (
            CGSize(width: min(usedWidth, width), height: y + rowHeight),
            points
        )
    }
}
