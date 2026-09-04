import SwiftUI

/// A shared iPhone rendering of semantic task identity. Each workspace still
/// supplies its own context text and decides which semantic badges are useful.
struct TaskSemanticIOSRowLabel: View {
    enum IdentityKind: Equatable {
        case task
        case taskGroup
        case containerGroup
    }

    let presentation: TaskRowSemanticPresentation
    let contextText: String?
    var identityKind: IdentityKind = .task
    var showsTaskType = false
    var showsStatus = true
    var showsPin = false
    var showsInheritedValue = false

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            identityIcon

            VStack(alignment: .leading, spacing: 4) {
                Text(presentation.name)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                semanticBadges

                if let contextText, !contextText.isEmpty {
                    Text(contextText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer(minLength: 2)

            trailingIndicators
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var identityIcon: some View {
        switch identityKind {
        case .task:
            taskIcon
        case .taskGroup:
            taskGroupIcon
        case .containerGroup:
            containerGroupIcon
        }
    }

    private var taskIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(identityTint.opacity(0.13))

            Text(presentation.emoji)
                .font(.title3)

            if presentation.hasImage {
                Image(systemName: "photo.fill")
                    .font(.system(size: 8, weight: .semibold))
                    .padding(2)
                    .background(.background, in: Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(2)
            }
        }
        .frame(width: 38, height: 38)
        .accessibilityHidden(true)
    }

    private var taskGroupIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(identityTint.opacity(0.07))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(identityTint.opacity(0.26), lineWidth: 1)
                }
                .frame(width: 31, height: 31)
                .offset(x: 3, y: -3)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(identityTint.opacity(0.14))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(identityTint.opacity(0.40), lineWidth: 1)
                }
                .frame(width: 31, height: 31)
                .offset(x: -2, y: 2)

            Text(presentation.emoji)
                .font(.body)
                .offset(x: -2, y: 2)
        }
        .frame(width: 38, height: 38)
        .accessibilityHidden(true)
    }

    private var containerGroupIcon: some View {
        ZStack {
            Image(systemName: "folder.fill")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(identityTint.opacity(0.20))

            Image(systemName: "folder")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(identityTint.opacity(0.78))

            Text(presentation.emoji)
                .font(.system(size: 13))
                .offset(y: 3)
        }
        .frame(width: 38, height: 38)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var semanticBadges: some View {
        let taskType = showsTaskType ? presentation.taskType : nil
        let status = showsStatus ? presentation.status : nil

        if taskType != nil || status != nil {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 5) {
                    badges(taskType: taskType, status: status)
                }

                VStack(alignment: .leading, spacing: 4) {
                    badges(taskType: taskType, status: status)
                }
            }
        }
    }

    @ViewBuilder
    private func badges(
        taskType: RoutineTaskType?,
        status: TaskRowSemanticPresentation.Status?
    ) -> some View {
        if let taskType {
            let title = taskType == .todo ? "One-time" : "Repeating"
            badge(
                title,
                systemImage: taskType == .todo ? "checklist" : "repeat",
                tint: taskType == .todo ? .blue : .green,
                accessibilityLabel: "Task type: \(title)"
            )
        }

        if let status {
            badge(
                status.title,
                systemImage: status.systemImage,
                tint: tint(for: status.tone),
                accessibilityLabel: "Status: \(status.title)"
            )
        }
    }

    private func badge(
        _ title: String,
        systemImage: String,
        tint: Color,
        accessibilityLabel: String
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            Text(title)
                .foregroundStyle(.primary)
        }
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.06), in: Capsule())
        .overlay {
            Capsule()
                .stroke(tint.opacity(0.34), lineWidth: 0.75)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var trailingIndicators: some View {
        VStack(spacing: 8) {
            if showsPin && presentation.isPinned {
                Image(systemName: "pin.fill")
                    .accessibilityLabel("Pinned")
            }

            if showsInheritedValue {
                Image(systemName: "arrow.triangle.branch")
                    .accessibilityLabel("Inherited value")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }

    private var identityTint: Color {
        presentation.color.swiftUIColor ?? .accentColor
    }

    private func tint(for tone: TaskRowSemanticTone) -> Color {
        switch tone {
        case .secondary: return .secondary
        case .blue: return .blue
        case .green: return .green
        case .indigo: return .indigo
        case .orange: return .orange
        case .red: return .red
        case .teal: return .teal
        }
    }
}
