import SwiftUI

struct HomeMacImportanceUrgencyMatrixView: View {
    @Binding var selectedFilter: ImportanceUrgencyFilterCell?
    let summaryText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(selectedFilter == nil ? "All levels selected" : "Show all levels") {
                selectedFilter = nil
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(selectedFilter == nil ? Color.accentColor : Color.primary)

            ImportanceUrgencyMatrixPicker(selectedFilter: $selectedFilter)
                .frame(maxWidth: 420, alignment: .leading)

            Text(summaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
