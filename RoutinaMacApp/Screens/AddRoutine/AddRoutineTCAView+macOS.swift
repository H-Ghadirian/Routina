import SwiftUI
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

extension View {
    func routinaAddRoutineNameAutofocus(
        isRoutineNameFocused: FocusState<Bool>.Binding
    ) -> some View {
        self
    }

    func routinaAddRoutineSheetFrame() -> some View {
        frame(minWidth: 620, minHeight: 430)
    }

    func routinaAddRoutineEmojiPicker<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        popover(isPresented: isPresented, arrowEdge: .top) {
            content()
                .frame(minWidth: 430, minHeight: 380)
        }
    }

    func routinaAddRoutinePlatformLinkField() -> some View {
        self
    }

    func routinaAddRoutineImageImportSupport(
        isDropTargeted: Binding<Bool>,
        isFileImporterPresented: Binding<Bool>,
        onImport: @escaping (URL) -> Void
    ) -> some View {
        background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isDropTargeted.wrappedValue ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isDropTargeted.wrappedValue ? Color.accentColor : Color.secondary.opacity(0.18),
                    style: StrokeStyle(lineWidth: isDropTargeted.wrappedValue ? 2 : 1, dash: [8, 6])
                )
        )
        .dropDestination(for: URL.self) { urls, _ in
            guard let imageURL = urls.first(where: { isSupportedImageFile($0) }) else {
                return false
            }
            onImport(imageURL)
            return true
        } isTargeted: { isTargeted in
            isDropTargeted.wrappedValue = isTargeted
        }
        .fileImporter(
            isPresented: isFileImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result,
                  let imageURL = urls.first(where: { isSupportedImageFile($0) }) else {
                return
            }
            onImport(imageURL)
        }
    }

    func routinaTaskRelationshipSearchFieldPlatform() -> some View {
        self
    }
}

private func isSupportedImageFile(_ url: URL) -> Bool {
    guard let type = UTType(filenameExtension: url.pathExtension) else {
        return false
    }
    return type.conforms(to: .image)
}

extension AddRoutineTCAView {
    private var macContentMaxWidth: CGFloat { 980 }
    private var macCompactControlWidth: CGFloat { 320 }

    private var sectionCardBackground: some ShapeStyle {
        Color(nsColor: .controlBackgroundColor)
    }

    private var sectionCardStroke: Color {
        Color.gray.opacity(0.18)
    }

