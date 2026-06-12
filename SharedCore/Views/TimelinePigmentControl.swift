import SwiftUI

struct TimelinePigmentControl: View {
    @Binding var selection: TimelineFilterType
    var includesEventEmotion = true

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TimelineFilterType.visibleTimelinePigmentCases(includingEventEmotion: includesEventEmotion)) { type in
                    pigmentButton(for: type)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
        .accessibilityLabel("Timeline type")
    }

    private func pigmentButton(for type: TimelineFilterType) -> some View {
        let isSelected = selection == type
        let tint = type.timelinePigmentTint

        return Button {
            selection = type
        } label: {
            Label {
                Text(type.rawValue)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            } icon: {
                Image(systemName: type.timelinePigmentSystemImage)
                    .font(.caption.weight(.semibold))
                    .imageScale(.medium)
            }
            .foregroundStyle(isSelected ? tint : Color.secondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .routinaGlassPill(
                tint: isSelected ? tint : Color.secondary,
                tintOpacity: isSelected ? 0.22 : 0.08,
                interactive: true
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension TimelineFilterType {
    var timelinePigmentSystemImage: String {
        switch self {
        case .all:
            return "square.grid.2x2.fill"
        case .routines:
            return "arrow.clockwise"
        case .todos:
            return "checkmark.circle.fill"
        case .focus:
            return "timer"
        case .notes:
            return "note.text"
        case .places:
            return "mappin.and.ellipse"
        case .emotions:
            return "face.smiling"
        case .sleep:
            return "bed.double.fill"
        case .events:
            return "calendar"
        case .done:
            return "checkmark.seal.fill"
        case .missed:
            return "exclamationmark.triangle.fill"
        case .canceled:
            return "xmark.seal.fill"
        }
    }

    var timelinePigmentTint: Color {
        switch self {
        case .all:
            return .accentColor
        case .routines:
            return .teal
        case .todos:
            return .green
        case .focus:
            return .cyan
        case .notes:
            return .indigo
        case .places:
            return .orange
        case .emotions:
            return .pink
        case .sleep:
            return .blue
        case .events:
            return .purple
        case .done:
            return .green
        case .missed:
            return .yellow
        case .canceled:
            return .orange
        }
    }
}
