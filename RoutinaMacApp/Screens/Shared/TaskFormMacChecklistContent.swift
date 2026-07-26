import SwiftUI

struct TaskFormMacChecklistComposer: View {
    let model: TaskFormModel

    var body: some View {
        if model.scheduleMode.wrappedValue.isChecklistDrivenMode {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    titleField
                    intervalControl
                    addButton
                }

                VStack(alignment: .leading, spacing: 10) {
                    titleField
                    HStack(spacing: 12) {
                        intervalControl
                        addButton
                    }
                }
            }
        } else {
            HStack(alignment: .center, spacing: 12) {
                titleField
                addButton
            }
        }
    }

    private var titleField: some View {
        TextField("Bread", text: model.checklistItemDraftTitle)
            .textFieldStyle(.roundedBorder)
            .onSubmit { model.onAddChecklistItem() }
    }

    private var intervalControl: some View {
        Stepper(value: model.checklistItemDraftInterval, in: 1...365) {
            Text(TaskFormPresentation.checklistIntervalLabel(for: model.checklistItemDraftInterval.wrappedValue))
        }
        .fixedSize()
    }

    private var addButton: some View {
        Button("Add Item") { model.onAddChecklistItem() }
            .buttonStyle(.bordered)
            .disabled(RoutineChecklistItem.normalizedTitle(model.checklistItemDraftTitle.wrappedValue) == nil)
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
                            if model.scheduleMode.wrappedValue.isChecklistDrivenMode {
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
