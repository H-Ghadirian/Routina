import SwiftData
import SwiftUI

struct TaskDetailDoneOccurrenceSection: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    let task: RoutineTask
    let date: Date
    let occurrence: DayPlanDoneTaskOccurrence
    @State private var startMinute: Int
    @State private var durationMinutes: Int
    @State private var hasSpecificTime: Bool
    @State private var feedbackMessage: String?
    @State private var didSave = false

    private let durationPresets = [
        TaskFormDurationPreset(minutes: 15, label: "15m"),
        TaskFormDurationPreset(minutes: 30, label: "30m"),
        TaskFormDurationPreset(minutes: 45, label: "45m"),
        TaskFormDurationPreset(minutes: 60, label: "1h"),
        TaskFormDurationPreset(minutes: 90, label: "1h 30m"),
        TaskFormDurationPreset(minutes: 120, label: "2h"),
    ]

    init(
        task: RoutineTask,
        date: Date,
        occurrence: DayPlanDoneTaskOccurrence
    ) {
        self.task = task
        self.date = date
        self.occurrence = occurrence

        let calendar = Calendar.current
        let workTiming = occurrence.workTiming(calendar: calendar)
        _startMinute = State(initialValue: workTiming.startMinute)
        _durationMinutes = State(initialValue: workTiming.durationMinutes)
        _hasSpecificTime = State(initialValue: occurrence.hasSpecificTime)
    }

    var body: some View {
        TaskDetailSectionCardView(
            background: TaskDetailPlatformStyle.summaryCardBackground,
            stroke: TaskDetailPlatformStyle.sectionCardStroke
        ) {
            VStack(alignment: .leading, spacing: 12) {
                header

                Divider()

                Picker("When", selection: $hasSpecificTime) {
                    Text("Specific time").tag(true)
                    Text("No specific time").tag(false)
                }
                .pickerStyle(.segmented)

                if hasSpecificTime {
                    DatePicker(
                        "Starts",
                        selection: startDateBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.compact)
                } else {
                    Text("Use the duration as the day’s total when the work happened in multiple sessions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                TaskFormDurationEntry(
                    title: "Duration",
                    minutes: durationBinding,
                    bounds: durationRange,
                    presets: durationPresets
                )

                if hasSpecificTime {
                    Text("Starts at \(startTimeText) · Ends \(endTimeText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No specific time · \(DayPlanFormatting.durationText(durationMinutes)) total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let feedbackMessage {
                    Label(
                        feedbackMessage,
                        systemImage: didSave ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(didSave ? Color.green : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Button(hasSpecificTime ? "Save Time & Duration" : "Save Duration") {
                    saveCompletedTime()
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: startMinute) { _, _ in
            clearFeedback()
        }
        .onChange(of: durationMinutes) { _, _ in
            clearFeedback()
        }
        .onChange(of: hasSpecificTime) { _, newValue in
            if newValue {
                durationMinutes = DayPlanBlock.clampedDuration(
                    durationMinutes,
                    startMinute: startMinute,
                    minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
                )
            }
            clearFeedback()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(Color.green)
                .frame(width: 28, height: 28)
                .background(Color.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 3) {
                Text("Done this day")
                    .font(.headline)

                Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year()))
                    .font(.subheadline.weight(.semibold))

                Text("Set the total time spent, with an optional specific start time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    private var durationRange: ClosedRange<Int> {
        DayPlanBlock
            .minimumStoredDurationMinutes...max(
                DayPlanBlock.minimumStoredDurationMinutes,
                DayPlanBlock.minutesPerDay - (hasSpecificTime ? startMinute : 0)
            )
    }

    private var startTimeText: String {
        DayPlanFormatting.timeText(
            for: startMinute,
            on: date,
            calendar: calendar
        )
    }

    private var endTimeText: String {
        DayPlanFormatting.timeText(
            for: startMinute + durationMinutes,
            on: date,
            calendar: calendar
        )
    }

    private var durationBinding: Binding<Int> {
        Binding(
            get: { durationMinutes },
            set: { minutes in
                durationMinutes = DayPlanBlock.clampedDuration(
                    minutes,
                    startMinute: hasSpecificTime ? startMinute : 0,
                    minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
                )
            }
        )
    }

    private var startDateBinding: Binding<Date> {
        Binding(
            get: {
                let startOfDay = calendar.startOfDay(for: date)
                return calendar.date(
                    byAdding: .minute,
                    value: startMinute,
                    to: startOfDay
                ) ?? startOfDay
            },
            set: { newDate in
                let components = calendar.dateComponents([.hour, .minute], from: newDate)
                let minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
                startMinute = DayPlanBlock.clampedStartMinute(minute)
                durationMinutes = DayPlanBlock.clampedDuration(
                    durationMinutes,
                    startMinute: startMinute,
                    minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
                )
            }
        )
    }

    private func clearFeedback() {
        feedbackMessage = nil
        didSave = false
    }

    private func saveCompletedTime() {
        didSave = DayPlanTimelineTasks.updateCompletedActivity(
            occurrence,
            taskID: task.id,
            on: date,
            startMinute: startMinute,
            durationMinutes: durationMinutes,
            hasSpecificTime: hasSpecificTime,
            context: modelContext,
            calendar: calendar
        )
        feedbackMessage =
            didSave
            ? "Updated this completion."
            : "Couldn’t update this completion. Try again."
    }
}