    var platformAddRoutineContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            macSectionCard(
                title: "Identity",
                subtitle: "Start with the essentials so the task feels defined right away."
            ) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 16) {
                        Text(store.routineEmoji)
                            .font(.system(size: 30))
                            .frame(width: 60, height: 60)
                            .background(
                                Circle()
                                    .fill(Color.accentColor.opacity(0.16))
                            )

                        VStack(alignment: .leading, spacing: 8) {
                            Text(macPreviewTitle)
                                .font(.title2.weight(.semibold))
                                .lineLimit(1)

                            Text(macPreviewSubtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    if let scheduleModeTitle = macScheduleModeTitle {
                                        macInfoPill(scheduleModeTitle, systemImage: "repeat")
                                    }

                                    macInfoPill(macScheduleSummary, systemImage: "calendar")
                                    macInfoPill(macPlaceSummary, systemImage: "mappin.and.ellipse")
                                }
                            }
                        }

                        Spacer(minLength: 0)
                    }

                    macControlBlock(title: "Task name") {
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Task name", text: routineNameBinding)
                                .textFieldStyle(.roundedBorder)
                                .focused($isRoutineNameFocused)

                            if let nameValidationMessage {
                                Text(nameValidationMessage)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    macControlBlock(title: "Emoji") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Button("Choose Emoji") {
                                    isEmojiPickerPresented = true
                                }
                                .buttonStyle(.bordered)

                                Text("Quick picks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(emojiOptions.prefix(8)), id: \.self) { emoji in
                                        Button {
                                            store.send(.routineEmojiChanged(emoji))
                                        } label: {
                                            Text(emoji)
                                                .font(.title3)
                                                .frame(width: 34, height: 34)
                                                .background(
                                                    Circle()
                                                        .fill(
                                                            store.routineEmoji == emoji
                                                                ? Color.accentColor.opacity(0.20)
                                                                : Color.secondary.opacity(0.08)
                                                        )
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    macSectionCard(
                        title: "Behavior",
                        subtitle: "Choose how this task repeats, where it appears, and when it is due."
                    ) {
                        VStack(alignment: .leading, spacing: 18) {
                            macControlBlock(title: "Type", caption: taskTypeDescription) {
                                HStack(spacing: 0) {
                                    Picker("Task Type", selection: taskTypeBinding) {
                                        Text("Routine").tag(RoutineTaskType.routine)
                                        Text("Todo").tag(RoutineTaskType.todo)
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.segmented)
                                    .fixedSize()
                                    Spacer(minLength: 0)
                                }
                            }

                            if store.taskType == .routine {
                                macControlBlock(title: "Schedule style", caption: scheduleModeDescription) {
                                    HStack(spacing: 0) {
                                        Picker("Schedule Type", selection: scheduleModeBinding) {
                                            Text("Fixed").tag(RoutineScheduleMode.fixedInterval)
                                            Text("Checklist").tag(RoutineScheduleMode.fixedIntervalChecklist)
                                            Text("Runout").tag(RoutineScheduleMode.derivedFromChecklist)
                                        }
                                        .labelsHidden()
                                        .pickerStyle(.segmented)
                                        .fixedSize()
                                        Spacer(minLength: 0)
                                    }
                                }

                                if !isStepBasedMode {
                                    macControlBlock(
                                        title: "Checklist",
                                        caption: checklistSectionDescription
                                    ) {
                                        VStack(alignment: .leading, spacing: 12) {
                                            checklistItemComposer
                                            editableChecklistItemsContent
                                        }
                                    }
                                }
                            }

                            if showsRepeatControls {
                                macControlBlock(title: "Repeat pattern", caption: recurrencePatternDescription) {
                                    HStack(spacing: 0) {
                                        Picker("Repeat Pattern", selection: recurrenceKindBinding) {
                                            ForEach(RoutineRecurrenceRule.Kind.allCases, id: \.self) { kind in
                                                Text(kind.pickerTitle).tag(kind)
                                            }
                                        }
                                        .labelsHidden()
                                        .pickerStyle(.segmented)
                                        .fixedSize()
                                        Spacer(minLength: 0)
                                    }
                                }

                                switch store.recurrenceKind {
                                case .intervalDays:
                                    macControlBlock(
                                        title: "Repeat",
                                        caption: stepperLabel(
                                            frequency: store.frequency,
                                            frequencyValue: store.frequencyValue
                                        )
                                    ) {
                                        HStack(spacing: 10) {
                                            Text("Every")
                                                .foregroundStyle(.secondary)

                                            Stepper(value: frequencyValueBinding, in: 1...365) {
                                                Text("\(store.frequencyValue)")
                                                    .font(.body.monospacedDigit())
                                                    .frame(minWidth: 28, alignment: .trailing)
                                            }
                                            .fixedSize()

                                            Picker("Unit", selection: frequencyBinding) {
                                                ForEach(AddRoutineFeature.Frequency.allCases, id: \.self) { frequency in
                                                    Text(frequency.rawValue).tag(frequency)
                                                }
                                            }
                                            .labelsHidden()
                                            .pickerStyle(.segmented)
                                            .frame(width: 220)

                                            Spacer(minLength: 0)
                                        }
                                    }

                                case .dailyTime:
                                    macControlBlock(
                                        title: "Time",
                                        caption: "Due every day at \(store.recurrenceTimeOfDay.formatted())."
                                    ) {
                                        DatePicker(
                                            "Time",
                                            selection: recurrenceTimeBinding,
                                            displayedComponents: .hourAndMinute
                                        )
                                        .labelsHidden()
                                    }

                                case .weekly:
                                    macControlBlock(
                                        title: "Weekday",
                                        caption: "Due every \(weekdayName(for: store.recurrenceWeekday))."
                                    ) {
                                        Picker("Weekday", selection: recurrenceWeekdayBinding) {
                                            ForEach(weekdayOptions, id: \.id) { option in
                                                Text(option.name).tag(option.id)
                                            }
                                        }
                                        .labelsHidden()
                                        .pickerStyle(.menu)
                                    }

                                case .monthlyDay:
                                    macControlBlock(
                                        title: "Month day",
                                        caption: "Due on the \(ordinalDay(store.recurrenceDayOfMonth)) of each month."
                                    ) {
                                        Stepper(value: recurrenceDayOfMonthBinding, in: 1...31) {
                                            Text(ordinalDay(store.recurrenceDayOfMonth))
                                                .frame(minWidth: 40, alignment: .leading)
                                        }
                                        .fixedSize()
                                    }
                                }
                            }

                            HStack(alignment: .top, spacing: 16) {
                                macControlBlock(title: "Place", caption: placeSelectionDescription) {
                                    Picker("Place", selection: selectedPlaceBinding) {
                                        Text("Anywhere").tag(Optional<UUID>.none)
                                        ForEach(store.availablePlaces) { place in
                                            Text(place.name).tag(Optional(place.id))
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.menu)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                if store.taskType == .todo {
                                    macControlBlock(
                                        title: "Deadline",
                                        caption: store.hasDeadline
                                            ? "This todo will use the selected due date."
                                            : "Leave this off until the task has a real deadline."
                                    ) {
                                        VStack(alignment: .leading, spacing: 10) {
                                            Toggle("Set deadline", isOn: deadlineEnabledBinding)
                                            if store.hasDeadline {
                                                DatePicker("Deadline", selection: deadlineBinding)
                                                    .labelsHidden()
                                            }
                                        }
                                    }
                                    .frame(width: macCompactControlWidth, alignment: .leading)
                                }
                            }

                            macControlBlock(title: "Importance & Urgency", caption: importanceUrgencyDescription) {
                                ImportanceUrgencyMatrixPicker(
                                    importance: importanceBinding,
                                    urgency: urgencyBinding
                                )
                                .frame(maxWidth: 420, alignment: .leading)
                            }
                        }
                    }

                    macSectionCard(
                        title: "Context",
                        subtitle: "Keep supporting metadata lightweight and easy to scan."
                    ) {
                        VStack(alignment: .leading, spacing: 18) {
                            macControlBlock(title: "Tags", caption: tagSectionHelpText) {
                                VStack(alignment: .leading, spacing: 10) {
                                    tagComposer
                                    editableTagsContent
                                    availableTagSuggestionsContent
                                    manageTagsButton
                                }
                            }

                            macControlBlock(
                                title: "Linked tasks",
                                caption: "Link this task to another task as related work or a blocker."
                            ) {
                                TaskRelationshipsEditor(
                                    relationships: store.relationships,
                                    candidates: store.availableRelationshipTasks,
                                    addRelationship: { store.send(.addRelationship($0, $1)) },
                                    removeRelationship: { store.send(.removeRelationship($0)) }
                                )
                            }

                            macControlBlock(title: "Open link", caption: linkHelpText) {
                                TextField("https://example.com", text: routineLinkBinding)
                                    .textFieldStyle(.roundedBorder)
                                    .routinaAddRoutinePlatformLinkField()
                            }
                        }
                    }

                    macSectionCard(
                        title: "Notes",
                        subtitle: notesHelpText
                    ) {
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: routineNotesBinding)
                                .frame(minHeight: 120)
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(nsColor: .textBackgroundColor))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(sectionCardStroke, lineWidth: 1)
                                )

                            if store.routineNotes.isEmpty {
                                Text("Add notes, reminders, or context")
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 14)
                                    .allowsHitTesting(false)
                            }
                        }
                    }

                    if isStepBasedMode {
                        macSectionCard(
                            title: "Steps",
                            subtitle: stepsSectionDescription
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                stepComposer
                                editableStepsContent
                            }
                        }
                    }

                    macSectionCard(
                        title: "Image",
                        subtitle: "Optional artwork or reference material for this task."
                    ) {
                        imageAttachmentContent
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    var platformImageImportButton: some View {
        Button(store.imageData == nil ? "Browse in Finder" : "Browse Another File") {
            isImageFileImporterPresented = true
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    var platformImageDropHint: some View {
        Text("You can also drag an image from Finder onto this area.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var macPreviewTitle: String {
        let trimmedName = store.trimmedRoutineName
        return trimmedName.isEmpty ? "New \(macTaskTypeLabel.lowercased())" : trimmedName
    }

    private var macPreviewSubtitle: String {
        if store.taskType == .todo {
            return store.hasDeadline
                ? "A one-off task with a deadline."
                : "A one-off task you can finish once."
        }

        switch store.scheduleMode {
        case .fixedInterval:
            return "A repeating routine with one shared cadence."
        case .fixedIntervalChecklist:
            return "A routine you complete by finishing every checklist item."
        case .derivedFromChecklist:
            return "A routine driven by the due dates of its checklist items."
        case .oneOff:
            return "A one-off task you can finish once."
        }
    }

    private var macTaskTypeLabel: String {
        store.taskType == .todo ? "Todo" : "Routine"
    }

    private var macScheduleModeTitle: String? {
        guard store.taskType == .routine else { return nil }

        switch store.scheduleMode {
        case .fixedInterval:
            return "Fixed"
        case .fixedIntervalChecklist:
            return "Checklist"
        case .derivedFromChecklist:
            return "Runout"
        case .oneOff:
            return nil
        }
    }

    private var macScheduleSummary: String {
        if store.taskType == .todo {
            if let deadline = store.deadline {
                return "Due \(deadline.formatted(date: .abbreviated, time: .omitted))"
            }
            return "One-off"
        }

        switch store.recurrenceKind {
        case .intervalDays:
            return stepperLabel(
                frequency: store.frequency,
                frequencyValue: store.frequencyValue
            )
        case .dailyTime:
            return "Daily at \(store.recurrenceTimeOfDay.formatted())"
        case .weekly:
            return "Every \(weekdayName(for: store.recurrenceWeekday))"
        case .monthlyDay:
            return "Monthly on the \(ordinalDay(store.recurrenceDayOfMonth))"
        }
    }

    private var macPlaceSummary: String {
        guard let selectedPlaceID = store.selectedPlaceID,
              let place = store.availablePlaces.first(where: { $0.id == selectedPlaceID }) else {
            return "Anywhere"
        }
        return place.name
    }

    @ViewBuilder
    private func macSectionCard<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(sectionCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(sectionCardStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func macControlBlock<Content: View>(
        title: String,
        caption: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            content()

            if let caption {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func macInfoPill(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.10))
            )
    }
}
