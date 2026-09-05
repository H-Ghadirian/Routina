import SwiftUI

struct TaskFormIOSAddDetailsSection: View {
    let sections: [TaskFormCompactSection]
    let onReveal: (TaskFormCompactSection) -> Void

    var body: some View {
        Section {
            Menu {
                ForEach(sections, id: \.self) { section in
                    Button {
                        onReveal(section)
                    } label: {
                        Label(
                            section.iosAddDetailsTitle,
                            systemImage: section.iosAddDetailsSystemImage
                        )
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Label("Add details", systemImage: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }
}

private extension TaskFormCompactSection {
    var iosAddDetailsTitle: String {
        switch self {
        case .name: return "Name"
        case .taskType: return "Task type"
        case .taskDescription: return "Description"
        case .emoji: return "Emoji"
        case .color: return "Color"
        case .notes: return "Notes"
        case .voiceNote: return "Voice note"
        case .link: return "Links"
        case .planning: return "Planning"
        case .deadline: return "Deadline"
        case .reminder: return "Reminder"
        case .taskLadderValues: return "Task Ladder values"
        case .estimation: return TaskFormEffortPresentation.sectionTitle
        case .image: return "Image"
        case .attachment: return "File attachment"
        case .organization: return "Organization"
        case .goals: return "Goals"
        case .events: return "Events"
        case .relationships: return "Relationships"
        case .scheduleType: return "Schedule behavior"
        case .steps: return "Steps"
        case .checklist: return "Checklist"
        case .place: return "Places"
        case .destination: return "Address"
        case .repeatPattern: return "Repeat"
        case .delete: return "Delete task"
        }
    }

    var iosAddDetailsSystemImage: String {
        switch self {
        case .name: return "text.cursor"
        case .taskType: return "repeat"
        case .taskDescription: return "text.alignleft"
        case .emoji: return "face.smiling"
        case .color: return "paintpalette"
        case .notes: return "note.text"
        case .voiceNote: return "waveform"
        case .link: return "link"
        case .planning: return "calendar.badge.clock"
        case .deadline: return "calendar.badge.exclamationmark"
        case .reminder: return "bell"
        case .taskLadderValues: return "square.grid.2x2"
        case .estimation: return "timer"
        case .image: return "photo"
        case .attachment: return "paperclip"
        case .organization: return "tray.full"
        case .goals: return "target"
        case .events: return "calendar"
        case .relationships: return "point.3.connected.trianglepath.dotted"
        case .scheduleType: return "calendar.badge.clock"
        case .steps: return "list.number"
        case .checklist: return "checklist"
        case .place: return "mappin.and.ellipse"
        case .destination: return "mappin.and.ellipse"
        case .repeatPattern: return "repeat"
        case .delete: return "trash"
        }
    }
}
