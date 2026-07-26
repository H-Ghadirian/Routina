import SwiftUI

struct StatsActiveItemsInfoPopover: View {
    let breakdown: StatsActiveItemsBreakdown

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            formulaRows
            Divider()
            todoBreakdown
        }
        .padding(16)
        .frame(width: 300, alignment: .leading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Active items")
                .font(.headline.weight(.semibold))

            Text("Calculated from the items matching the current Stats filters.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var formulaRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            StatsActiveItemsFormulaRow(
                title: "Matching items",
                formula: "\(breakdown.routineCount.formatted()) routines + \(breakdown.todoCount.formatted()) todos",
                result: breakdown.matchingCount.formatted()
            )

            StatsActiveItemsFormulaRow(
                title: "Active items",
                formula: "\(breakdown.matchingCount.formatted()) matching - \(breakdown.archivedCount.formatted()) archived",
                result: breakdown.activeCount.formatted()
            )
        }
    }

    private var todoBreakdown: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Todo breakdown")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("\(breakdown.openTodoCount.formatted()) open + \(breakdown.completedTodoCount.formatted()) completed + \(breakdown.canceledTodoCount.formatted()) canceled = \(breakdown.todoCount.formatted()) todos")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct StatsActiveItemsFormulaRow: View {
    let title: String
    let formula: String
    let result: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 12)

                Text(result)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
            }

            Text(formula)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
