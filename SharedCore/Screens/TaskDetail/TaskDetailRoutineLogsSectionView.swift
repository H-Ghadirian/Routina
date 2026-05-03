import SwiftUI

struct TaskDetailRoutineLogsSectionView<RowContent: View>: View {
    let logs: [RoutineLog]
    @Binding var isExpanded: Bool
    @Binding var isShowingAllLogs: Bool
    let createdAtBadgeValue: String?
    let background: Color
    let stroke: Color
    let rowContent: (Int, RoutineLog, [RoutineLog]) -> RowContent

    init(
        logs: [RoutineLog],
        isExpanded: Binding<Bool>,
        isShowingAllLogs: Binding<Bool>,
        createdAtBadgeValue: String?,
        background: Color,
        stroke: Color,
        @ViewBuilder rowContent: @escaping (Int, RoutineLog, [RoutineLog]) -> RowContent
    ) {
        self.logs = logs
        self._isExpanded = isExpanded
        self._isShowingAllLogs = isShowingAllLogs
        self.createdAtBadgeValue = createdAtBadgeValue
        self.background = background
        self.stroke = stroke
        self.rowContent = rowContent
    }

    var body: some View {
        TaskDetailSectionCardView(background: background, stroke: stroke) {
            VStack(alignment: .leading, spacing: 8) {
                TaskDetailCollapsibleSectionHeaderView(
                    title: "Routine Logs",
                    count: logs.count,
                    isExpanded: isExpanded,
                    onToggle: { isExpanded.toggle() }
                )

                if let createdAtBadgeValue {
                    Label("Created \(createdAtBadgeValue)", systemImage: "calendar.badge.plus")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if isExpanded {
                    if logs.isEmpty {
                        Text("No logs yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        let displayedLogs = TaskDetailLogPresentation.displayedLogs(logs, showingAll: isShowingAllLogs)
                        ForEach(Array(displayedLogs.enumerated()), id: \.offset) { index, log in
                            rowContent(index, log, displayedLogs)

                            if index < displayedLogs.count - 1 {
                                Divider()
                            }
                        }

                        if logs.count > 3 {
                            Button(isShowingAllLogs ? "Show less" : "See all (\(logs.count))") {
                                isShowingAllLogs.toggle()
                            }
                            .font(.footnote.weight(.semibold))
                            .padding(.top, 4)
                        }
                    }
                }
            }
        }
    }
}
