import SwiftUI

struct TaskTemporalWeightRuleEditor: View {
    @Binding var rule: RoutineTaskTemporalWeightRule?
    let importance: RoutineTaskImportance
    let urgency: RoutineTaskUrgency
    let pressure: RoutineTaskPressure

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Use time-based values", isOn: enabledBinding)

            if rule != nil {
                Picker("Change", selection: curveBinding) {
                    ForEach(RoutineTaskTemporalWeightCurve.allCases) { curve in
                        Text(curve.title).tag(curve)
                    }
                }
                .pickerStyle(.segmented)

                if curveBinding.wrappedValue == .gradual {
                    Stepper(
                        "Lead window: \(leadDaysBinding.wrappedValue) \(leadDaysBinding.wrappedValue == 1 ? "day" : "days")",
                        value: leadDaysBinding,
                        in: 1...RoutineTaskTemporalWeightRule.maximumLeadDays
                    )
                }

                importanceTargetRow
                urgencyTargetRow
                pressureTargetRow

                if !Self.hasValidTarget(
                    rule: rule,
                    importance: importance,
                    urgency: urgency,
                    pressure: pressure
                ) {
                    Text("Choose at least one value that should rise above its Base value.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    static func hasValidTarget(
        rule: RoutineTaskTemporalWeightRule?,
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency,
        pressure: RoutineTaskPressure
    ) -> Bool {
        rule?.sanitized(
            baseImportance: importance,
            baseUrgency: urgency,
            basePressure: pressure
        ) != nil
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { rule != nil },
            set: { isEnabled in
                rule = isEnabled
                    ? (rule ?? RoutineTaskTemporalWeightRule())
                    : nil
            }
        )
    }

    private var curveBinding: Binding<RoutineTaskTemporalWeightCurve> {
        Binding(
            get: { rule?.curve ?? .onDueDate },
            set: { curve in
                var updated = rule ?? RoutineTaskTemporalWeightRule()
                updated.curve = curve
                rule = updated
            }
        )
    }

    private var leadDaysBinding: Binding<Int> {
        Binding(
            get: { rule?.leadDays ?? 7 },
            set: { leadDays in
                var updated = rule ?? RoutineTaskTemporalWeightRule()
                updated.leadDays = min(max(leadDays, 1), RoutineTaskTemporalWeightRule.maximumLeadDays)
                rule = updated
            }
        )
    }

    private var adjustsImportanceBinding: Binding<Bool> {
        Binding(
            get: {
                guard let target = rule?.importanceAtDue else { return false }
                return target.sortOrder > importance.sortOrder
            },
            set: { isEnabled in
                var updated = rule ?? RoutineTaskTemporalWeightRule()
                updated.importanceAtDue = isEnabled ? (importanceTargets.last ?? importance) : nil
                rule = updated
            }
        )
    }

    private var importanceTargetBinding: Binding<RoutineTaskImportance> {
        Binding(
            get: {
                guard let target = rule?.importanceAtDue,
                      importanceTargets.contains(target) else {
                    return importanceTargets.last ?? importance
                }
                return target
            },
            set: { target in
                var updated = rule ?? RoutineTaskTemporalWeightRule()
                updated.importanceAtDue = target
                rule = updated
            }
        )
    }

    private var adjustsUrgencyBinding: Binding<Bool> {
        Binding(
            get: {
                guard let target = rule?.urgencyAtDue else { return false }
                return target.sortOrder > urgency.sortOrder
            },
            set: { isEnabled in
                var updated = rule ?? RoutineTaskTemporalWeightRule()
                updated.urgencyAtDue = isEnabled ? (urgencyTargets.last ?? urgency) : nil
                rule = updated
            }
        )
    }

    private var urgencyTargetBinding: Binding<RoutineTaskUrgency> {
        Binding(
            get: {
                guard let target = rule?.urgencyAtDue,
                      urgencyTargets.contains(target) else {
                    return urgencyTargets.last ?? urgency
                }
                return target
            },
            set: { target in
                var updated = rule ?? RoutineTaskTemporalWeightRule()
                updated.urgencyAtDue = target
                rule = updated
            }
        )
    }

    private var adjustsPressureBinding: Binding<Bool> {
        Binding(
            get: {
                guard let target = rule?.pressureAtDue else { return false }
                return target.sortOrder > pressure.sortOrder
            },
            set: { isEnabled in
                var updated = rule ?? RoutineTaskTemporalWeightRule()
                updated.pressureAtDue = isEnabled ? (pressureTargets.last ?? pressure) : nil
                rule = updated
            }
        )
    }

    private var pressureTargetBinding: Binding<RoutineTaskPressure> {
        Binding(
            get: {
                guard let target = rule?.pressureAtDue,
                      pressureTargets.contains(target) else {
                    return pressureTargets.last ?? pressure
                }
                return target
            },
            set: { target in
                var updated = rule ?? RoutineTaskTemporalWeightRule()
                updated.pressureAtDue = target
                rule = updated
            }
        )
    }

    private var importanceTargets: [RoutineTaskImportance] {
        RoutineTaskImportance.allCases.filter { $0.sortOrder > importance.sortOrder }
    }

    private var urgencyTargets: [RoutineTaskUrgency] {
        RoutineTaskUrgency.allCases.filter { $0.sortOrder > urgency.sortOrder }
    }

    private var pressureTargets: [RoutineTaskPressure] {
        RoutineTaskPressure.allCases.filter { $0.sortOrder > pressure.sortOrder }
    }

    private var importanceTargetRow: some View {
        targetRowShell(
            title: "Importance",
            baseTitle: importance.title,
            isEnabled: adjustsImportanceBinding,
            hasTargets: !importanceTargets.isEmpty
        ) {
            Picker("Importance at due", selection: importanceTargetBinding) {
                ForEach(importanceTargets, id: \.self) { value in
                    Text(value.title).tag(value)
                }
            }
            .labelsHidden()
        }
    }

    private var urgencyTargetRow: some View {
        targetRowShell(
            title: "Urgency",
            baseTitle: urgency.title,
            isEnabled: adjustsUrgencyBinding,
            hasTargets: !urgencyTargets.isEmpty
        ) {
            Picker("Urgency at due", selection: urgencyTargetBinding) {
                ForEach(urgencyTargets, id: \.self) { value in
                    Text(value.title).tag(value)
                }
            }
            .labelsHidden()
        }
    }

    private var pressureTargetRow: some View {
        targetRowShell(
            title: "Pressure",
            baseTitle: pressure.title,
            isEnabled: adjustsPressureBinding,
            hasTargets: !pressureTargets.isEmpty
        ) {
            Picker("Pressure at due", selection: pressureTargetBinding) {
                ForEach(pressureTargets, id: \.self) { value in
                    Text(value.title).tag(value)
                }
            }
            .labelsHidden()
        }
    }

    private func targetRowShell<Content: View>(
        title: String,
        baseTitle: String,
        isEnabled: Binding<Bool>,
        hasTargets: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Toggle(isOn: isEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text("Base: \(baseTitle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!hasTargets)

            Spacer(minLength: 8)

            if hasTargets {
                content()
                    .frame(minWidth: 120)
                    .disabled(!isEnabled.wrappedValue)
            } else {
                Text("At maximum")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct TaskTemporalWeightRuleSheet: View {
    let task: RoutineTask
    let onSave: (RoutineTaskTemporalWeightRule?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftRule: RoutineTaskTemporalWeightRule?

    init(
        task: RoutineTask,
        onSave: @escaping (RoutineTaskTemporalWeightRule?) -> Void
    ) {
        self.task = task
        self.onSave = onSave
        _draftRule = State(initialValue: task.temporalWeightRule)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Time-based values")
                    .font(.title2.weight(.semibold))
                Text("\(task.emoji ?? "✨") \(task.name ?? "Untitled task")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Base values stay saved. Now values rise toward the targets for each occurrence, then reset after completion advances the due date.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TaskTemporalWeightRuleEditor(
                rule: $draftRule,
                importance: task.importance,
                urgency: task.urgency,
                pressure: task.pressure
            )

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(savedRule)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(22)
        .frame(minWidth: 360, idealWidth: 510, minHeight: 420, idealHeight: 560)
    }

    private var canSave: Bool {
        draftRule == nil || TaskTemporalWeightRuleEditor.hasValidTarget(
            rule: draftRule,
            importance: task.importance,
            urgency: task.urgency,
            pressure: task.pressure
        )
    }

    private var savedRule: RoutineTaskTemporalWeightRule? {
        RoutineTaskTemporalWeightResolver.sanitizedRule(draftRule, for: task)
    }
}

struct TaskTemporalWeightSummaryCard: View {
    let task: RoutineTask
    let referenceDate: Date
    var calendar: Calendar = .current
    var onEdit: (() -> Void)?

    var body: some View {
        if let rule = task.temporalWeightRule,
           let targetSummary = RoutineTaskTemporalWeightPresentation.targetSummary(
                rule: rule,
                importance: task.importance,
                urgency: task.urgency,
                pressure: task.pressure
           ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Label("Time-based values", systemImage: "flame.fill")
                        .font(.caption.weight(.semibold))
                    Spacer(minLength: 8)
                    if let onEdit {
                        Button("Edit", action: onEdit)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }

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
                    Text("\(RoutineTaskTemporalWeightPresentation.changeSummary(rule: rule) ?? "Time-based change"): \(targetSummary)")
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
