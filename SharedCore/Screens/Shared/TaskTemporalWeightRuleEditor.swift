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
                Text("This controls when the task competes in Task Ladder. Search and completion remain available.")
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
                policy.wrappedValue =
                    policy.wrappedValue
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
                guard let fallbackTarget = targets.last else {
                    preconditionFailure("Temporal weight target choices must not be empty")
                }
                guard let target = policy.wrappedValue?.target,
                    targets.contains(target)
                else {
                    return fallbackTarget
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
