import SwiftData
import SwiftUI

struct TimelineView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \RoutineLog.timestamp, order: .reverse) private var logs: [RoutineLog]
    @Query private var tasks: [RoutineTask]

    @State private var selectedRange: TimelineRange = .week
    @State private var filterType: TimelineFilterType = .all

    init(
        selectedRange: TimelineRange = .week,
        filterType: TimelineFilterType = .all
    ) {
        _selectedRange = State(initialValue: selectedRange)
        _filterType = State(initialValue: filterType)
    }

    private var entries: [TimelineEntry] {
        TimelineLogic.filteredEntries(
            logs: logs,
            tasks: tasks,
            range: selectedRange,
            filterType: filterType,
            now: Date(),
            calendar: calendar
        )
    }

    private var groupedByDay: [(date: Date, entries: [TimelineEntry])] {
        TimelineLogic.groupedByDay(entries: entries, calendar: calendar)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Timeline")
#if !os(macOS)
                .navigationBarTitleDisplayMode(.large)
#endif
        }
    }

    @ViewBuilder
    private var content: some View {
        if logs.isEmpty {
            ContentUnavailableView(
                "No completions yet",
                systemImage: "clock.arrow.circlepath",
                description: Text("Completed routines and todos will appear here in chronological order.")
            )
        } else {
            VStack(spacing: 0) {
                filterBar
                    .padding(.horizontal)
                    .padding(.vertical, 10)

                if groupedByDay.isEmpty {
                    ContentUnavailableView(
                        "No matches",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Try a different time range or filter.")
                    )
                } else {
                    timelineList
                }
            }
        }
    }

    private var filterBar: some View {
        VStack(spacing: 10) {
            Picker("Range", selection: $selectedRange) {
                ForEach(TimelineRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)

            if tasks.contains(where: { $0.isOneOffTask }) {
                Picker("Type", selection: $filterType) {
                    ForEach(TimelineFilterType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var timelineList: some View {
        List {
            ForEach(groupedByDay, id: \.date) { section in
                Section {
                    ForEach(section.entries) { entry in
                        timelineRow(entry)
                    }
                } header: {
                    Text(TimelineLogic.daySectionTitle(for: section.date, calendar: calendar))
                }
            }
        }
        .listStyle(.plain)
    }

    private func timelineRow(_ entry: TimelineEntry) -> some View {
        HStack(spacing: 12) {
            Text(entry.taskEmoji)
                .font(.title2)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.taskName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Text(entry.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text(entry.isOneOff ? "Todo" : "Routine")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(entry.isOneOff
                            ? Color.purple.opacity(0.15)
                            : Color.accentColor.opacity(0.15)
                        )
                )
                .foregroundStyle(entry.isOneOff ? .purple : .accentColor)
        }
        .padding(.vertical, 2)
    }
}
