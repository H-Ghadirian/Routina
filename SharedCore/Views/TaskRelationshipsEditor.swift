import Foundation
import SwiftUI

struct TaskRelationshipsEditor<SearchField: View>: View {
    let relationships: [RoutineTaskRelationship]
    let candidates: [RoutineTaskRelationshipCandidate]
    let addRelationship: (UUID, RoutineTaskRelationshipKind) -> Void
    let removeRelationship: (UUID) -> Void

    private let searchField: (Binding<String>) -> SearchField

    @State private var isPickerPresented = false

    init(
        relationships: [RoutineTaskRelationship],
        candidates: [RoutineTaskRelationshipCandidate],
        addRelationship: @escaping (UUID, RoutineTaskRelationshipKind) -> Void,
        removeRelationship: @escaping (UUID) -> Void,
        @ViewBuilder searchField: @escaping (Binding<String>) -> SearchField
    ) {
        self.relationships = relationships
        self.candidates = candidates
        self.addRelationship = addRelationship
        self.removeRelationship = removeRelationship
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
            Button {
                isPickerPresented = true
            } label: {
                Label("Add linked task", systemImage: "plus.circle")
            }
            .disabled(candidates.isEmpty)

            if candidates.isEmpty {
                Text("Create another task first to add a relationship.")
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

                            Picker("", selection: Binding(
                                get: { relationship.kind },
                                set: { addRelationship(relationship.taskID, $0) }
                            )) {
                                ForEach(RoutineTaskRelationshipKind.allCases, id: \.self) { kind in
                                    Label(kind.title, systemImage: kind.systemImage).tag(kind)
                                }
                            }
                            .pickerStyle(.menu)
                            .font(.caption)
                            .labelsHidden()
                            .padding(.leading, -8)
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
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
                }
            }
        }
        .sheet(isPresented: $isPickerPresented) {
            TaskRelationshipPickerSheet(
                candidates: candidates,
                linkedTaskIDs: Set(relationships.map(\.targetTaskID)),
                onSelect: { taskID, kind in
                    addRelationship(taskID, kind)
                    isPickerPresented = false
                },
                searchField: searchField
            )
        }
    }
}

private struct TaskRelationshipPickerSheet<SearchField: View>: View {
    let candidates: [RoutineTaskRelationshipCandidate]
    let linkedTaskIDs: Set<UUID>
    let onSelect: (UUID, RoutineTaskRelationshipKind) -> Void

    private let searchField: (Binding<String>) -> SearchField

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedKind: RoutineTaskRelationshipKind = .related

    init(
        candidates: [RoutineTaskRelationshipCandidate],
        linkedTaskIDs: Set<UUID>,
        onSelect: @escaping (UUID, RoutineTaskRelationshipKind) -> Void,
        @ViewBuilder searchField: @escaping (Binding<String>) -> SearchField
    ) {
        self.candidates = candidates
        self.linkedTaskIDs = linkedTaskIDs
        self.onSelect = onSelect
        self.searchField = searchField
    }

    private var availableCandidates: [RoutineTaskRelationshipCandidate] {
        RoutineTaskRelationshipCandidate.uniqueByID(candidates)
            .filter { !linkedTaskIDs.contains($0.id) }
    }

    private var filteredCandidates: [RoutineTaskRelationshipCandidate] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return availableCandidates }
        let normalizedSearch = trimmedSearch.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        return availableCandidates.filter { candidate in
            let normalizedName = candidate.displayName.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            return normalizedName.contains(normalizedSearch)
                || candidate.emoji.contains(trimmedSearch)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Relationship Type", selection: $selectedKind) {
                        ForEach(RoutineTaskRelationshipKind.allCases, id: \.self) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

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
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
                }
                .padding()

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose Task")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if filteredCandidates.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(availableCandidates.isEmpty ? "All tasks are already linked." : "No matching tasks.")
                                .foregroundStyle(.secondary)

                            if !availableCandidates.isEmpty && !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Try part of the task name.")
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
                                        onSelect(candidate.id, selectedKind)
                                        dismiss()
                                    } label: {
                                        HStack(spacing: 10) {
                                            Text(candidate.emoji)
                                                .font(.title3)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(candidate.displayName)
                                                    .foregroundStyle(.primary)
                                                Text(selectedKind.title)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer(minLength: 0)
                                        }
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    if candidate.id != filteredCandidates.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .navigationTitle("Link Task")
            .frame(minWidth: 520, minHeight: 420)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
