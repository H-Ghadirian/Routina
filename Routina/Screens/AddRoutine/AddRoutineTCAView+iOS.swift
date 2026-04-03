import SwiftUI

extension View {
    func routinaAddRoutineNameAutofocus(
        isRoutineNameFocused: FocusState<Bool>.Binding
    ) -> some View {
        onAppear {
            // Real devices can delay the first tap-to-focus inside Form.
            // Auto-focus improves perceived responsiveness.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isRoutineNameFocused.wrappedValue = true
            }
        }
    }

    func routinaAddRoutineSheetFrame() -> some View {
        self
    }

    func routinaAddRoutineEmojiPicker<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: isPresented) {
            content()
        }
    }

    func routinaAddRoutinePlatformLinkField() -> some View {
        textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)
    }

    func routinaAddRoutineImageImportSupport(
        isDropTargeted: Binding<Bool>,
        isFileImporterPresented: Binding<Bool>,
        onImport: @escaping (URL) -> Void
    ) -> some View {
        self
    }

    func routinaTaskRelationshipSearchFieldPlatform() -> some View {
        textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }
}

extension AddRoutineTCAView {
    var platformAddRoutineContent: some View {
        Form {
            Section(header: Text("Name")) {
                TextField("Task name", text: routineNameBinding)
                    .focused($isRoutineNameFocused)
                if let nameValidationMessage {
                    Text(nameValidationMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section(header: Text("Task Type")) {
                Picker("Task Type", selection: taskTypeBinding) {
                    Text("Routine").tag(RoutineTaskType.routine)
                    Text("Todo").tag(RoutineTaskType.todo)
                }
                .pickerStyle(.segmented)

                Text(taskTypeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Emoji")) {
                HStack(spacing: 12) {
                    Text("Selected")
                        .foregroundColor(.secondary)
                    Text(store.routineEmoji)
                        .font(.title2)
                        .frame(width: 44, height: 44)
                    Spacer()
                    Button("Choose Emoji") {
                        isEmojiPickerPresented = true
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(emojiOptions, id: \.self) { emoji in
                            Button {
                                store.send(.routineEmojiChanged(emoji))
                            } label: {
                                Text(emoji)
                                    .font(.title2)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(store.routineEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section(header: Text("Notes")) {
                TextField("Add notes", text: routineNotesBinding, axis: .vertical)
                    .lineLimit(4...8)

                Text(notesHelpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Link")) {
                TextField("https://example.com", text: routineLinkBinding)
                    .routinaAddRoutinePlatformLinkField()

                Text(linkHelpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if store.taskType == .todo {
                Section(header: Text("Deadline")) {
                    Toggle("Set deadline", isOn: deadlineEnabledBinding)
                    if store.hasDeadline {
                        DatePicker("Deadline", selection: deadlineBinding)
                    }
                }
            }

            Section(header: Text("Importance & Urgency")) {
                ImportanceUrgencyMatrixPicker(
                    importance: importanceBinding,
                    urgency: urgencyBinding
                )

                Text(importanceUrgencyDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Image")) {
                imageAttachmentContent
            }

            Section(header: Text("Tags")) {
                tagComposer
                availableTagSuggestionsContent
                manageTagsButton
                editableTagsContent

                Text(tagSectionHelpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Relationships")) {
                TaskRelationshipsEditor(
                    relationships: store.relationships,
                    candidates: store.availableRelationshipTasks,
                    addRelationship: { store.send(.addRelationship($0, $1)) },
                    removeRelationship: { store.send(.removeRelationship($0)) }
                )

                Text("Link this task to another task as related work or a blocker.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if store.taskType == .routine {
                Section(header: Text("Schedule Type")) {
                    Picker("Schedule Type", selection: scheduleModeBinding) {
                        Text("Fixed").tag(RoutineScheduleMode.fixedInterval)
                        Text("Checklist").tag(RoutineScheduleMode.fixedIntervalChecklist)
                        Text("Runout").tag(RoutineScheduleMode.derivedFromChecklist)
                    }
                    .pickerStyle(.segmented)

                    Text(scheduleModeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isStepBasedMode {
                Section(header: Text("Steps")) {
                    stepComposer
                    editableStepsContent

                    Text(stepsSectionDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section(header: Text("Checklist Items")) {
                    checklistItemComposer
                    editableChecklistItemsContent

                    Text(checklistSectionDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(header: Text("Place")) {
                Picker("Place", selection: selectedPlaceBinding) {
                    Text("Anywhere").tag(Optional<UUID>.none)
                    ForEach(store.availablePlaces) { place in
                        Text(place.name).tag(Optional(place.id))
                    }
                }

                Text(placeSelectionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if showsRepeatControls {
                repeatPatternSections
            }
        }
    }

    @ViewBuilder
    var platformImageImportButton: some View {
        EmptyView()
    }

    @ViewBuilder
    var platformImageDropHint: some View {
        EmptyView()
    }
}
