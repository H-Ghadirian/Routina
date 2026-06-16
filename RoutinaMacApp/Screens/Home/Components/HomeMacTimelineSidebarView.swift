import SwiftUI

struct HomeMacTimelineSidebarView<RowContent: View>: View {
    let timelineEntryCount: Int
    let groupedEntries: [(date: Date, entries: [TimelineEntry])]
    @Binding var selection: HomeFeature.MacSidebarSelection?
    @Binding var scrollRequest: MacTimelineSidebarScrollRequest?
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
                ScrollViewReader { scrollProxy in
                    List(selection: $selection) {
                        ForEach(groupedEntries, id: \.date) { section in
                            Section {
                                ForEach(section.entries, id: \.id) { entry in
                                    rowContent(entry, rowNumbersByEntryID[entry.id] ?? 1)
                                        .id(entry.id)
                                }
                            } header: {
                                Text(sectionTitle(section.date))
                            }
                        }
                    }
                    .listStyle(.sidebar)
                    .onAppear {
                        selectAndScrollToResolvedTimelineEntry(with: scrollProxy)
                    }
                    .onChange(of: visibleEntryIDs) { _, _ in
                        selectAndScrollToResolvedTimelineEntry(with: scrollProxy)
                    }
                    .onChange(of: scrollRequest) { _, _ in
                        scrollToPendingTimelineEntry(with: scrollProxy)
                    }
                }
            }
        }
    }

    private var visibleEntryIDs: [UUID] {
        groupedEntries.flatMap { section in
            section.entries.map(\.id)
        }
    }

    private var selectedEntryID: UUID? {
        guard case let .timelineEntry(entryID) = selection else { return nil }
        return entryID
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

    private func selectAndScrollToResolvedTimelineEntry(with proxy: ScrollViewProxy) {
        guard let entryID = TimelineSelectionSupport.resolvedSelection(
            currentSelection: selectedEntryID,
            visibleEntryIDs: visibleEntryIDs,
            usesSidebarLayout: true
        ) else { return }

        if selectedEntryID != entryID {
            selection = .timelineEntry(entryID)
        }
        scrollTimelineList(to: entryID, with: proxy)
    }

    private func scrollToPendingTimelineEntry(with proxy: ScrollViewProxy) {
        guard
            let entryID = scrollRequest?.entryID,
            visibleEntryIDs.contains(entryID)
        else { return }

        scrollTimelineList(to: entryID, with: proxy)
        scrollRequest = nil
    }

    private func scrollTimelineList(to entryID: UUID, with proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            proxy.scrollTo(entryID, anchor: .bottom)
        }
    }
}
