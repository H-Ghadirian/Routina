import SwiftUI

enum HomeMacTodoBoardFormatting {
    static func dueLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    static func tint(for state: TodoState) -> Color {
        switch state {
        case .ready, .paused:
            return .orange
        case .inProgress:
            return .blue
        case .blocked:
            return .red
        case .done:
            return .green
        }
    }
}

struct HomeMacTodoBoardBadgeView: View {
    let title: String
    let tint: Color
    let isCompactLayout: Bool

    var body: some View {
        Text(title)
            .font((isCompactLayout ? Font.system(size: 10) : Font.caption2).weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, isCompactLayout ? 2 : 3)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }
}

struct HomeMacTodoBoardInsertionIndicator: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)

            Rectangle()
                .fill(Color.accentColor)
                .frame(height: 3)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
}

struct HomeMacTodoBoardColumnDropSpacer: View {
    let column: HomeMacTodoBoardView.Column
    let isHighlighted: Bool
    let isCompactLayout: Bool

    var body: some View {
        VStack(spacing: 8) {
            if isHighlighted {
                HomeMacTodoBoardInsertionIndicator()
            }

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    isHighlighted
                        ? column.tint.opacity(0.14)
                        : Color.clear
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isHighlighted
                                ? column.tint.opacity(0.45)
                                : Color.primary.opacity(0.06),
                            style: StrokeStyle(lineWidth: isHighlighted ? 1.5 : 1, dash: [6, 6])
                        )
                )
                .frame(maxWidth: .infinity, minHeight: column.tasks.isEmpty ? 160 : (isCompactLayout ? 56 : 72))
        }
        .animation(.spring(response: 0.2, dampingFraction: 0.86), value: isHighlighted)
    }
}

struct HomeMacTodoBoardEmptyStateView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.grid.3x3.topleft.filled")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("Nothing on this board yet")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Try another scope, change filters, or move a todo into this board.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}
