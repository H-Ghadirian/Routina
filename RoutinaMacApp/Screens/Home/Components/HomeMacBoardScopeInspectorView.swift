import SwiftUI

struct HomeMacBoardScopeInspectorView: View {
    let presentation: HomeBoardPresentation

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                summaryCard
                countsCard
                dateCard
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var summaryCard: some View {
        inspectorCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(presentation.scopeTitle, systemImage: presentation.scopeIcon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(presentation.scopeDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var countsCard: some View {
        inspectorCard(title: "Tasks") {
            VStack(alignment: .leading, spacing: 8) {
                statRow("Open", presentation.openTodoCount, tint: .secondary)
                statRow("In Progress", presentation.inProgressTodoCount, tint: .blue)
                statRow("Blocked", presentation.blockedTodoCount, tint: .red)

                if !presentation.isBacklogScope {
                    statRow("Done", presentation.doneTodoCount, tint: .green)
                }
            }
        }
    }

    private var dateCard: some View {
        inspectorCard(title: presentation.scopeDateCardTitle) {
            VStack(alignment: .leading, spacing: 8) {
                switch presentation.selectedScope {
                case .backlog:
                    dateRow("Created", nil)
                case let .namedBacklog(backlogID):
                    let backlog = presentation.backlogs.first { $0.id == backlogID }
                    dateRow("Created", backlog?.createdAt)
                case .currentSprint:
                    if presentation.activeSprints.isEmpty {
                        Text("No active sprint.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(presentation.activeSprints) { sprint in
                            sprintDateSummary(sprint)
                        }
                    }
                case let .sprint(sprintID):
                    if let sprint = presentation.sprints.first(where: { $0.id == sprintID }) {
                        sprintDateSummary(sprint)
                    }
                }
            }
        }
    }

    private func inspectorCard<Content: View>(
        title: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func statRow(_ title: String, _ value: Int, tint: Color) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            Text("\(value)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func sprintDateSummary(_ sprint: BoardSprint) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sprint.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            dateRow("Start", sprint.startedAt)
            dateRow("Finish", sprint.finishedAt)

            if let activeDayTitle = presentation.activeDayTitle(for: sprint) {
                detailRow("Day", activeDayTitle)
            }
        }
    }

    private func dateRow(_ title: String, _ date: Date?) -> some View {
        detailRow(title, date.map(presentation.dateLabel(for:)) ?? "Not set")
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}
