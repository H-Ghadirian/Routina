import SwiftUI

struct TaskFormDurationEntry: View {
    let title: String
    @Binding var minutes: Int
    let bounds: ClosedRange<Int>
    let presets: [TaskFormDurationPreset]
    var showsFineTuning = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Text(TaskFormPresentation.estimatedDurationLabel(for: minutes))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            HStack(alignment: .top, spacing: 10) {
                durationNumberField(title: "Hours", value: hoursBinding)
                durationNumberField(title: "Minutes", value: minuteRemainderBinding)
            }

            if !visiblePresets.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(visiblePresets) { preset in
                            Button(preset.label) {
                                minutes = TaskFormDurationEntryPresentation.clamped(
                                    preset.minutes,
                                    bounds: bounds
                                )
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(preset.minutes == minutes ? Color.accentColor : Color.secondary)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }

            if showsFineTuning {
                Stepper(value: durationBinding, in: bounds, step: 5) {
                    Text("Adjust by 5 minutes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .fixedSize()
            }
        }
    }

    private var visiblePresets: [TaskFormDurationPreset] {
        presets.filter { bounds.contains($0.minutes) }
    }

    private var durationBinding: Binding<Int> {
        Binding(
            get: { TaskFormDurationEntryPresentation.clamped(minutes, bounds: bounds) },
            set: { minutes = TaskFormDurationEntryPresentation.clamped($0, bounds: bounds) }
        )
    }

    private var hoursBinding: Binding<Int> {
        Binding(
            get: { TaskFormDurationEntryPresentation.hours(for: minutes) },
            set: { newHours in
                minutes = TaskFormDurationEntryPresentation.combinedMinutes(
                    hours: newHours,
                    minuteRemainder: TaskFormDurationEntryPresentation.minuteRemainder(for: minutes),
                    bounds: bounds
                )
            }
        )
    }

    private var minuteRemainderBinding: Binding<Int> {
        Binding(
            get: { TaskFormDurationEntryPresentation.minuteRemainder(for: minutes) },
            set: { newMinutes in
                minutes = TaskFormDurationEntryPresentation.combinedMinutes(
                    hours: TaskFormDurationEntryPresentation.hours(for: minutes),
                    minuteRemainder: newMinutes,
                    bounds: bounds
                )
            }
        )
    }

    private func durationNumberField(title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("0", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 72)
                .durationEntryKeyboard()
                .accessibilityLabel(title)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private extension View {
    @ViewBuilder
    func durationEntryKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.numberPad)
        #else
        self
        #endif
    }
}
