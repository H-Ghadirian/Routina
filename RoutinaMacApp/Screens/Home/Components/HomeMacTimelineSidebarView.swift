import SwiftUI

struct HomeMacTimelineSidebarView<RowContent: View>: View {
    let timelineEntryCount: Int
    let groupedEntries: [(date: Date, entries: [TimelineEntry])]
    let presentationID: UUID
    let isActive: Bool
    let allowsFallbackSelection: Bool
    let showsPlaces: Bool
    let showsNotes: Bool
    let showsAway: Bool
    @Binding var positionedPresentationID: UUID?
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
                    description: Text(emptyTimelineDescription)
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
                    .id(presentationID)
                    .listStyle(.sidebar)
                    .onAppear {
                        if isPositionedForCurrentPresentation {
                            if isActive {
                                selectResolvedTimelineEntry()
                            }
                        } else {
                            positionInitialTimelineEntry(
                                with: scrollProxy,
                                shouldSelect: isActive && allowsFallbackSelection
                            )
                        }
                    }
                    .onChange(of: visibleEntryIDs) { _, _ in
                        if !isPositionedForCurrentPresentation {
                            positionInitialTimelineEntry(
                                with: scrollProxy,
                                shouldSelect: isActive && allowsFallbackSelection
                            )
                        } else if isActive {
                            if !scrollToPendingTimelineEntry(with: scrollProxy) {
                                selectResolvedTimelineEntry()
                            }
                        }
                    }
                    .onChange(of: presentationID) { _, _ in
                        positionedPresentationID = nil
                        positionInitialTimelineEntry(
                            with: scrollProxy,
                            shouldSelect: isActive && allowsFallbackSelection
                        )
                    }
                    .onChange(of: isActive) { _, newValue in
                        guard newValue else { return }
                        if isPositionedForCurrentPresentation {
                            if !scrollToPendingTimelineEntry(with: scrollProxy) {
                                selectResolvedTimelineEntry()
                            }
                        } else {
                            positionInitialTimelineEntry(
                                with: scrollProxy,
                                shouldSelect: allowsFallbackSelection
                            )
                        }
                    }
                    .onChange(of: scrollRequest) { _, _ in
                        guard isActive else { return }
                        if isPositionedForCurrentPresentation {
                            scrollToPendingTimelineEntry(with: scrollProxy)
                        } else {
                            positionInitialTimelineEntry(with: scrollProxy, shouldSelect: true)
                        }
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

    private var emptyTimelineDescription: String {
        var items = ["completed items"]
        if showsNotes {
            items.append("notes")
        }
        if showsPlaces {
            items.append("place check-ins")
        }
        items.append("emotions")
        items.append("sleep records")
        if showsAway {
            items.append("away sessions")
        }
        return "\(Self.listText(items).capitalized) will appear here newest first."
    }

    private static func listText(_ items: [String]) -> String {
        switch items.count {
        case 0:
            return ""
        case 1:
            return items[0]
        case 2:
            return "\(items[0]) and \(items[1])"
        default:
            return items.dropLast().joined(separator: ", ") + ", and \(items.last ?? "")"
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

    private var isPositionedForCurrentPresentation: Bool {
        positionedPresentationID == presentationID
    }

    private func positionInitialTimelineEntry(with proxy: ScrollViewProxy, shouldSelect: Bool) {
        guard let entryID = initialTimelineEntryID(prefersPendingRequest: shouldSelect) else { return }

        if shouldSelect, selectedEntryID != entryID {
            selection = .timelineEntry(entryID)
        }
        positionTimelineList(to: entryID, with: proxy, clearsMatchingRequest: shouldSelect)
    }

    private func initialTimelineEntryID(prefersPendingRequest: Bool) -> UUID? {
        if prefersPendingRequest,
           let requestedEntryID = scrollRequest?.entryID,
           visibleEntryIDs.contains(requestedEntryID) {
            return requestedEntryID
        }

        return visibleEntryIDs.first
    }

    private func selectResolvedTimelineEntry() {
        guard let entryID = TimelineSelectionSupport.resolvedSelection(
            currentSelection: selectedEntryID,
            visibleEntryIDs: visibleEntryIDs,
            usesSidebarLayout: true,
            allowsFallbackSelection: allowsFallbackSelection
        ) else { return }

        if selectedEntryID != entryID {
            selection = .timelineEntry(entryID)
        }
    }

    @discardableResult
    private func scrollToPendingTimelineEntry(with proxy: ScrollViewProxy) -> Bool {
        guard
            let entryID = scrollRequest?.entryID,
            visibleEntryIDs.contains(entryID)
        else { return false }

        if selectedEntryID != entryID {
            selection = .timelineEntry(entryID)
        }
        scrollTimelineList(to: entryID, with: proxy)
        scrollRequest = nil
        return true
    }

    private func positionTimelineList(
        to entryID: UUID,
        with proxy: ScrollViewProxy,
        clearsMatchingRequest: Bool
    ) {
        DispatchQueue.main.async {
            proxy.scrollTo(entryID, anchor: .top)
            DispatchQueue.main.async {
                proxy.scrollTo(entryID, anchor: .top)
                if clearsMatchingRequest, scrollRequest?.entryID == entryID {
                    scrollRequest = nil
                }
                positionedPresentationID = presentationID
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    proxy.scrollTo(entryID, anchor: .top)
                }
            }
        }
    }

    private func scrollTimelineList(to entryID: UUID, with proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            proxy.scrollTo(entryID, anchor: .top)
            DispatchQueue.main.async {
                proxy.scrollTo(entryID, anchor: .top)
            }
        }
    }
}

struct HomeMacPlannerTimelineListView<RowContent: View>: View {
    let timelineEntryCount: Int
    let groupedEntries: [(date: Date, entries: [TimelineEntry])]
    let showsPlaces: Bool
    let showsNotes: Bool
    let showsAway: Bool
    let sectionTitle: (Date) -> String
    @ViewBuilder let rowContent: (TimelineEntry, Int) -> RowContent

    var body: some View {
        Group {
            if timelineEntryCount == 0 {
                ContentUnavailableView(
                    "No timeline entries yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text(emptyTimelineDescription)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if groupedEntries.isEmpty {
                ContentUnavailableView(
                    "No matching timeline entries",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Try a different timeline search.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(groupedEntries, id: \.date) { section in
                        Section {
                            ForEach(section.entries, id: \.id) { entry in
                                rowContent(entry, rowNumbersByEntryID[entry.id] ?? 1)
                            }
                        } header: {
                            Text(sectionTitle(section.date))
                        }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        }
    }

    private var emptyTimelineDescription: String {
        var items = ["completed items"]
        if showsNotes {
            items.append("notes")
        }
        if showsPlaces {
            items.append("place check-ins")
        }
        items.append("emotions")
        items.append("sleep records")
        if showsAway {
            items.append("away sessions")
        }
        return "\(Self.listText(items).capitalized) will appear here newest first."
    }

    private static func listText(_ items: [String]) -> String {
        switch items.count {
        case 0:
            return ""
        case 1:
            return items[0]
        case 2:
            return "\(items[0]) and \(items[1])"
        default:
            return items.dropLast().joined(separator: ", ") + ", and \(items.last ?? "")"
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
