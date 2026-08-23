import SwiftUI

struct TaskTemporalWeightRuleEditor: View {
    @Binding var rule: RoutineTaskTemporalWeightRule?
    let importance: RoutineTaskImportance
    let urgency: RoutineTaskUrgency
    let pressure: RoutineTaskPressure
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
#if os(macOS)
        macEditor
#else
        iosEditor
#endif
    }

#if os(macOS)
    private var macEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                macTargetRow(
                    title: "Importance",
                    baseTitle: importance.title,
                    selection: macImportanceTargetBinding,
                    targets: importanceTargets,
                    optionTitle: { $0.title }
                )
                macTargetRow(
                    title: "Urgency",
                    baseTitle: urgency.title,
                    selection: macUrgencyTargetBinding,
                    targets: urgencyTargets,
                    optionTitle: { $0.title }
                )
                macTargetRow(
                    title: "Pressure",
                    baseTitle: pressure.title,
                    selection: macPressureTargetBinding,
                    targets: pressureTargets,
                    optionTitle: { $0.title }
                )
            }

            if let validRule = macValidRule {
                macTimingAndSummary(rule: validRule)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(
            accessibilityReduceMotion ? nil : .easeInOut(duration: 0.18),
            value: macValidRule != nil
        )
        .animation(
            accessibilityReduceMotion ? nil : .easeInOut(duration: 0.18),
            value: macValidRule?.curve
        )
    }

    private func macTargetRow<Option: Hashable>(
        title: String,
        baseTitle: String,
        selection: Binding<Option?>,
        targets: [Option],
        optionTitle: @escaping (Option) -> String
    ) -> some View {
        GridRow {
            Text(title)
                .font(.subheadline.weight(.medium))

            Text(baseTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Image(systemName: "arrow.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)

            Picker("\(title) target", selection: selection) {
                Text("No change")
                    .tag(Optional<Option>.none)
                ForEach(targets, id: \.self) { target in
                    Text(optionTitle(target))
                        .tag(Optional(target))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            .disabled(targets.isEmpty)
        }
    }

    private func macTimingAndSummary(rule validRule: RoutineTaskTemporalWeightRule) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text("Values change")
                    .font(.subheadline.weight(.medium))

                Picker("Change timing", selection: curveBinding) {
                    ForEach(RoutineTaskTemporalWeightCurve.allCases) { curve in
                        Text(curve.title).tag(curve)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()

                if validRule.curve == .gradual {
                    Stepper(
                        "over \(leadDaysBinding.wrappedValue) \(leadDaysBinding.wrappedValue == 1 ? "day" : "days") before due",
                        value: leadDaysBinding,
                        in: 1...RoutineTaskTemporalWeightRule.maximumLeadDays
                    )
                    .fixedSize()
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }

            if let summary = macChangeSummary(rule: validRule) {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Changed values remain until completion, then reset to the original values.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
    }

    private var macValidRule: RoutineTaskTemporalWeightRule? {
        rule?.sanitized(
            baseImportance: importance,
            baseUrgency: urgency,
            basePressure: pressure
        )
    }

    private func macChangeSummary(rule: RoutineTaskTemporalWeightRule) -> String? {
        var changes: [String] = []
        if let target = rule.importanceAtDue {
            changes.append("Importance \(importance.title) → \(target.title)")
        }
        if let target = rule.urgencyAtDue {
            changes.append("Urgency \(urgency.title) → \(target.title)")
        }
        if let target = rule.pressureAtDue {
            changes.append("Pressure \(pressure.title) → \(target.title)")
        }
        guard !changes.isEmpty else { return nil }

        let timing: String
        switch rule.curve {
        case .onDueDate:
            timing = "On the due date"
        case .gradual:
            timing = "Gradually over the \(rule.leadDays) \(rule.leadDays == 1 ? "day" : "days") before due"
        }
        return "\(timing): \(changes.joined(separator: " • "))"
    }

    private var macImportanceTargetBinding: Binding<RoutineTaskImportance?> {
        Binding(
            get: {
                guard let target = rule?.importanceAtDue,
                      importanceTargets.contains(target) else { return nil }
                return target
            },
            set: { updateMacTarget(\.importanceAtDue, to: $0) }
        )
    }

    private var macUrgencyTargetBinding: Binding<RoutineTaskUrgency?> {
        Binding(
            get: {
                guard let target = rule?.urgencyAtDue,
                      urgencyTargets.contains(target) else { return nil }
                return target
            },
            set: { updateMacTarget(\.urgencyAtDue, to: $0) }
        )
    }

    private var macPressureTargetBinding: Binding<RoutineTaskPressure?> {
        Binding(
            get: {
                guard let target = rule?.pressureAtDue,
                      pressureTargets.contains(target) else { return nil }
                return target
            },
            set: { updateMacTarget(\.pressureAtDue, to: $0) }
        )
    }

    private func updateMacTarget<Value>(
        _ keyPath: WritableKeyPath<RoutineTaskTemporalWeightRule, Value?>,
        to target: Value?
    ) {
        var updated = rule ?? RoutineTaskTemporalWeightRule()
        updated[keyPath: keyPath] = target
        rule = updated.sanitized(
            baseImportance: importance,
            baseUrgency: urgency,
            basePressure: pressure
        )
    }
#endif

    private var iosEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Change values over time", isOn: enabledBinding)

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

                Divider()
                temporalPreview
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

    private var temporalPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            previewRow(
                title: "After done",
                detail: "Next occurrence resets to Base",
                progress: 0
            )

            if rule?.curve == .gradual {
                previewRow(
                    title: "During lead window",
                    detail: "Values rise gradually",
                    progress: 0.5
                )
            } else {
                previewRow(
                    title: "Before due",
                    detail: "Values stay at Base",
                    progress: 0
                )
            }

            previewRow(
                title: "Due date",
                detail: "Due targets apply",
                progress: 1
            )
            previewRow(
                title: "After due",
                detail: "Targets remain until done",
                progress: 1
            )
        }
    }

    private func previewRow(title: String, detail: String, progress: Double) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 118, alignment: .leading)

            Spacer(minLength: 8)

            Text(previewSummary(progress: progress))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func previewSummary(progress: Double) -> String {
        let importanceValue = previewValue(
            base: importance,
            target: rule?.importanceAtDue,
            progress: progress,
            values: RoutineTaskImportance.allCases
        )
        let urgencyValue = previewValue(
            base: urgency,
            target: rule?.urgencyAtDue,
            progress: progress,
            values: RoutineTaskUrgency.allCases
        )
        let pressureValue = previewValue(
            base: pressure,
            target: rule?.pressureAtDue,
            progress: progress,
            values: RoutineTaskPressure.allCases
        )
        return "I \(importanceValue.title) • U \(urgencyValue.title) • P \(pressureValue.title)"
    }

    private func previewValue<Value: Equatable>(
        base: Value,
        target: Value?,
        progress: Double,
        values: [Value]
    ) -> Value {
        guard let target,
              let baseIndex = values.firstIndex(of: base),
              let targetIndex = values.firstIndex(of: target),
              targetIndex > baseIndex,
              progress > 0
        else { return base }

        let distance = targetIndex - baseIndex
        let level = progress >= 1
            ? distance
            : min(Int(ceil(Double(distance) * progress)), max(distance - 1, 0))
        return values[min(baseIndex + level, targetIndex)]
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
                Text("Changes over time")
                    .font(.title2.weight(.semibold))
                Text("\(task.emoji ?? "✨") \(task.name ?? "Untitled task")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
#if !os(macOS)
                Text("Base values stay saved. Now values rise toward the targets for each occurrence, then reset after completion advances the due date.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
#endif
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
                    Label("Changes over time", systemImage: "flame.fill")
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
                    Text("\(RoutineTaskTemporalWeightPresentation.changeSummary(rule: rule) ?? "Value change"): \(targetSummary)")
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
