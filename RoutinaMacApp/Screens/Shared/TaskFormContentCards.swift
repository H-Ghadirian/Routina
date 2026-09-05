import PhotosUI
import SwiftUI

extension TaskFormContent {
    var identityCard: some View {
        let parsedSmartNameDraft = smartNameDraft
        return TaskFormMacIdentityCard(
            model: model,
            smartNameDraft: parsedSmartNameDraft,
            smartNameCalendar: calendar,
            onApplySmartName: model.onApplySmartName
        ) {
            taskNameField(onTab: parsedSmartNameDraft == nil ? nil : model.onApplySmartName)
        }
        .id(FormSection.identity)
    }

    var emojiCard: some View {
        macSectionCard(title: "Emoji") {
            TaskFormMacEmojiContent(model: model)
        }
        .id(FormSection.emoji)
    }

    private var smartNameDraft: RoutinaQuickAddDraft? {
        guard
            let draft = RoutinaQuickAddParser.parse(
                model.name.wrappedValue,
                calendar: calendar,
                includingPlaces: isPlacesEnabled
            ),
            draft.hasDetectedMetadata
        else {
            return nil
        }
        return draft
    }

    private func taskNameField(onTab: (() -> Void)?) -> some View {
        MacFocusableTextField(
            placeholder: smartNamePlaceholder,
            text: model.name,
            isFocusRequested: model.autofocusName,
            focusRequestID: model.nameFocusRequestID,
            onTab: onTab
        )
        .frame(height: 50)
    }

    private var smartNamePlaceholder: String {
        if isPlacesEnabled {
            return "Water plants every Sat at 9am #home @Balcony !high 25m"
        }
        return "Water plants every Sat at 9am #home !high 25m"
    }

    // MARK: Color

    var colorCard: some View {
        TaskFormMacColorCard(model: model)
    }

    // MARK: Behavior

    var behaviorCard: some View {
        TaskFormMacBehaviorCard(
            model: model,
            presentation: presentation,
            persianDeadlineText: persianDeadlineText
        )
        .id(FormSection.behavior)
    }

    // MARK: Task Ladder values

