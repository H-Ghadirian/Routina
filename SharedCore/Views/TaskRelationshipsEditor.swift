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
                    .routinaGlassCard(cornerRadius: 10, tint: .secondary, tintOpacity: 0.08, interactive: true)
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
        TaskRelationshipCandidateSearch.filteredCandidates(availableCandidates, matching: searchText)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    TaskRelationshipKindChipPicker(selection: $selectedKind)

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

private struct TaskRelationshipKindChipPicker: View {
    @Binding var selection: RoutineTaskRelationshipKind

    var body: some View {
        HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(RoutineTaskRelationshipKind.allCases, id: \.self) { kind in
                Button {
                    selection = kind
                } label: {
                    Label(kind.title, systemImage: kind.systemImage)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(selection == kind ? Color.accentColor : Color.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .routinaGlassPill(
                            tint: selection == kind ? Color.accentColor : Color.secondary,
                            tintOpacity: selection == kind ? 0.18 : 0.10,
                            interactive: true
                        )
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityValue(selection == kind ? "Selected" : "")
                .accessibilityAddTraits(selection == kind ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Relationship Type")
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
