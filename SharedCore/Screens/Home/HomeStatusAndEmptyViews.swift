import SwiftUI

struct HomeStatusBadgeStyle {
    let title: String
    let systemImage: String
    let foregroundColor: Color
    let backgroundColor: Color

    init(
        title: String,
        systemImage: String,
        foregroundColor: Color,
        backgroundColor: Color
    ) {
        self.title = title
        self.systemImage = systemImage
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }

    init(
        _ style: (
            title: String,
            systemImage: String,
            foregroundColor: Color,
            backgroundColor: Color
        )
    ) {
        self.init(
            title: style.title,
            systemImage: style.systemImage,
            foregroundColor: style.foregroundColor,
            backgroundColor: style.backgroundColor
        )
    }
}

struct HomeStatusBadgeView: View {
    let style: HomeStatusBadgeStyle?

    var body: some View {
        if let style {
            HStack(spacing: 4) {
                Image(systemName: style.systemImage)
                    .imageScale(.small)

                Text(style.title)
                    .lineLimit(1)
            }
            .font(.subheadline.weight(.semibold))
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(2)
            .foregroundStyle(style.foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(style.backgroundColor, in: Capsule())
        }
    }
}

struct HomeTaskTypeBadgeView: View {
    let isTodo: Bool

    private var title: String {
        isTodo ? "Todo" : "Routine"
    }

    private var tint: Color {
        isTodo ? .blue : .green
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

struct HomeEmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    let actionTitle: String
    let action: (() -> Void)?

    init(
        title: String,
        message: String,
        systemImage: String,
        actionTitle: String = "Add Task",
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            if let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

struct HomeInlineEmptyStateRowView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 40)
    }
}
