import SwiftUI

#if os(macOS)
    extension RoutineEventEditorView {
        var macEditorContent: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    macHeader

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 18) {
                            VStack(alignment: .leading, spacing: 18) {
                                macEventCard
                                if isNotesEnabled {
                                    macNotesCard
                                }
                            }
                            .frame(minWidth: 520, maxWidth: .infinity, alignment: .topLeading)

                            VStack(alignment: .leading, spacing: 18) {
                                macScheduleCard
                                macNotificationCard
                                macTagsCard
                            }
                            .frame(width: 340, alignment: .topLeading)
                        }

                        VStack(alignment: .leading, spacing: 18) {
                            macEventCard
                            macScheduleCard
                            macNotificationCard
                            if isNotesEnabled {
                                macNotesCard
                            }
                            macTagsCard
                        }
                    }

                    if let errorText {
                        macErrorBanner(errorText)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
                .frame(maxWidth: 980, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .frame(minWidth: 520, minHeight: 560)
        }

        var macHeader: some View {
            HStack(alignment: .center, spacing: 14) {
                Text(displayEmojiPreview)
                    .font(.system(size: 30))
                    .frame(width: 50, height: 50)
                    .routinaGlassCard(cornerRadius: 14, tint: .teal, tintOpacity: 0.14)

                VStack(alignment: .leading, spacing: 4) {
                    Text(editorTitle)
                        .font(.largeTitle.weight(.semibold))
                        .lineLimit(1)

                    Text(datePreviewText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 16)

                Button("Cancel") {
                    cancel()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Button {
                    save()
                } label: {
                    Label("Save", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .keyboardShortcut(.defaultAction)
            }
        }

        var macEventCard: some View {
            RoutineEventEditorCard(title: "Event", systemImage: "calendar.badge.plus") {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Emoji")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField("", text: $emoji, prompt: Text("🗓️"))
                            .textFieldStyle(.plain)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .frame(width: 72)
                            .background(macInputBackground)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField("", text: $title, prompt: Text("Conference day"))
                            .textFieldStyle(.plain)
                            .font(.title3.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(macInputBackground)
                    }
                }
            }
        }

        var macScheduleCard: some View {
            RoutineEventEditorCard(title: "When", systemImage: isAllDay ? "sun.max" : "clock") {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Timing")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        RoutinaGlassSegmentedControl(
                            accessibilityLabel: "Timing",
                            options: [true, false],
                            selection: $isAllDay
                        ) { isAllDayOption in
                            Text(isAllDayOption ? "All Day" : "Timed")
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        if isAllDay {
                            macDatePicker(
                                title: "Starts",
                                selection: allDayStartBinding,
                                displayedComponents: [.date]
                            )
                            macDatePicker(
                                title: "Ends",
                                selection: allDayEndBinding,
                                displayedComponents: [.date]
                            )
                        } else {
                            macDatePicker(
                                title: "Starts",
                                selection: timedStartBinding,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            macDatePicker(
                                title: "Ends",
                                selection: timedEndBinding,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                        }
                    }
                }
            }
        }

        var macNotificationCard: some View {
            RoutineEventEditorCard(title: "Notification", systemImage: "bell") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Set notification", isOn: reminderEnabledBinding)

                    if reminderAt != nil {
                        if let reminderEventDate {
                            Picker("When", selection: reminderLeadMinutesBinding) {
                                Text("Custom time").tag(Optional<Int>.none)
                                ForEach(TaskFormReminderLeadTime.allCases) { option in
                                    Text(option.title).tag(Optional(option.rawValue))
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 190, alignment: .leading)

                            Text(
                                isAllDay
                                    ? "Event: \(reminderEventDate.formatted(date: .abbreviated, time: .omitted))"
                                    : "Event: \(reminderEventDate.formatted(date: .abbreviated, time: .shortened))"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        DatePicker(
                            reminderEventDate == nil ? "Notification" : "Custom time",
                            selection: reminderDateBinding
                        )
                        .labelsHidden()
                        .fixedSize()
                    }
                }
            }
        }

        var macNotesCard: some View {
            RoutineEventEditorCard(title: "Notes", systemImage: "text.alignleft") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Context")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $notesText)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .frame(minHeight: 170)

                        if notesText.isEmpty {
                            Text("Add context")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 13)
                                .allowsHitTesting(false)
                        }
                    }
                    .background(macInputBackground)
                }
            }
        }

        var macTagsCard: some View {
            RoutineEventEditorCard(title: "Tags", systemImage: "tag") {
                VStack(alignment: .leading, spacing: 12) {
                    macTagComposer
                    selectedTagsContent
                    existingTagsContent
                }
            }
        }

        var macTagComposer: some View {
            HStack(spacing: 10) {
                ZStack(alignment: .trailing) {
                    TextField("", text: $tagDraft, prompt: Text("health, travel, work"))
                        .textFieldStyle(.plain)
                        .onSubmit(addTagDraft)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .padding(.trailing, tagAutocompleteSuggestion == nil ? 0 : 96)
                        .background(macInputBackground)

                    if let suggestion = tagAutocompleteSuggestion {
                        Button {
                            acceptTagAutocompleteSuggestion()
                        } label: {
                            Text("#\(suggestion)")
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .routinaGlassPill(
                                    tint: .secondary,
                                    tintOpacity: 0.12,
                                    interactive: true
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 6)
                        .accessibilityLabel("Complete tag \(suggestion)")
                    }
                }

                Button {
                    addTagDraft()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .disabled(RoutineTag.parseDraft(tagDraft).isEmpty)
            }
        }

        func macDatePicker(
            title: String,
            selection: Binding<Date>,
            displayedComponents: DatePickerComponents
        ) -> some View {
            HStack(spacing: 10) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 46, alignment: .leading)

                DatePicker("", selection: selection, displayedComponents: displayedComponents)
                    .labelsHidden()
                    .fixedSize()

                Spacer(minLength: 0)
            }
        }

        var macInputBackground: some View {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                )
        }

        var displayEmojiPreview: String {
            RoutineEvent.cleanedText(emoji) ?? "🗓️"
        }

        var datePreviewText: String {
            RoutineEventDateFormatting.text(
                startedAt: normalizedStartDate,
                endedAt: normalizedEndDate,
                isAllDay: isAllDay,
                calendar: calendar
            )
        }

        func macErrorBanner(_ message: String) -> some View {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.red)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.red.opacity(0.10))
                )
        }
    }

    private struct RoutineEventEditorCard<Content: View>: View {
        let title: String
        let systemImage: String
        let content: Content

        init(
            title: String,
            systemImage: String,
            @ViewBuilder content: () -> Content
        ) {
            self.title = title
            self.systemImage = systemImage
            self.content = content()
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                Label(title, systemImage: systemImage)
                    .font(.headline.weight(.semibold))

                content
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .routinaGlassPanel(cornerRadius: 14, tint: .secondary, tintOpacity: 0.06)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            )
        }
    }
#endif
