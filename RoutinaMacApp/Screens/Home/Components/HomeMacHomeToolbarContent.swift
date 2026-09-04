import AppKit
import SwiftUI

struct HomeMacTopToolbarChrome: View {
    enum Mode {
        case board
        case goals
        case standard
    }

    let mode: Mode
    let doneCount: Int
    let showsDoneCount: Bool
    let isDevelopmentAppVariant: Bool
    let showsProgressModePicker: Bool
    let showsPlaces: Bool
    let showsSearch: Bool
    let showsSidebarToggle: Bool
    let isFilterPresented: Bool
    let isFilterActive: Bool
    @Binding var progressMode: MacHomeProgressMode
    @Binding var selectedSidebarMode: HomeFeature.MacSidebarMode
    @Binding var searchText: String
    @Binding var isSearchTextFocused: Bool
    @Binding var isSearchExpanded: Bool
    @Binding var searchVisiblePillWidth: CGFloat
    @Binding var searchExpansionTransitionID: Int
    @Binding var searchFocusRequestID: Int
    @Binding var searchFocusDismissRequestID: Int
    let isSidebarCollapsed: Bool
    let locationSnapshot: LocationSnapshot
    let onPlaceCheckInMapRequested: () -> Void
    let isCreatingTaskFromSearch: Bool
    let canCreateTaskFromSearch: Bool
    let onSearchSubmit: (String) -> Void
    let onSearchCommandSubmit: (String) -> Void
    let onAddEvent: () -> Void
    let onAddEmotion: () -> Void
    let onAddNote: () -> Void
    let onAddGoal: () -> Void
    let onAddTask: () -> Void
    let onFocus: () -> Void
    let focusAvailability: MacFocusMenuAvailability
    let onCheckIn: () -> Void
    let onStartAway: () -> Void
    let onOpenSettings: () -> Void
    let onToggleFilters: () -> Void
    let isBoardInspectorPresented: Bool
    let onToggleBoardInspector: () -> Void
    let onToggleSidebar: () -> Void

