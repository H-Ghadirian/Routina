import SwiftUI

struct AddRoutineChecklistItemsView: View {
    let items: [RoutineChecklistItem]
    let showsInterval: Bool
    let intervalLabel: (Int) -> String
    let onRemoveItem: (RoutineChecklistItem.ID) -> Void

    var body: some View {
        if items.isEmpty {
            Label("No checklist items yet", systemImage: "checklist")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 8) {
                ForEach(items) { item in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if showsInterval {
                                Text(intervalLabel(item.intervalDays))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button(role: .destructive) {
                            onRemoveItem(item.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }
}
