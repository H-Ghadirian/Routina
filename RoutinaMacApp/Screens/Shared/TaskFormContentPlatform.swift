import ComposableArchitecture
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

enum TaskFormContentLayout {
    case fullForm
    case embeddedSections([FormSection])
}

struct TaskFormContent: View {
    let model: TaskFormModel
    let layout: TaskFormContentLayout

    @FocusState private var fallbackNameFocused: Bool
    @State var selectedPhotoItem: PhotosPickerItem?
    @State var isFileImporterPresented = false
    @State var isAttachmentDropTargeted = false
    @State var isImageDropTargeted = false
    @State private var hasAppliedInitialNameAutofocus = false
    @State var isTagManagerPresented = false
    @State private var tagManagerStore = Store(initialState: SettingsFeature.State()) {
        SettingsFeature()
    }
    @State var isPlaceManagerPresented = false
    @State private var placeManagerStore = Store(initialState: SettingsFeature.State()) {
        SettingsFeature()
    }
    @State private var fallbackFormCoordinator = AddEditFormCoordinator()
    @Environment(\.calendar) var calendar
    @Environment(\.addEditFormCoordinator) private var inheritedFormCoordinator
    @AppStorage(
        UserDefaultBoolValueKey.appSettingShowPersianDates.rawValue,
        store: SharedDefaults.app
    ) var showPersianDates = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingGoalsTabEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isGoalsTabEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue,
        store: SharedDefaults.app
    ) var isPlacesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isNotesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacEventEmotionActionsEnabled.rawValue,
        store: SharedDefaults.app
    ) private var areMacEventEmotionActionsEnabled = false

    init(
        model: TaskFormModel,
        layout: TaskFormContentLayout = .fullForm
    ) {
        self.model = model
        self.layout = layout
    }

    private var nameFocusBinding: FocusState<Bool>.Binding {
        model.nameFocus ?? $fallbackNameFocused
    }

    private var formCoordinator: AddEditFormCoordinator {
        inheritedFormCoordinator ?? fallbackFormCoordinator
    }

    var body: some View {
        content
            .routinaSegmentedControlSurfaceStyle(.scrolling)
            .sheet(isPresented: $isTagManagerPresented) {
                SettingsTagManagerPresentationView(store: tagManagerStore)
            }
            .sheet(isPresented: $isPlaceManagerPresented) {
                SettingsPlaceManagerPresentationView(store: placeManagerStore)
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                loadPickedImage(from: newItem)
            }
            .onAppear {
                guard model.autofocusName, !hasAppliedInitialNameAutofocus else { return }
                hasAppliedInitialNameAutofocus = true
                Task { @MainActor in
                    await Task.yield()
                    nameFocusBinding.wrappedValue = true
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch layout {
        case .fullForm:
            fullFormContent
        case let .embeddedSections(sections):
            embeddedSectionsContent(sections)
        }
    }

    private var fullFormContent: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                identityCard
                    .padding(.horizontal, 24)
                    .padding(.top, 22)
                    .padding(.bottom, 20)
                    .frame(
                        maxWidth: TaskFormMacLayoutMetrics.maximumFullFormWidth,
                        alignment: .leading
                    )
                    .frame(maxWidth: .infinity, alignment: .center)

                ScrollView {
                    scrollableFormSections
                        .padding(.horizontal, 24)
                        .padding(.bottom, 22)
                        .frame(
                            maxWidth: TaskFormMacLayoutMetrics.maximumFullFormWidth,
                            alignment: .leading
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .onChange(of: formCoordinator.scrollTarget) { _, target in
                guard let target else { return }
                if target == .identity {
                    formCoordinator.scrollTarget = nil
                    return
                }
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(target, anchor: .top)
                }
                formCoordinator.scrollTarget = nil
            }
        }
    }

    private func embeddedSectionsContent(_ sections: [FormSection]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(sections.filter(shouldDisplayFormSection), id: \.self) { section in
                formSectionView(for: section)
            }

            embeddedActionButtons
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var embeddedActionButtons: some View {
        if model.onCancel != nil || model.onSave != nil {
            HStack(spacing: 8) {
                Spacer(minLength: 0)

                if let onCancel = model.onCancel {
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }

                if let onSave = model.onSave {
                    Button {
                        onSave()
                    } label: {
                        saveButtonLabel
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(model.isSaveDisabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var saveButtonLabel: some View {
        if model.isSaving {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Saving…")
            }
            .accessibilityLabel("Saving task")
        } else {
            Text("Save")
        }
    }

    // MARK: - Form sections

    /// All sections that are available given the current form state (excluding `.identity`).
    private var availableSections: [FormSection] {
        FormSection.taskFormSections(
            scheduleMode: model.scheduleMode.wrappedValue,
            includesIdentity: false,
            includesDangerZone: model.onDelete != nil || model.pauseResumeAction != nil
        ).filter { section in
            if section == .planning {
                return planningPlacement == .standaloneSection
            }
            return shouldDisplayFormSection(section)
        }
    }

    var planningPlacement: TaskFormMacPlanningPlacement {
        TaskFormMacPlanningPlacement.resolve(
            taskType: model.taskType.wrappedValue,
            supportsPlanning: model.supportsPlanning
        )
    }

    private func shouldDisplayFormSection(_ section: FormSection) -> Bool {
        if section == .places {
            return isPlacesEnabled
        }
        if section == .notes || section == .voiceNote {
            return isNotesEnabled
        }
        if section == .events {
            return areMacEventEmotionActionsEnabled
        }
        return section != .goals || isGoalsTabEnabled
    }

    private func canRevealOptionalSection(_ section: FormSection) -> Bool {
        section != .checklist || model.allowsOptionalChecklistReveal
    }

    @ViewBuilder
    private var scrollableFormSections: some View {
        // Resolve the section collections once for this render. The form can grow
        // substantially after Add More Details, so its scroll container must not
        // eagerly construct every card or repeat the disclosure derivation.
        let available = availableSections
        let visible = FormSection.visibleTaskFormSections(
            from: available,
            mode: model.visibilityMode,
            revealedSections: formCoordinator.revealedTaskFormSections,
            populatedSections: model.populatedMacFormSections,
            allowsOptionalChecklistReveal: model.allowsOptionalChecklistReveal
        )
        let ordered = formCoordinator.orderedSections(available: visible)
        let visibleSet = Set(visible)
        let hiddenOptional = formCoordinator.orderedSections(available: available).filter {
            $0 != .identity
                && !visibleSet.contains($0)
                && canRevealOptionalSection($0)
        }

        LazyVStack(alignment: .leading, spacing: 20) {
            ForEach(ordered, id: \.self) { section in
                formSectionView(for: section)
            }

            if model.visibilityMode.usesProgressiveDisclosure && !hiddenOptional.isEmpty {
                addDetailsCard(sections: hiddenOptional)
            }
        }
    }

    private func addDetailsCard(sections: [FormSection]) -> some View {
        TaskFormMacSectionCard(title: "Add More Details") {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 132), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(sections, id: \.self) { section in
                    Button {
                        revealOptionalSection(section)
                    } label: {
                        Label(section.addButtonTitle, systemImage: section.icon)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("Add \(section.title)")
                }
            }
        }
    }

    private func revealOptionalSection(_ section: FormSection) {
        withAnimation(.easeInOut(duration: 0.18)) {
            formCoordinator.revealTaskFormSection(section)
        }

        Task { @MainActor in
            await Task.yield()
            withAnimation(.easeInOut(duration: 0.25)) {
                formCoordinator.scrollTarget = section
            }
        }
    }

    @ViewBuilder
    private func formSectionView(for section: FormSection) -> some View {
        switch section {
        case .identity: EmptyView()  // identityCard is rendered separately above the ScrollView
        case .taskDescription: taskDescriptionCard
        case .emoji: emojiCard
        case .color: colorCard
        case .behavior: behaviorCard
        case .taskLadderValues: taskLadderValuesCard
        case .organization: organizationCard
        case .estimation: estimationCard
        case .places:
            if isPlacesEnabled {
                placesCard
            }
        case .destination:
            destinationCard
        case .goals: goalsCard
        case .events: eventsCard
        case .linkedTasks: linkedTasksCard
        case .planning: planningCard
        case .linkURL: linkURLCard
        case .notes:
            if isNotesEnabled {
                notesCard
            }
        case .steps: stepsCard
        case .checklist: checklistCard
        case .image: imageCard
        case .voiceNote:
            if isNotesEnabled {
                voiceNoteCard
            }
        case .attachment: attachmentCard
        case .dangerZone: dangerZoneCard
        }
    }

    // MARK: Identity

}