    var body: some View {
        toolbarRow
            .frame(height: HomeMacToolbarSearchLayout.topToolbarHeight)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .leading) {
                if showsSidebarToggle {
                    HStack(spacing: 8) {
                        HomeMacSidebarVisibilityToolbarButton(
                            isCollapsed: isSidebarCollapsed,
                            onToggle: onToggleSidebar
                        )

                        RoutinaMacFocusTimerToolbarBadge(showsTitle: false)
                    }
                    .padding(.leading, HomeMacToolbarSearchLayout.sidebarToggleLeadingPadding)
                }
            }
            .background(HomeMacToolbarSearchLayout.toolbarBackground)
            .overlay(alignment: .bottom) {
                Divider()
                    .opacity(0.55)
            }
    }

    private var toolbarRow: some View {
        ZStack(alignment: .center) {
            HStack(alignment: .center, spacing: 12) {
                statusBadges
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(3)

                Spacer(minLength: 8)

                toolbarTrailingCluster
                    .layoutPriority(4)
            }
            .padding(.leading, HomeMacToolbarSearchLayout.trafficLightReservedLeadingPadding)
            .padding(.trailing, HomeMacToolbarSearchLayout.topToolbarHorizontalPadding)
            .frame(height: HomeMacToolbarSearchLayout.topToolbarHeight)
            .frame(maxWidth: .infinity)

            if showsSearch {
                toolbarSearch
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(height: HomeMacToolbarSearchLayout.topToolbarHeight)
        .frame(maxWidth: .infinity)
    }

    private var toolbarSearch: some View {
        HomeMacToolbarSearchField(
            text: $searchText,
            isTextFocused: $isSearchTextFocused,
            isSearchExpanded: $isSearchExpanded,
            visiblePillWidth: $searchVisiblePillWidth,
            searchExpansionTransitionID: $searchExpansionTransitionID,
            focusRequestID: $searchFocusRequestID,
            focusDismissRequestID: $searchFocusDismissRequestID,
            isCreatingTask: isCreatingTaskFromSearch,
            canCreateTaskFromQuery: canCreateTaskFromSearch,
            onSubmit: onSearchSubmit,
            onCommandSubmit: onSearchCommandSubmit
        )
        .frame(width: HomeMacToolbarSearchLayout.focusedWidth, alignment: .center)
        .layoutPriority(2)
    }

    private var toolbarTrailingCluster: some View {
        HStack(spacing: 12) {
            toolbarCommandCluster

            if mode == .board {
                HomeMacBoardInspectorToolbarButton(
                    isPresented: isBoardInspectorPresented,
                    onToggle: onToggleBoardInspector
                )
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var toolbarCommandCluster: some View {
        HStack(spacing: 10) {
            if HomeMacToolbarFilterPresentation.isVisible(for: selectedSidebarMode) {
                HomeMacToolbarFilterButton(
                    isPresented: isFilterPresented,
                    isActive: isFilterActive,
                    workspaceTitle: selectedSidebarMode.workspaceTitle,
                    presentsSort: selectedSidebarMode == .backlog,
                    onToggle: onToggleFilters
                )
            }

            HomeMacWorkspaceToolbarControls(
                selectedMode: $selectedSidebarMode,
                onOpenSettings: onOpenSettings,
                onAddEvent: onAddEvent,
                onAddEmotion: onAddEmotion,
                onAddNote: onAddNote,
                onAddGoal: onAddGoal,
                onAddTask: onAddTask,
                onFocus: onFocus,
                focusAvailability: focusAvailability,
                onCheckIn: onCheckIn,
                onStartAway: onStartAway
            )

            if showsProgressModePicker {
                MacHomeProgressModePicker(selection: $progressMode)
            }

            if showsPlaces {
                RoutinaMacPlaceCheckInToolbarButton(
                    locationSnapshot: locationSnapshot,
                    onMapRequested: onPlaceCheckInMapRequested
                )
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var statusBadges: some View {
        HStack(spacing: 8) {
            if isDevelopmentAppVariant {
                MacToolbarStatusBadge(
                    title: "Dev Version",
                    systemImage: "hammer.fill",
                    tintColor: .systemOrange
                )
                .help("Development version")
            }

            if showsDoneCount {
                MacToolbarStatusBadge(
                    title: "\(doneCount) done",
                    systemImage: "checkmark.seal.fill",
                    tintColor: .systemGreen
                )
                .help("\(doneCount) total done")
            }
        }
    }
}

enum HomeMacToolbarFilterPresentation {
    static func isVisible(for mode: HomeFeature.MacSidebarMode) -> Bool {
        mode == .routines || mode == .backlog
    }
}

private struct HomeMacToolbarFilterButton: View {
    let isPresented: Bool
    let isActive: Bool
    let workspaceTitle: String
    let presentsSort: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Image(
                systemName: isActive
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(isPresented || isActive ? Color.accentColor : Color.secondary)
            .frame(width: 32, height: 32)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isPresented ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.07))
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(actionTitle)
        .accessibilityValue(isActive ? activeValue : inactiveValue)
        .help(actionTitle)
    }

    private var actionTitle: String {
        presentsSort ? "\(workspaceTitle) filter and sort" : "\(workspaceTitle) filters"
    }

    private var activeValue: String {
        presentsSort ? "Filter or sort active" : "Filters active"
    }

    private var inactiveValue: String {
        presentsSort ? "Default filters and sort" : "No active filters"
    }
}

private struct HomeMacSidebarVisibilityToolbarButton: View {
    let isCollapsed: Bool
    let onToggle: () -> Void

    var body: some View {
        MacToolbarIconButton(
            title: title,
            systemImage: "sidebar.left"
        ) {
            onToggle()
        }
        .frame(
            width: HomeMacToolbarSearchLayout.sidebarToggleButtonSize,
            height: HomeMacToolbarSearchLayout.sidebarToggleButtonSize
        )
        .contentShape(Rectangle())
        .fixedSize()
        .help(title)
        .accessibilityLabel(title)
    }

    private var title: String {
        isCollapsed ? "Expand Sidebar" : "Collapse Sidebar"
    }
}

struct HomeMacBoardInspectorToolbarButton: View {
    let isPresented: Bool
    let onToggle: () -> Void

    var body: some View {
        MacToolbarIconButton(
            title: isPresented ? "Hide Board Details" : "Show Board Details",
            systemImage: "sidebar.right"
        ) {
            onToggle()
        }
        .help(isPresented ? "Hide board details" : "Show board details")
    }
}
