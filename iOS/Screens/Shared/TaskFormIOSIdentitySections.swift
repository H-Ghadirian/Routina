import SwiftUI

struct TaskFormIOSNameSection: View {
    let model: TaskFormModel
    let isNameFocused: FocusState<Bool>.Binding

    var body: some View {
        Section(header: Text("Name")) {
            TextField("Task name", text: model.name)
                .focused(isNameFocused)
            if let msg = model.nameValidationMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

struct TaskFormIOSTaskTypeSection: View {
    let model: TaskFormModel
    let presentation: TaskFormPresentation

    var body: some View {
        Section(header: Text("Kind")) {
            Picker("Kind", selection: model.taskType) {
                Text("Routine").tag(RoutineTaskType.routine)
                Text("Todo").tag(RoutineTaskType.todo)
            }
            .pickerStyle(.segmented)

            if model.taskType.wrappedValue == .todo {
                Toggle("All-day block", isOn: model.isAllDay)
            } else if showsRoutineAvailabilityControl {
                Divider()
                availabilityContent
            }

            Text(presentation.taskTypeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var showsRoutineAvailabilityControl: Bool {
        model.taskType.wrappedValue == .routine && presentation.showsRepeatControls
    }

    private var availabilityContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Availability")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("Availability", selection: timingModeBinding) {
                ForEach(TaskFormTimingMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if model.recurrenceHasExplicitTime.wrappedValue {
                DatePicker("Time", selection: model.recurrenceTimeOfDay, displayedComponents: .hourAndMinute)
            } else if model.recurrenceHasTimeRange.wrappedValue {
                timeRangePickers
            }

            Text(recurrenceAvailabilityHelpText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var timeRangePickers: some View {
        VStack(spacing: 8) {
            DatePicker("Starts", selection: model.recurrenceTimeRangeStart, displayedComponents: .hourAndMinute)
            DatePicker("Ends", selection: model.recurrenceTimeRangeEnd, displayedComponents: .hourAndMinute)
        }
    }

    private var recurrenceAvailabilityHelpText: String {
        presentation.availabilityControlHelpText(isAllDay: model.isAllDay.wrappedValue)
    }

    private var timingModeBinding: Binding<TaskFormTimingMode> {
        Binding(
            get: {
                if model.isAllDay.wrappedValue {
                    return .allDay
                }
                if model.recurrenceHasTimeRange.wrappedValue {
                    return .range
                }
                if model.recurrenceHasExplicitTime.wrappedValue {
                    return .exact
                }
                return .none
            },
            set: { mode in
                model.isAllDay.wrappedValue = mode == .allDay
                model.recurrenceHasExplicitTime.wrappedValue = mode == .exact
                model.recurrenceHasTimeRange.wrappedValue = mode == .range
            }
        )
    }
}

struct TaskFormIOSEmojiSection: View {
    let model: TaskFormModel

    var body: some View {
        Section(header: Text("Emoji")) {
            HStack(spacing: 12) {
                Text("Selected").foregroundColor(.secondary)
                Text(model.emoji.wrappedValue)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                Spacer()
                Button("Choose Emoji") { model.isEmojiPickerPresented.wrappedValue = true }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(model.emojiOptions, id: \.self) { emoji in
                        Button {
                            model.emoji.wrappedValue = emoji
                        } label: {
                            Text(emoji)
                                .font(.title2)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle().fill(
                                        model.emoji.wrappedValue == emoji
                                            ? Color.blue.opacity(0.2)
                                            : Color.clear
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
