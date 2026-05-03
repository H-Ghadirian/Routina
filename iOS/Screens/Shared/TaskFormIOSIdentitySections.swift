import SwiftUI

struct TaskFormIOSNameSection: View {
    let model: TaskFormModel
    let isNameFocused: FocusState<Bool>.Binding

    var body: some View {
        Section(header: Text("Name")) {
            TextField("Task name", text: model.name)
                .focused(isNameFocused)
            if let msg = model.nameValidationMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

struct TaskFormIOSTaskTypeSection: View {
    let model: TaskFormModel
    let presentation: TaskFormPresentation

    var body: some View {
        Section(header: Text("Task Type")) {
            Picker("Task Type", selection: model.taskType) {
                Text("Routine").tag(RoutineTaskType.routine)
                Text("Todo").tag(RoutineTaskType.todo)
            }
            .pickerStyle(.segmented)

            Text(presentation.taskTypeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct TaskFormIOSEmojiSection: View {
    let model: TaskFormModel

    var body: some View {
        Section(header: Text("Emoji")) {
            HStack(spacing: 12) {
                Text("Selected").foregroundColor(.secondary)
                Text(model.emoji.wrappedValue)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                Spacer()
                Button("Choose Emoji") { model.isEmojiPickerPresented.wrappedValue = true }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(model.emojiOptions, id: \.self) { emoji in
                        Button {
                            model.emoji.wrappedValue = emoji
                        } label: {
                            Text(emoji)
                                .font(.title2)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle().fill(
                                        model.emoji.wrappedValue == emoji
                                            ? Color.blue.opacity(0.2)
                                            : Color.clear
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
