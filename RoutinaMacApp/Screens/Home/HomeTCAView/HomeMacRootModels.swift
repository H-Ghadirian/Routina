import Foundation
import SwiftData
import SwiftUI

let homeFocusPauseResumeActionPredicate = #Predicate<RoutinaDeviceActionLog> { log in
    log.entityRawValue == "focusSession"
        && (log.actionRawValue == "paused" || log.actionRawValue == "resumed")
}

final class HomeCollapsedTagTaskListSectionIDsCache: ObservableObject {
    private var cachedStorage: String?
    private var cachedIDs: Set<String> = []

    func ids(for storage: String) -> Set<String> {
        guard cachedStorage != storage else { return cachedIDs }
        cachedStorage = storage
        cachedIDs = Set(storage.split(separator: "\n").map(String.init))
        return cachedIDs
    }
}

enum MacHomeDetailMode: String, CaseIterable, Identifiable {
    case details = "Details"
    case planner = "Planner"
    case board = "Board"
    case places = "Places"

    var id: Self { self }

    static var visibleModes: [Self] {
        var modes: [Self] = [.details, .planner]
        if SharedDefaults.app[.appSettingBoardScreenEnabled] {
            modes.append(.board)
        }
        if SharedDefaults.app[.appSettingPlacesEnabled] {
            modes.append(.places)
        }
        return modes
    }

    static var defaultLandingMode: Self { .planner }

    var visibleSurfaceMode: Self {
        Self.visibleModes.contains(self) ? self : .details
    }
}

enum MacHomeProgressMode: String, CaseIterable, Identifiable {
    case stats = "Stats"
    case adventure = "Adventure"

    var id: Self { self }

    static var visibleModes: [Self] {
        guard SharedDefaults.app[.appSettingAdventureMapEnabled] else {
            return [.stats]
        }
        return [.stats, .adventure]
    }

    var visibleSurfaceMode: Self {
        Self.visibleModes.contains(self) ? self : .stats
    }
}

enum HomeMacFilterDetailScope: String, CaseIterable, Identifiable {
    case both
    case taskList
    case timeline
    case calendar

    var id: Self { self }

    var title: String {
        switch self {
        case .both:
            return "Shared"
        case .taskList:
            return "Task List"
        case .timeline:
            return "Timeline"
        case .calendar:
            return "Calendar"
        }
    }

    var scopeDescription: String {
        switch self {
        case .both:
            return "Applies to task-backed rows in Task List, Timeline, and Calendar."
        case .taskList:
            return "Filters and organizes Task List rows only."
        case .timeline:
            return "Filters Timeline activity only."
        case .calendar:
            return "Controls Calendar layers and Calendar task rows only."
        }
    }

    var systemImage: String {
        switch self {
        case .both:
            return "slider.horizontal.3"
        case .taskList:
            return "checklist"
        case .timeline:
            return "clock.arrow.circlepath"
        case .calendar:
            return "calendar"
        }
    }
}

struct MacSidebarTaskScrollRequest: Equatable {
    enum Anchor: Equatable {
        case center
        case minimalReveal
    }

    let taskID: UUID
    let anchor: Anchor
    let destination: MacSidebarTaskScrollDestination?
    private let token = UUID()

    init(
        taskID: UUID,
        anchor: Anchor = .center,
        destination: MacSidebarTaskScrollDestination? = nil
    ) {
        self.taskID = taskID
        self.anchor = anchor
        self.destination = destination
    }
}

struct MacSidebarTaskScrollDestination: Equatable {
    let sectionID: String
    let groupIDs: [String]
}

struct MacTimelineSidebarScrollRequest: Equatable {
    let entryID: UUID
    private let token = UUID()
}
