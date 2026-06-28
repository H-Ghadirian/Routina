import SwiftUI

struct HomeMacSearchPanelView: View {
    let hasCustomFiltersApplied: Bool
    let activeFiltersSummary: String?
    let onClearFilters: () -> Void

    var body: some View {
        if hasCustomFiltersApplied {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Button("Clear All Filters", action: onClearFilters)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)

                if let activeFiltersSummary, !activeFiltersSummary.isEmpty {
                    Text(activeFiltersSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
    }
}
