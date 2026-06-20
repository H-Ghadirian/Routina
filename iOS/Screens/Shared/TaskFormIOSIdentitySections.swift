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
    @Environment(\.calendar) private var calendar

    var body: some View {
        Section(header: Text("Kind")) {
            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Kind",
                options: RoutineTaskType.allCases,
                selection: model.taskType,
                fillsAvailableWidth: true
            ) { taskType in
                Text(taskType.rawValue)
            }

            if showsRoutineDurationControl {
                Divider()
                routineDurationContent
            }

            if showsAvailabilityControl {
                Divider()
                availabilityContent
            }
        }
    }

    private var showsAvailabilityControl: Bool {
        switch model.taskType.wrappedValue {
        case .todo:
            return true
        case .routine:
            return presentation.showsRepeatControls
        }
    }

    private var showsRoutineDurationControl: Bool {
        model.taskType.wrappedValue == .routine
    }

    private var availabilityContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.taskType.wrappedValue == .todo {
                dateAvailabilityContent
            }

            timeAvailabilityContent
        }
    }

    private var dateAvailabilityContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date availability")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Date availability",
                options: TaskFormDateAvailabilityMode.allCases,
                selection: dateAvailabilityModeBinding,
                fillsAvailableWidth: true
            ) { mode in
                Text(mode.rawValue)
            }

            dateAvailabilityPickers
        }
    }

    private var timeAvailabilityContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time availability")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Time availability",
                options: TaskFormTimingMode.cases(for: model.taskType.wrappedValue),
                selection: timingModeBinding,
                fillsAvailableWidth: true
            ) { mode in
                Text(mode.rawValue)
            }

            if currentTimingMode == .exact {
                DatePicker("Time", selection: model.recurrenceTimeOfDay, displayedComponents: .hourAndMinute)
            } else if currentTimingMode == .range {
                routineTimeRangePickers
            }
        }
    }

    private var routineDurationContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Duration")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Duration",
                options: RoutineDurationMode.allCases,
                selection: model.routineDurationMode,
                fillsAvailableWidth: true
            ) { mode in
                Text(mode.rawValue)
            }
        }
    }

    @ViewBuilder
    private var dateAvailabilityPickers: some View {
        switch currentDateAvailabilityMode {
        case .none:
            EmptyView()
        case .exact:
            DatePicker("Date", selection: todoAvailabilityStartBinding, displayedComponents: .date)
        case .range:
            todoDateRangePickers
        }
    }

    private var routineTimeRangePickers: some View {
        VStack(spacing: 8) {
            DatePicker("Starts", selection: model.recurrenceTimeRangeStart, displayedComponents: .hourAndMinute)
            DatePicker("Ends", selection: model.recurrenceTimeRangeEnd, displayedComponents: .hourAndMinute)
        }
    }

    private var todoDateRangePickers: some View {
        VStack(spacing: 8) {
            DatePicker("Starts", selection: todoAvailabilityStartBinding, displayedComponents: .date)
            DatePicker("Ends", selection: todoAvailabilityEndBinding, displayedComponents: .date)
        }
    }

    private var dateAvailabilityModeBinding: Binding<TaskFormDateAvailabilityMode> {
        Binding(
            get: {
                if model.availabilityStartDate.wrappedValue == nil {
                    return .none
                }
                if model.availabilityEndDate.wrappedValue != nil {
                    return .range
                }
                return .exact
            },
            set: { mode in
                applyTodoDateAvailabilityMode(mode)
            }
        )
    }

    private var currentDateAvailabilityMode: TaskFormDateAvailabilityMode {
        dateAvailabilityModeBinding.wrappedValue
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
                applyTimingMode(mode)
            }
        )
    }

    private var currentTimingMode: TaskFormTimingMode {
        timingModeBinding.wrappedValue
    }

    private var todoAvailabilityStartBinding: Binding<Date> {
        Binding(
            get: { model.availabilityStartDate.wrappedValue ?? Date() },
            set: { setTodoAvailabilityStartDate($0) }
        )
    }

    private var todoAvailabilityEndBinding: Binding<Date> {
        Binding(
            get: {
                let start = model.availabilityStartDate.wrappedValue ?? Date()
                return model.availabilityEndDate.wrappedValue ?? dateAfter(start)
            },
            set: { setTodoAvailabilityEndDate($0) }
        )
    }

    private func applyTimingMode(_ mode: TaskFormTimingMode) {
        model.isAllDay.wrappedValue = mode == .allDay
        model.recurrenceHasExplicitTime.wrappedValue = mode == .exact
        model.recurrenceHasTimeRange.wrappedValue = mode == .range
    }

    private func applyTodoDateAvailabilityMode(_ mode: TaskFormDateAvailabilityMode) {
        let start = model.availabilityStartDate.wrappedValue ?? Date()
        let end = model.availabilityEndDate.wrappedValue ?? dateAfter(start)
        switch mode {
        case .none:
            model.availabilityStartDate.wrappedValue = nil
            model.availabilityEndDate.wrappedValue = nil
        case .exact:
            model.availabilityStartDate.wrappedValue = calendar.startOfDay(for: start)
            model.availabilityEndDate.wrappedValue = nil
        case .range:
            model.availabilityStartDate.wrappedValue = calendar.startOfDay(for: start)
            model.availabilityEndDate.wrappedValue = calendar.startOfDay(for: end) < calendar.startOfDay(for: start)
                ? calendar.startOfDay(for: start)
                : calendar.startOfDay(for: end)
        }
    }

    private func setTodoAvailabilityStartDate(_ date: Date) {
        let storedDate = calendar.startOfDay(for: date)
        model.availabilityStartDate.wrappedValue = storedDate

        if currentDateAvailabilityMode == .range,
           let end = model.availabilityEndDate.wrappedValue,
           calendar.startOfDay(for: end) < storedDate {
            model.availabilityEndDate.wrappedValue = storedDate
        }
    }

    private func setTodoAvailabilityEndDate(_ date: Date) {
        let start = calendar.startOfDay(for: model.availabilityStartDate.wrappedValue ?? Date())
        let storedDate = calendar.startOfDay(for: date)
        model.availabilityEndDate.wrappedValue = storedDate < start ? start : storedDate
    }

    private func dateAfter(_ date: Date) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
            ?? calendar.startOfDay(for: date)
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
