import SwiftUI

struct HomeMacTimelineSidebarView<RowContent: View>: View {
    let timelineEntryCount: Int
    let groupedEntries: [(date: Date, entries: [TimelineEntry])]
    @Binding var selection: HomeFeature.MacSidebarSelection?
    @State private var timelineScrollPosition: UUID?
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
                ScrollViewReader { proxy in
                    List(selection: $selection) {
                        ForEach(Array(groupedEntries.enumerated()), id: \.element.date) { sectionIndex, section in
                            let sectionStart = groupedEntries.prefix(sectionIndex).reduce(0) { $0 + $1.entries.count }
                            Section(sectionTitle(section.date)) {
                                ForEach(Array(section.entries.enumerated()), id: \.element.id) { index, entry in
                                    rowContent(entry, sectionStart + index + 1)
                                        .id(entry.id)
                                }
                            }
                        }
                    }
                    .listStyle(.sidebar)
                    .defaultScrollAnchor(.bottom)
                    .scrollPosition(id: $timelineScrollPosition, anchor: .bottom)
                    .onAppear {
                        scrollToLatestEntry(using: proxy)
                    }
                    .onChange(of: latestEntryID) { _, _ in
                        scrollToLatestEntry(using: proxy)
                    }
                }
            }
        }
    }

    private var latestEntryID: UUID? {
        groupedEntries.last?.entries.last?.id
    }

    private func scrollToLatestEntry(using proxy: ScrollViewProxy) {
        guard let latestEntryID else { return }
        timelineScrollPosition = latestEntryID
        Task { @MainActor in
            await Task.yield()
            proxy.scrollTo(latestEntryID, anchor: .bottom)
            timelineScrollPosition = latestEntryID
        }
    }
}
