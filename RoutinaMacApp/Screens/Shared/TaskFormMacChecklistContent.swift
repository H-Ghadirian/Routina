import SwiftUI

struct TaskFormMacChecklistComposer: View {
    let model: TaskFormModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Bread", text: model.checklistItemDraftTitle)
                .textFieldStyle(.roundedBorder)
                .onSubmit { model.onAddChecklistItem() }

            if model.scheduleMode.wrappedValue == .derivedFromChecklist {
                Stepper(value: model.checklistItemDraftInterval, in: 1...365) {
                    Text(TaskFormPresentation.checklistIntervalLabel(for: model.checklistItemDraftInterval.wrappedValue))
                }
            }

            Button("Add Item") { model.onAddChecklistItem() }
                .buttonStyle(.bordered)
                .disabled(RoutineChecklistItem.normalizedTitle(model.checklistItemDraftTitle.wrappedValue) == nil)
        }
    }
}

struct TaskFormMacChecklistItemsContent: View {
    let model: TaskFormModel

    var body: some View {
        if model.routineChecklistItems.isEmpty {
            Text("No checklist items yet")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 8) {
                ForEach(model.routineChecklistItems) { item in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if model.scheduleMode.wrappedValue == .derivedFromChecklist {
                                Text(TaskFormPresentation.checklistIntervalLabel(for: item.intervalDays))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button(role: .destructive) { model.onRemoveChecklistItem(item.id) } label: {
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
