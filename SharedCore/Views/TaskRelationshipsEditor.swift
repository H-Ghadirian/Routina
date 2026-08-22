import Foundation
import SwiftUI

struct TaskRelationshipsEditor<SearchField: View>: View {
    let relationships: [RoutineTaskRelationship]
    let candidates: [RoutineTaskRelationshipCandidate]
    let addRelationship: (UUID, RoutineTaskRelationshipKind) -> Void
    let removeRelationship: (UUID) -> Void
    let createLinkedTask: ((RoutineTaskRelationshipKind) -> Void)?

    private let searchField: (Binding<String>) -> SearchField

    @State private var isPickerPresented = false
    @State private var selectedRelationshipKind: RoutineTaskRelationshipKind = .related

    init(
        relationships: [RoutineTaskRelationship],
        candidates: [RoutineTaskRelationshipCandidate],
        addRelationship: @escaping (UUID, RoutineTaskRelationshipKind) -> Void,
        removeRelationship: @escaping (UUID) -> Void,
        createLinkedTask: ((RoutineTaskRelationshipKind) -> Void)? = nil,
        @ViewBuilder searchField: @escaping (Binding<String>) -> SearchField
    ) {
        self.relationships = relationships
        self.candidates = candidates
        self.addRelationship = addRelationship
        self.removeRelationship = removeRelationship
        self.createLinkedTask = createLinkedTask
        self.searchField = searchField
    }

    private var resolvedRelationships: [RoutineTaskResolvedRelationship] {
        let candidateByID = RoutineTaskRelationshipCandidate.lookupByID(candidates)
        return relationships.compactMap { relationship in
            guard let candidate = candidateByID[relationship.targetTaskID] else { return nil }
            return RoutineTaskResolvedRelationship(
                taskID: candidate.id,
                taskName: candidate.displayName,
                taskEmoji: candidate.emoji,
                kind: relationship.kind,
                status: candidate.status
            )
        }
        .sorted {
            if $0.kind.sortOrder != $1.kind.sortOrder {
                return $0.kind.sortOrder < $1.kind.sortOrder
            }
            return $0.taskName.localizedCaseInsensitiveCompare($1.taskName) == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if candidates.isEmpty {
                Text(
                    createLinkedTask == nil
                        ? "Create another task first to add a relationship."
                        : "There are no other tasks available to link."
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if resolvedRelationships.isEmpty {
                Text("No linked tasks yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(resolvedRelationships) { relationship in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(relationship.taskEmoji)
                                Text(relationship.taskName)
                                    .foregroundStyle(.primary)
                            }

                            TaskRelationshipKindMenuPicker(
                                selection: Binding(
                                    get: { relationship.kind },
                                    set: { addRelationship(relationship.taskID, $0) }
                                ),
                                fillsAvailableWidth: false
                            )
                        }

                        Spacer(minLength: 0)

                        Button {
                            removeRelationship(relationship.taskID)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove relationship to \(relationship.taskName)")
                    }
                    .padding(12)
                    .routinaGlassCard(cornerRadius: 10, tint: .secondary, tintOpacity: 0.08, interactive: true)
                }
            }

            relationshipActions
        }
        .sheet(isPresented: $isPickerPresented) {
            TaskRelationshipPickerSheet(
                candidates: candidates,
                linkedTaskIDs: Set(relationships.map(\.targetTaskID)),
                initialKind: selectedRelationshipKind,
                onSelect: { taskID, kind in
                    addRelationship(taskID, kind)
                    isPickerPresented = false
                },
                searchField: searchField
            )
        }
    }

    @ViewBuilder
    private var relationshipActions: some View {
        if let createLinkedTask {
            HStack(spacing: 12) {
                TaskRelationshipKindMenuPicker(
                    selection: $selectedRelationshipKind,
                    fillsAvailableWidth: false
                )

                Button {
                    createLinkedTask(selectedRelationshipKind)
                } label: {
                    Label(TaskRelationshipActionPresentation.createTaskTitle, systemImage: "plus.circle")
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)

                Button {
                    isPickerPresented = true
                } label: {
                    Label(TaskRelationshipActionPresentation.linkTaskTitle, systemImage: "link")
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(candidates.isEmpty)
            }
        } else {
            Button {
                isPickerPresented = true
            } label: {
                Label("Add linked task", systemImage: "plus.circle")
            }
            .disabled(candidates.isEmpty)
        }
    }
}

struct TaskRelationshipPickerSheet<SearchField: View>: View {
    let candidates: [RoutineTaskRelationshipCandidate]
    let linkedTaskIDs: Set<UUID>
    let onSelect: (UUID, RoutineTaskRelationshipKind) -> Void
    let sourceTaskTitle: String?
    let createLinkedTask: ((RoutineTaskRelationshipKind) -> Void)?

    private let searchField: (Binding<String>) -> SearchField

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedKind: RoutineTaskRelationshipKind = .related
    @State private var selectedCandidateID: UUID?

    init(
        candidates: [RoutineTaskRelationshipCandidate],
        linkedTaskIDs: Set<UUID>,
        initialKind: RoutineTaskRelationshipKind,
        onSelect: @escaping (UUID, RoutineTaskRelationshipKind) -> Void,
        sourceTaskTitle: String? = nil,
        createLinkedTask: ((RoutineTaskRelationshipKind) -> Void)? = nil,
        @ViewBuilder searchField: @escaping (Binding<String>) -> SearchField
    ) {
        self.candidates = candidates
        self.linkedTaskIDs = linkedTaskIDs
        self.onSelect = onSelect
        self.sourceTaskTitle = sourceTaskTitle
        self.createLinkedTask = createLinkedTask
        self.searchField = searchField
        _selectedKind = State(initialValue: initialKind)
    }

