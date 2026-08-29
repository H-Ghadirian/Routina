import SwiftUI

struct TaskLadderEntryWindowSummary: View {
    let task: RoutineTask

    var body: some View {
        if let summary = RoutineTaskLadderEntryPresentation.detailSummary(for: task) {
            Label(summary, systemImage: "list.number")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct TaskLadderEntryWindowEditor: View {
    @Binding var window: RoutineTaskLadderEntryWindow
    let maximumBeforeDueDays: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TaskTemporalWeightFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                Text("Appears in Task Ladder")
                    .fontWeight(.medium)

                Picker("Task Ladder entry window", selection: modeBinding) {
                    ForEach(RoutineTaskLadderEntryWindowMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()

                if case .beforeDue = window {
                    Text("starting")

                    Picker("Days before due", selection: daysBinding) {
                        ForEach(1...maximumDays, id: \.self) { days in
                            Text("\(days) \(days == 1 ? "day" : "days")").tag(days)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()

                    Text("before due")
                }

                Text(".")
            }
            .font(.subheadline)

            if window != .throughoutCycle {
                Text("This controls when the task competes in Task Ladder. Search and early completion remain available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var maximumDays: Int {
        min(
            max(maximumBeforeDueDays ?? RoutineTaskTemporalWeightRule.maximumTransitionDays, 1),
            RoutineTaskTemporalWeightRule.maximumTransitionDays
        )
    }

    private var modeBinding: Binding<RoutineTaskLadderEntryWindowMode> {
        Binding(
            get: { window.mode },
            set: { mode in
                switch mode {
                case .throughoutCycle:
                    window = .throughoutCycle
                case .beforeDue:
                    window = .beforeDue(
                        days: min(
                            RoutineTaskLadderEntryWindow.defaultBeforeDueDays,
                            maximumDays
                        )
                    )
                case .onDueDate:
                    window = .onDueDate
                }
            }
        )
    }

    private var daysBinding: Binding<Int> {
        Binding(
            get: {
                guard case let .beforeDue(days) = window else {
                    return min(RoutineTaskLadderEntryWindow.defaultBeforeDueDays, maximumDays)
                }
                return min(max(days, 1), maximumDays)
            },
            set: { window = .beforeDue(days: min(max($0, 1), maximumDays)) }
        )
    }
}

struct TaskTemporalWeightRuleEditor: View {
    @Binding var rule: RoutineTaskTemporalWeightRule?
    @Binding var importance: RoutineTaskImportance
    @Binding var urgency: RoutineTaskUrgency
    @Binding var pressure: RoutineTaskPressure
    let allowsTemporalChanges: Bool
    let maximumBeforeDueDays: Int?
    let usesAfterDoneLanguage: Bool

    init(
        rule: Binding<RoutineTaskTemporalWeightRule?>,
        importance: Binding<RoutineTaskImportance>,
        urgency: Binding<RoutineTaskUrgency>,
        pressure: Binding<RoutineTaskPressure>,
        allowsTemporalChanges: Bool = true,
        maximumBeforeDueDays: Int? = nil,
        usesAfterDoneLanguage: Bool = true
    ) {
        _rule = rule
        _importance = importance
        _urgency = urgency
        _pressure = pressure
        self.allowsTemporalChanges = allowsTemporalChanges
        self.maximumBeforeDueDays = maximumBeforeDueDays
        self.usesAfterDoneLanguage = usesAfterDoneLanguage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            metricSentence(
                title: "Importance",
                base: importanceBinding,
                values: RoutineTaskImportance.allCases,
                policy: importancePolicyBinding,
                titleForValue: { $0.title },
                sortOrder: { $0.sortOrder }
            )

            metricSentence(
                title: "Urgency",
                base: urgencyBinding,
                values: RoutineTaskUrgency.allCases,
                policy: urgencyPolicyBinding,
                titleForValue: { $0.title },
                sortOrder: { $0.sortOrder }
            )

            metricSentence(
                title: "Pressure",
                base: pressureBinding,
                values: RoutineTaskPressure.allCases,
                policy: pressurePolicyBinding,
                titleForValue: { $0.title },
                sortOrder: { $0.sortOrder }
            )

            if allowsTemporalChanges, rule?.sanitized != nil {
                Text("After completion, the next occurrence resets each changing metric to its After done value.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    static func hasValidTarget(
        rule: RoutineTaskTemporalWeightRule?,
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency,
        pressure: RoutineTaskPressure,
        maximumBeforeDueDays: Int? = nil
    ) -> Bool {
        rule?.sanitized(
            baseImportance: importance,
            baseUrgency: urgency,
            basePressure: pressure,
            maximumBeforeDueDays: maximumBeforeDueDays
        ) != nil
    }

    @ViewBuilder
    private func metricSentence<Value>(
        title: String,
        base: Binding<Value>,
        values: [Value],
        policy: Binding<RoutineTaskTemporalWeightPolicy<Value>?>,
        titleForValue: @escaping (Value) -> String,
        sortOrder: @escaping (Value) -> Int
    ) -> some View where Value: Codable & Equatable & Hashable & Sendable {
        let targets = values.filter { sortOrder($0) > sortOrder(base.wrappedValue) }
        let configuredPolicy = policy.wrappedValue

        VStack(alignment: .leading, spacing: 5) {
            TaskTemporalWeightFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                if usesAfterDoneLanguage {
                    Text("After done,")
                }

                Text(title)
                    .fontWeight(.medium)

                Text("is")

                Picker("\(title) after done", selection: base) {
                    ForEach(values, id: \.self) { value in
                        Text(titleForValue(value)).tag(value)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()

                if allowsTemporalChanges {
                    Text("and")

                    Picker("Whether \(title.lowercased()) changes", selection: changesBinding(policy: policy, targets: targets)) {
                        Text("does not change").tag(false)
                        Text("changes").tag(true)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                    .disabled(targets.isEmpty)

                    if configuredPolicy != nil, !targets.isEmpty {
                        Picker("How \(title.lowercased()) changes", selection: timingBinding(policy: policy)) {
                            ForEach(RoutineTaskTemporalWeightTiming.allCases) { timing in
                                Text(timing.title).tag(timing)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()

                        switch configuredPolicy?.timing {
                        case .onDueDate:
                            Text("to")
                            targetPicker(
                                title: title,
                                targets: targets,
                                policy: policy,
                                titleForValue: titleForValue
                            )

                        case .gradualBeforeDue:
                            Text("to")
                            targetPicker(
                                title: title,
                                targets: targets,
                                policy: policy,
                                titleForValue: titleForValue
                            )
                            Text("over")
                            daysPicker(
                                title: "\(title) days before due",
                                policy: policy,
                                maximum: beforeDueMaximum
                            )
                            Text("before due")

                        case .gradualWhileOverdue:
                            Text("toward")
                            targetPicker(
                                title: title,
                                targets: targets,
                                policy: policy,
                                titleForValue: titleForValue
                            )
                            Text("one level every")
                            daysPicker(
                                title: "\(title) overdue interval",
                                policy: policy,
                                maximum: RoutineTaskTemporalWeightRule.maximumTransitionDays
                            )
                            Text("overdue")

                        case nil:
                            EmptyView()
                        }
                    }
                }

                Text(".")
            }
            .font(.subheadline)

            if configuredPolicy?.timing == .gradualWhileOverdue {
                Text("On the due date, \(title.lowercased()) is still \(titleForValue(base.wrappedValue)).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func targetPicker<Value>(
        title: String,
        targets: [Value],
        policy: Binding<RoutineTaskTemporalWeightPolicy<Value>?>,
        titleForValue: @escaping (Value) -> String
    ) -> some View where Value: Codable & Equatable & Hashable & Sendable {
        Picker("\(title) target", selection: targetBinding(policy: policy, targets: targets)) {
            ForEach(targets, id: \.self) { value in
                Text(titleForValue(value)).tag(value)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .fixedSize()
    }

    private func daysPicker<Value>(
        title: String,
        policy: Binding<RoutineTaskTemporalWeightPolicy<Value>?>,
        maximum: Int
    ) -> some View where Value: Codable & Equatable & Hashable & Sendable {
        Picker(title, selection: daysBinding(policy: policy, maximum: maximum)) {
            ForEach(1...max(maximum, 1), id: \.self) { days in
                Text("\(days) \(days == 1 ? "day" : "days")").tag(days)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .fixedSize()
    }

    private var importanceBinding: Binding<RoutineTaskImportance> {
        Binding(
            get: { importance },
            set: { value in
                importance = value
                sanitizeRule()
            }
        )
    }

    private var urgencyBinding: Binding<RoutineTaskUrgency> {
        Binding(
            get: { urgency },
            set: { value in
                urgency = value
                sanitizeRule()
            }
        )
    }

    private var pressureBinding: Binding<RoutineTaskPressure> {
        Binding(
            get: { pressure },
            set: { value in
                pressure = value
                sanitizeRule()
            }
        )
    }

    private var importancePolicyBinding: Binding<RoutineTaskTemporalWeightPolicy<RoutineTaskImportance>?> {
        policyBinding(\.importance)
    }

    private var urgencyPolicyBinding: Binding<RoutineTaskTemporalWeightPolicy<RoutineTaskUrgency>?> {
        policyBinding(\.urgency)
    }

    private var pressurePolicyBinding: Binding<RoutineTaskTemporalWeightPolicy<RoutineTaskPressure>?> {
        policyBinding(\.pressure)
    }

    private func policyBinding<Value>(
        _ keyPath: WritableKeyPath<RoutineTaskTemporalWeightRule, RoutineTaskTemporalWeightPolicy<Value>?>
    ) -> Binding<RoutineTaskTemporalWeightPolicy<Value>?>
    where Value: Codable & Equatable & Hashable & Sendable {
        Binding(
            get: { rule?[keyPath: keyPath] },
            set: { policy in
                var updated = rule ?? RoutineTaskTemporalWeightRule()
                updated[keyPath: keyPath] = policy
                rule = updated.sanitized(
                    baseImportance: importance,
                    baseUrgency: urgency,
                    basePressure: pressure,
                    maximumBeforeDueDays: maximumBeforeDueDays
                )
            }
        )
    }

    private func changesBinding<Value>(
        policy: Binding<RoutineTaskTemporalWeightPolicy<Value>?>,
        targets: [Value]
    ) -> Binding<Bool> where Value: Codable & Equatable & Hashable & Sendable {
        Binding(
            get: { policy.wrappedValue != nil },
            set: { changes in
                guard changes, let target = targets.last else {
                    policy.wrappedValue = nil
                    return
                }
                policy.wrappedValue = policy.wrappedValue
                    ?? RoutineTaskTemporalWeightPolicy(target: target)
            }
        )
    }

    private func timingBinding<Value>(
        policy: Binding<RoutineTaskTemporalWeightPolicy<Value>?>
    ) -> Binding<RoutineTaskTemporalWeightTiming>
    where Value: Codable & Equatable & Hashable & Sendable {
        Binding(
            get: { policy.wrappedValue?.timing ?? .onDueDate },
            set: { timing in
                guard var updated = policy.wrappedValue else { return }
                updated.timing = timing
                if timing == .onDueDate {
                    updated.days = 1
                } else if timing == .gradualBeforeDue {
                    updated.days = min(max(updated.days, 1), beforeDueMaximum)
                } else {
                    updated.days = max(updated.days, 1)
                }
                policy.wrappedValue = updated
            }
        )
    }

    private func targetBinding<Value>(
        policy: Binding<RoutineTaskTemporalWeightPolicy<Value>?>,
        targets: [Value]
    ) -> Binding<Value> where Value: Codable & Equatable & Hashable & Sendable {
        Binding(
            get: {
                guard let target = policy.wrappedValue?.target,
                      targets.contains(target) else {
                    return targets.last!
                }
                return target
            },
            set: { target in
                guard var updated = policy.wrappedValue else { return }
                updated.target = target
                policy.wrappedValue = updated
            }
        )
    }

    private func daysBinding<Value>(
        policy: Binding<RoutineTaskTemporalWeightPolicy<Value>?>,
        maximum: Int
    ) -> Binding<Int> where Value: Codable & Equatable & Hashable & Sendable {
        Binding(
            get: { min(max(policy.wrappedValue?.days ?? 1, 1), max(maximum, 1)) },
            set: { days in
                guard var updated = policy.wrappedValue else { return }
                updated.days = min(max(days, 1), max(maximum, 1))
                policy.wrappedValue = updated
            }
        )
    }

    private var beforeDueMaximum: Int {
        min(
            max(maximumBeforeDueDays ?? RoutineTaskTemporalWeightRule.maximumTransitionDays, 1),
            RoutineTaskTemporalWeightRule.maximumTransitionDays
        )
    }

    private func sanitizeRule() {
        rule = rule?.sanitized(
            baseImportance: importance,
            baseUrgency: urgency,
            basePressure: pressure,
            maximumBeforeDueDays: maximumBeforeDueDays
        )
    }
}

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
    let onSave: (
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
        onSave: @escaping (
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
                    Text(RoutineTaskTemporalWeightPresentation.baseSummary(
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

private struct TaskTemporalWeightFlowLayout: Layout {
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
