import SwiftUI

struct HomeMacTimelineSidebarView<RowContent: View>: View {
    let timelineEntryCount: Int
    let groupedEntries: [(date: Date, entries: [TimelineEntry])]
    @Binding var selection: HomeFeature.MacSidebarSelection?
    let sectionTitle: (Date) -> String
    @ViewBuilder let rowContent: (TimelineEntry, Int) -> RowContent

    var body: some View {
        Group {
            if timelineEntryCount == 0 {
                ContentUnavailableView(
                    "No timeline entries yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Completed items, notes, place check-ins, emotions, and sleep records will appear here in chronological order.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if groupedEntries.isEmpty {
                ContentUnavailableView(
                    "No matching timeline entries",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Try a different search, time range, or done type.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selection) {
                    ForEach(invertedGroupedEntries, id: \.date) { section in
                        Section {
                            ForEach(section.entries, id: \.id) { entry in
                                rowContent(entry, rowNumbersByEntryID[entry.id] ?? 1)
                                    .id(entry.id)
                                    .scaleEffect(x: 1, y: -1)
                            }
                        } header: {
                            Text(sectionTitle(section.date))
                                .scaleEffect(x: 1, y: -1)
                        }
                    }
                }
                .listStyle(.sidebar)
                .scaleEffect(x: 1, y: -1)
            }
        }
    }

    private var invertedGroupedEntries: [(date: Date, entries: [TimelineEntry])] {
        groupedEntries.reversed().map { section in
            (date: section.date, entries: Array(section.entries.reversed()))
        }
    }

    private var rowNumbersByEntryID: [UUID: Int] {
        var result: [UUID: Int] = [:]
        var rowNumber = 1
        for section in groupedEntries {
            for entry in section.entries {
                result[entry.id] = rowNumber
                rowNumber += 1
            }
        }
        return result
    }
}
