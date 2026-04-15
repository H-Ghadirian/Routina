import SwiftUI

struct HomeMacRoutineFiltersDetailView<TagContent: View, PlaceContent: View>: View {
    let availableFilters: [RoutineListFilter]
    @Binding var selectedFilter: RoutineListFilter
    @Binding var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    let importanceUrgencySummary: String
    let showsTagSection: Bool
    let showsPlaceSection: Bool
    @ViewBuilder let tagSectionContent: () -> TagContent
    @ViewBuilder let placeSectionContent: () -> PlaceContent

    var body: some View {
        Group {
            HomeMacSidebarSectionCard {
                filterPicker
            }

            HomeMacSidebarSectionCard(title: "Importance & Urgency") {
                HomeMacImportanceUrgencyMatrixView(
                    selectedFilter: $selectedImportanceUrgencyFilter,
                    summaryText: importanceUrgencySummary
                )
            }

            if showsTagSection {
                HomeMacSidebarSectionCard {
                    tagSectionContent()
                }
            }

            if showsPlaceSection {
                HomeMacSidebarSectionCard {
                    placeSectionContent()
                }
            }
        }
    }

    private var filterPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Show")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 92), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(availableFilters) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .foregroundStyle(selectedFilter == filter ? Color.white : Color.primary)
                            .background(
                                Capsule()
                                    .fill(selectedFilter == filter ? Color.accentColor : Color.secondary.opacity(0.10))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
