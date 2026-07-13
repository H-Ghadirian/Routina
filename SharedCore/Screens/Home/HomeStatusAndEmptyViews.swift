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
            .routinaGlassPill(tint: style.foregroundColor, tintOpacity: 0.12)
        }
    }
}

struct HomeTaskTypeBadgeView: View {
    let taskType: RoutineTaskType

    init(taskType: RoutineTaskType) {
        self.taskType = taskType
    }

    init(isTodo: Bool) {
        self.taskType = isTodo ? .todo : .routine
    }

    private var title: String {
        taskType.rawValue
    }

    private var tint: Color {
        switch taskType {
        case .routine:
            return .green
        case .todo:
            return .blue
        case .record:
            return .purple
        }
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .routinaGlassPill(tint: tint, tintOpacity: 0.12)
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

struct HomeLoadingStateView: View {
    let title: String
    let message: String
    let systemImage: String
    let showsSkeleton: Bool

    init(
        title: String = "Loading Home",
        message: String = "Fetching routines, todos, and recent activity.",
        systemImage: String = "arrow.triangle.2.circlepath",
        showsSkeleton: Bool = true
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.showsSkeleton = showsSkeleton
    }

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                    Image(systemName: systemImage)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(width: 56, height: 56)
                .homeShimmering()

                Text(title)
                    .font(.title3.weight(.semibold))

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }

            if showsSkeleton {
                HomeLoadingSkeletonListView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

private struct HomeLoadingSkeletonListView: View {
    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { index in
                HomeLoadingSkeletonRowView(index: index)
            }
        }
        .frame(maxWidth: 360)
    }
}

private struct HomeLoadingSkeletonRowView: View {
    let index: Int

    private var titleWidth: CGFloat {
        [0.72, 0.56, 0.66, 0.48][index % 4] * 230
    }

    private var metadataWidth: CGFloat {
        [0.46, 0.62, 0.38, 0.54][index % 4] * 230
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.secondary.opacity(0.16))
                .frame(width: 34, height: 34)
                .homeShimmering()

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.secondary.opacity(0.18))
                    .frame(width: titleWidth, height: 10)
                    .homeShimmering()

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: metadataWidth, height: 8)
                    .homeShimmering()
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .routinaGlassCard(cornerRadius: 8, tint: .secondary, tintOpacity: 0.05)
    }
}

private struct HomeShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay {
                    SwiftUI.TimelineView(.animation) { context in
                        GeometryReader { proxy in
                            let phase = context.date.timeIntervalSinceReferenceDate
                                .truncatingRemainder(dividingBy: 1.6) / 1.6
                            let width = proxy.size.width
                            let bandWidth = max(width * 0.45, 48)
                            let offset = -bandWidth + (width + bandWidth * 2) * phase

                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.primary.opacity(0.10),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: bandWidth)
                            .offset(x: offset)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .clipped()
        }
    }
}

private extension View {
    func homeShimmering() -> some View {
        modifier(HomeShimmerModifier())
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
