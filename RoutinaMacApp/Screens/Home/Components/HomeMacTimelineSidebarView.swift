import SwiftUI

struct HomeMacTimelineSidebarView<RowContent: View>: View {
    let timelineLogCount: Int
    let groupedEntries: [(date: Date, entries: [TimelineEntry])]
    @Binding var selection: HomeFeature.MacSidebarSelection?
    let sectionTitle: (Date) -> String
    @ViewBuilder let rowContent: (TimelineEntry, Int) -> RowContent

    var body: some View {
        Group {
            if timelineLogCount == 0 {
                ContentUnavailableView(
                    "No completions yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Completed routines and todos will appear here in chronological order.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if groupedEntries.isEmpty {
                ContentUnavailableView(
                    "No matching dones",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Try a different search, time range, or done type.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selection) {
                    ForEach(Array(groupedEntries.enumerated()), id: \.element.date) { sectionIndex, section in
                        let sectionStart = groupedEntries.prefix(sectionIndex).reduce(0) { $0 + $1.entries.count }
                        Section(sectionTitle(section.date)) {
                            ForEach(Array(section.entries.enumerated()), id: \.element.id) { index, entry in
                                rowContent(entry, sectionStart + index + 1)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }
}
