import SwiftUI

struct HomeMacSearchPanelView<SearchField: View>: View {
    let hasCustomFiltersApplied: Bool
    let activeFiltersSummary: String?
    let isFilterDetailPresented: Bool
    let onToggleFilters: () -> Void
    let onClearFilters: () -> Void
    @ViewBuilder let searchField: () -> SearchField

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                searchField()

                Button(action: onToggleFilters) {
                    Image(
                        systemName: hasCustomFiltersApplied
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle"
                    )
                    .font(.title3)
                    .foregroundStyle(
                        isFilterDetailPresented || hasCustomFiltersApplied
                            ? Color.accentColor
                            : Color.secondary
                    )
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                isFilterDetailPresented
                                    ? Color.accentColor.opacity(0.14)
                                    : Color.secondary.opacity(0.07)
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show filters")
            }

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
}