    private var availableCandidates: [RoutineTaskRelationshipCandidate] {
        RoutineTaskRelationshipCandidate.uniqueByID(candidates)
            .filter { !linkedTaskIDs.contains($0.id) }
    }

    private var filteredCandidates: [RoutineTaskRelationshipCandidate] {
        TaskRelationshipCandidateSearch.filteredCandidates(availableCandidates, matching: searchText)
    }

    private var selectedCandidate: RoutineTaskRelationshipCandidate? {
        filteredCandidates.first { $0.id == selectedCandidateID }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    if let sourceTaskTitle = normalizedSourceTaskTitle {
                        Text("Link another task to \u{201c}\(sourceTaskTitle)\u{201d}")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    relationshipTypeSelector
                    taskSearchField
                }
                .padding()

                Divider()

                manualTaskSelection
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .navigationTitle("Link Task")
#if os(macOS)
            .frame(minWidth: 520, minHeight: 420)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var normalizedSourceTaskTitle: String? {
        guard let sourceTaskTitle else { return nil }
        let trimmedTitle = sourceTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? nil : trimmedTitle
    }

    private var relationshipTypeSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Relationship")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TaskRelationshipKindMenuPicker(selection: $selectedKind)
        }
    }

    private var taskSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            searchField($searchText)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .routinaGlassCard(cornerRadius: 12, tint: .secondary, tintOpacity: 0.08, interactive: true)
    }

    @ViewBuilder
    private var manualTaskSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let createLinkedTask {
                Button {
                    createLinkedTask(selectedKind)
                    dismiss()
                } label: {
                    Label(TaskRelationshipActionPresentation.createTaskTitle, systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
            }

            Text("Choose Task")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if filteredCandidates.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(availableCandidates.isEmpty ? "All tasks are already linked." : "No matching tasks.")
                        .foregroundStyle(.secondary)

                    if !availableCandidates.isEmpty && !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Try part of the task name or a copied task link.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredCandidates) { candidate in
                            Button {
                                selectedCandidateID = candidate.id
                            } label: {
                                HStack(spacing: 10) {
                                    Text(candidate.emoji)
                                        .font(.title3)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(candidate.displayName)
                                            .foregroundStyle(.primary)

                                        if candidate.status != .onTrack {
                                            Label(candidate.status.title, systemImage: candidate.status.systemImage)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer(minLength: 0)

                                    if selectedCandidateID == candidate.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.tint)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(
                                            selectedCandidateID == candidate.id
                                                ? Color.accentColor.opacity(0.12)
                                                : Color.clear
                                        )
                                )
                            }
                            .buttonStyle(.plain)

                            if candidate.id != filteredCandidates.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }

            if let selectedCandidate {
                relationshipConfirmation(for: selectedCandidate)
            }
        }
    }

    private func relationshipConfirmation(
        for candidate: RoutineTaskRelationshipCandidate
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(
                TaskRelationshipActionPresentation.effectDescription(
                    kind: selectedKind,
                    sourceTaskTitle: normalizedSourceTaskTitle ?? "This task",
                    targetTaskTitle: candidate.displayName
                )
            )
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)

            Button("Add Relationship") {
                onSelect(candidate.id, selectedKind)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(12)
        .routinaGlassCard(
            cornerRadius: 12,
            tint: selectedKind == .related ? .secondary : .accentColor,
            tintOpacity: 0.09,
            interactive: false
        )
    }

}

struct TaskRelationshipKindMenuPicker: View {
    @Binding var selection: RoutineTaskRelationshipKind
    var fillsAvailableWidth = true

    var body: some View {
        Menu {
            relationshipSection("General", kinds: [.related])
            relationshipSection("Dependency", kinds: [.blockedBy, .blocks])
            relationshipSection("Automatic Completion", kinds: [.doneWhen, .completes])
            relationshipSection("Optional Completion", kinds: [.canBeCompletedBy, .canComplete])
        } label: {
            HStack(spacing: 8) {
                Label(selection.sentenceFragment, systemImage: selection.systemImage)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: fillsAvailableWidth ? .infinity : nil, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .routinaGlassCard(
                cornerRadius: 10,
                tint: .secondary,
                tintOpacity: 0.10,
                interactive: true
            )
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: !fillsAvailableWidth, vertical: false)
        .accessibilityLabel("Relationship")
        .accessibilityValue(selection.sentenceFragment)
    }

    @ViewBuilder
    private func relationshipSection(
        _ title: String,
        kinds: [RoutineTaskRelationshipKind]
    ) -> some View {
        Section(title) {
            ForEach(kinds, id: \.self) { kind in
                Button {
                    selection = kind
                } label: {
                    Label(
                        kind.sentenceFragment,
                        systemImage: selection == kind ? "checkmark" : kind.systemImage
                    )
                }
            }
        }
    }
}

enum TaskRelationshipCandidateSearch {
    static func filteredCandidates(
        _ candidates: [RoutineTaskRelationshipCandidate],
        matching query: String
    ) -> [RoutineTaskRelationshipCandidate] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return candidates }

        if let taskID = taskID(from: trimmedQuery) {
            return candidates.filter { $0.id == taskID }
        }

        let normalizedQuery = trimmedQuery.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        return candidates.filter { candidate in
            let normalizedName = candidate.displayName.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            return normalizedName.contains(normalizedQuery)
                || candidate.emoji.contains(trimmedQuery)
        }
    }

    private static func taskID(from query: String) -> UUID? {
        if let id = UUID(uuidString: query) {
            return id
        }

        guard let url = URL(string: query),
              case let .some(.task(taskID)) = RoutinaDeepLink(url: url)
        else {
            return nil
        }
        return taskID
    }
}
