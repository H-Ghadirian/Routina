import SwiftUI

struct TaskDetailEffortMetric: Identifiable {
    let title: String
    let value: String
    let systemImage: String?
    let tint: Color
    var isMuted = false

    var id: String { title }
}

struct TaskDetailEffortSummary: View {
    let isContentExpanded: Bool
    let metrics: [TaskDetailEffortMetric]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EFFORT")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            if !isContentExpanded {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 18) {
                        ForEach(metrics) { metric in
                            metricView(metric)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(metrics) { metric in
                            metricView(metric)
                        }
                    }
                }
            }
        }
    }

    private func metricView(_ metric: TaskDetailEffortMetric) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(metric.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                if let systemImage = metric.systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(metric.tint)
                }

                Text(metric.value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(metric.isMuted ? .secondary : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct TaskDetailCompactEffortRow<Actions: View>: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color
    let isValueMuted: Bool
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                compactEffortValue

                Spacer(minLength: 16)

                actions()
            }

            VStack(alignment: .leading, spacing: 10) {
                compactEffortValue
                actions()
            }
        }
        .frame(maxWidth: 720, alignment: .leading)
    }

    private var compactEffortValue: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(value)
                    .font(.caption)
                    .foregroundStyle(isValueMuted ? .secondary : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

struct TaskDetailActualTimeEditor: View {
    let currentMinutes: Int?
    @Binding var entryMinutes: Int
    let canApplyEntry: Bool
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(currentMinutes == nil ? "Log actual time" : "Add actual time")
                    .font(.headline)
                Text(
                    currentMinutes == nil
                        ? "Record time without changing Focus history."
                        : "Add this duration to the recorded total."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Stepper(
                value: $entryMinutes,
                in: TaskDetailTimeSpentPresentation.minimumMinutes...TaskDetailTimeSpentPresentation.maximumMinutes,
                step: 5
            ) {
                HStack {
                    Text("Duration")
                    Spacer()
                    Text(RoutineTimeSpentFormatting.compactMinutesText(entryMinutes))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            }

            if currentMinutes != nil {
                Text(
                    TaskDetailTimeSpentPresentation.previewText(
                        currentMinutes: currentMinutes,
                        entryMinutes: entryMinutes
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()

                Button(currentMinutes == nil ? "Log time" : "Add time", action: onApply)
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                    .disabled(!canApplyEntry)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 340)
        .padding(18)
    }
}

struct TaskDetailFocusStartEditor: View {
    @Binding var mode: TaskDetailFocusStartMode
    @Binding var countdownMinutes: Int
    let onStart: (TimeInterval) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Start focus")
                    .font(.headline)
                Text("Focus time stays separate from Actual time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("Timer", selection: $mode) {
                ForEach(TaskDetailFocusStartMode.allCases) { mode in
                    Text(mode.title)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if mode == .countdown {
                Stepper(
                    value: $countdownMinutes,
                    in: TaskDetailTimeSpentPresentation.minimumMinutes...TaskDetailTimeSpentPresentation.maximumMinutes,
                    step: 5
                ) {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(RoutineTimeSpentFormatting.compactMinutesText(countdownMinutes))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                }
            }

            HStack {
                Spacer()

                Button("Start focus") {
                    let durationSeconds =
                        mode == .countdown
                        ? TimeInterval(countdownMinutes * 60)
                        : 0
                    onStart(durationSeconds)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 340)
        .padding(18)
    }
}