    var taskLadderValuesCard: some View {
        macSectionCard(
            title: "Task Ladder values",
            subtitle: "Set the four independent signals used to place this task."
        ) {
            TaskTemporalWeightRuleEditor(
                rule: model.temporalWeightRule,
                importance: model.importance,
                urgency: model.urgency,
                pressure: model.pressure,
                allowsTemporalChanges: model.supportsTemporalWeightValues,
                maximumBeforeDueDays: model.maximumTemporalWeightBeforeDueDays,
                usesAfterDoneLanguage: model.taskType.wrappedValue == .routine
            )

            TaskTemporalThinkingSentenceEditor(
                thinking: model.thinkingNeeded,
                usesAfterDoneLanguage: model.taskType.wrappedValue == .routine
            )

            if model.supportsTaskLadderEntryWindow {
                Divider()
                TaskLadderEntryWindowEditor(
                    window: model.taskLadderEntryWindow,
                    maximumBeforeDueDays: model.maximumTaskLadderEntryBeforeDueDays
                )
            }

            if model.taskType.wrappedValue == .routine,
                !model.supportsTemporalWeightValues,
                let message = model.temporalWeightAvailabilityMessage
            {
                Label(message, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .id(FormSection.taskLadderValues)
    }

    // MARK: Organization

    var organizationCard: some View {
        macSectionCard(title: "Organization") {
            TaskFormMacPathControl(model: model)

            Divider()

            TaskFormMacTagsContent(model: model) {
                isTagManagerPresented = true
            }

            if model.taskType.wrappedValue == .routine {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Task Ladder group")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TaskFormMacTaskLadderGroupControl(model: model)
                }
            }
        }
        .id(FormSection.organization)
    }

    var estimationCard: some View {
        TaskFormMacEstimationCard(model: model)
            .id(FormSection.estimation)
    }

    // MARK: Places

    var placesCard: some View {
        TaskFormMacPlacesCard(model: model) {
            isPlaceManagerPresented = true
        }
        .id(FormSection.places)
    }

    var destinationCard: some View {
        TaskFormMacDestinationCard(model: model)
            .id(FormSection.destination)
    }

    // MARK: Goals

    var goalsCard: some View {
        macSectionCard(
            title: "Goals"
        ) {
            TaskFormMacGoalsContent(model: model, presentation: presentation)
        }
        .id(FormSection.goals)
    }

    // MARK: Events

    var eventsCard: some View {
        macSectionCard(
            title: "Events"
        ) {
            TaskFormLinkedEventsContent(
                events: model.availableEvents,
                selectedEventIDs: model.selectedEventIDs,
                onToggleEvent: model.onToggleEventSelection
            )
        }
        .id(FormSection.events)
    }

    // MARK: Linked Tasks

    var linkedTasksCard: some View {
        macSectionCard(
            title: "Linked tasks"
        ) {
            TaskRelationshipsEditor(
                relationships: model.relationships,
                candidates: model.availableRelationshipTasks,
                addRelationship: model.onAddRelationship,
                removeRelationship: model.onRemoveRelationship,
                createLinkedTask: model.onCreateLinkedTask
            ) { searchText in
                TextField("Search tasks", text: searchText)
                    .routinaTaskRelationshipSearchFieldPlatform()
            }
        }
        .id(FormSection.linkedTasks)
    }

    // MARK: Planning

    @ViewBuilder
    var planningCard: some View {
        if planningPlacement == .standaloneSection {
            TaskFormMacPlanningCard(model: model)
                .id(FormSection.planning)
        }
    }

    // MARK: Links

    var linkURLCard: some View {
        TaskFormMacLinkCard(model: model, presentation: presentation)
            .id(FormSection.linkURL)
    }

    // MARK: Description

    var taskDescriptionCard: some View {
        TaskFormMacDescriptionCard(model: model)
            .id(FormSection.taskDescription)
    }

    // MARK: Notes

    var notesCard: some View {
        TaskFormMacNotesCard(model: model)
            .id(FormSection.notes)
    }

    // MARK: Steps

    var stepsCard: some View {
        macSectionCard(title: "Steps") {
            TaskFormMacStepsContent(model: model)
        }
        .id(FormSection.steps)
    }

    // MARK: Checklist

    var checklistCard: some View {
        macSectionCard(
            title: "Checklist",
            subtitle: presentation.checklistSectionDescription(includesDerivedChecklistDueDetail: true)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                TaskFormMacChecklistComposer(model: model)
                if let message = model.checklistValidationMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                TaskFormMacChecklistItemsContent(model: model)
            }
        }
        .id(FormSection.checklist)
    }

    // MARK: Image

    var imageCard: some View {
        macSectionCard(
            title: "Image"
        ) {
            TaskFormMacImageContent(
                model: model,
                selectedPhotoItem: $selectedPhotoItem,
                isDropTargeted: $isImageDropTargeted,
                isSupportedImageFile: { isSupportedImageFile($0) },
                onLoadPickedImageURL: { loadPickedImage(fromFileAt: $0) },
                onBrowseImageFile: browseForImageFile
            )
        }
        .id(FormSection.image)
    }

    // MARK: Voice Note

    var voiceNoteCard: some View {
        macSectionCard(
            title: "Voice Note"
        ) {
            TaskFormMacVoiceNoteContent(model: model)
        }
        .id(FormSection.voiceNote)
    }

    // MARK: Attachment

    var attachmentCard: some View {
        macSectionCard(
            title: "File Attachment"
        ) {
            TaskFormMacAttachmentContent(
                model: model,
                isFileImporterPresented: $isFileImporterPresented,
                isDropTargeted: $isAttachmentDropTargeted,
                onLoadAttachment: { loadAttachment(fromFileAt: $0) }
            )
        }
        .id(FormSection.attachment)
    }

    // MARK: Danger Zone

    var dangerZoneCard: some View {
        TaskFormMacDangerZoneCard(
            pauseResumeAction: model.pauseResumeAction,
            pauseResumeTitle: model.pauseResumeTitle,
            pauseResumeDescription: model.pauseResumeDescription,
            pauseResumeTint: model.pauseResumeTint,
            onDelete: model.onDelete
        )
        .id(FormSection.dangerZone)
    }

    // MARK: - Card helpers

    @ViewBuilder
    private func macSectionCard<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        TaskFormMacSectionCard(title: title, subtitle: subtitle) {
            content()
        }
    }

    @ViewBuilder
    private func macControlBlock<Content: View>(
        title: String,
        caption: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        TaskFormMacControlBlock(title: title, caption: caption) {
            content()
        }
    }

    // MARK: - Computed helpers

}
