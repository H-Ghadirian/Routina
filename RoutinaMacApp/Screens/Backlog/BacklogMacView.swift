import ComposableArchitecture
import SwiftUI

struct BacklogMacView<FilterView: View>: View {
    let store: StoreOf<BacklogFeature>
    let onShowTaskInPlanner: (UUID, String) -> Void
    let onShowTaskInTimeline: (UUID, String) -> Void
    let isFilterPresented: Bool
    let isFilterFullscreen: Bool
    let onExpandFilter: () -> Void
    let onMinimizeFilter: () -> Void
    let onCloseFilter: () -> Void
    @ViewBuilder let filterView: () -> FilterView

    init(
        store: StoreOf<BacklogFeature>,
        onShowTaskInPlanner: @escaping (UUID, String) -> Void = { _, _ in },
        onShowTaskInTimeline: @escaping (UUID, String) -> Void = { _, _ in },
        isFilterPresented: Bool,
        isFilterFullscreen: Bool,
        onExpandFilter: @escaping () -> Void,
        onMinimizeFilter: @escaping () -> Void,
        onCloseFilter: @escaping () -> Void,
        @ViewBuilder filterView: @escaping () -> FilterView
    ) {
        self.store = store
        self.onShowTaskInPlanner = onShowTaskInPlanner
        self.onShowTaskInTimeline = onShowTaskInTimeline
        self.isFilterPresented = isFilterPresented
        self.isFilterFullscreen = isFilterFullscreen
        self.onExpandFilter = onExpandFilter
        self.onMinimizeFilter = onMinimizeFilter
        self.onCloseFilter = onCloseFilter
        self.filterView = filterView
    }

    @AppStorage(
        UserDefaultStringValueKey.appSettingCustomTaskSections.rawValue,
        store: SharedDefaults.app
    ) var customTaskSectionsRawValue = ""
    @AppStorage(
        UserDefaultStringValueKey.appSettingBacklogTaskRowHiddenFields.rawValue,
        store: SharedDefaults.app
    ) var backlogTaskRowHiddenFieldsRawValue = HomeTaskRowVisibility.backlogDefaultStorageRawValue
    @AppStorage(
        UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue,
        store: SharedDefaults.app
    ) var isPlacesEnabled = false
    @State var newSectionTitle = ""
    @State var newSectionTaskID: UUID?
    @State var isNewSectionPromptPresented = false
    @State var newSubsectionTitleBySectionID: [UUID: String] = [:]

    var body: some View {
        backlogContent
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            store.send(.onAppear)
        }
        .onDisappear {
            store.send(.onDisappear)
        }
        .onChange(of: customTaskSectionsRawValue) { _, rawValue in
            store.send(.customSectionsChanged(HomeCustomTaskSectionStorage.decoded(from: rawValue)))
        }
        .onReceive(NotificationCenter.default.publisher(for: .routineDidUpdate)) { _ in
            store.send(.routineDataChanged)
        }
        .alert("New Backlog Super Section", isPresented: $isNewSectionPromptPresented) {
            TextField("Name", text: $newSectionTitle)
            Button("Create") {
                createBacklogSection()
            }
            .disabled(HomeCustomTaskSectionStorage.sanitizedTitle(newSectionTitle) == nil)
            Button("Cancel", role: .cancel) {
                resetNewSectionPrompt()
            }
        }
    }

    @ViewBuilder
    private var backlogContent: some View {
        if isFilterPresented && isFilterFullscreen {
            fullscreenFilterContent
        } else {
            contentWithOptionalFilterPane
        }
    }

    private var workspaceContent: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 280, idealWidth: 330, maxWidth: 420)

            detail
                .frame(minWidth: 620, maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var contentWithOptionalFilterPane: some View {
        GeometryReader { proxy in
            let filterPaneWidth = isFilterPresented ? MacDetailContainerSizing.filterDetailPaneWidth : 0
            let workspaceWidth = max(proxy.size.width - filterPaneWidth, 0)

            HStack(spacing: 0) {
                workspaceContent
                    .frame(width: workspaceWidth)
                    .frame(maxHeight: .infinity)
                    .clipped()

                if isFilterPresented {
                    filterPane
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(MacHomeDetailAnimation.secondaryPane, value: isFilterPresented)
    }

    private var filterPane: some View {
        VStack(spacing: 0) {
            filterHeader(showsFullscreenAction: true)
            Divider()
            filterView()
        }
        .frame(width: MacDetailContainerSizing.filterDetailPaneWidth)
        .frame(maxHeight: .infinity)
        .background(Color.secondary.opacity(0.045), ignoresSafeAreaEdges: [])
        .overlay(alignment: .leading) {
            Divider()
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
        .zIndex(1)
    }

    private var fullscreenFilterContent: some View {
        VStack(spacing: 0) {
            filterHeader(showsFullscreenAction: false)
            Divider()
            filterView()
                .frame(
                    maxWidth: MacDetailContainerSizing.fullscreenFilterContentMaxWidth,
                    maxHeight: .infinity,
                    alignment: .top
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func filterHeader(showsFullscreenAction: Bool) -> some View {
        HStack(spacing: 10) {
            Label(
                "Filter, Sort, and Appearance",
                systemImage: "line.3.horizontal.decrease.circle"
            )
            .font(.headline)
            .lineLimit(1)

            Spacer(minLength: 8)

            filterHeaderButton(
                systemName: showsFullscreenAction
                    ? "arrow.up.left.and.arrow.down.right"
                    : "arrow.down.right.and.arrow.up.left",
                title: showsFullscreenAction ? "Open Fullscreen" : "Minimize",
                action: showsFullscreenAction ? onExpandFilter : onMinimizeFilter
            )

            filterHeaderButton(
                systemName: "xmark",
                title: "Close",
                action: onCloseFilter
            )
        }
        .padding(.horizontal, showsFullscreenAction ? 14 : 20)
        .padding(.vertical, showsFullscreenAction ? 10 : 12)
    }

    private func filterHeaderButton(
        systemName: String,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.secondary)
                .frame(width: 30, height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                }
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .help(title)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Backlog")
                        .font(.title2.weight(.semibold))

                    Spacer(minLength: 8)

                    Text(backlogCountLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Button {
                        store.send(.refresh)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh Backlog")
                    .disabled(store.isLoading)
                }

                Text("Tasks kept off your main task list")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(16)

            Divider()

            if store.isLoading && store.presentation.isEmpty {
                ProgressView("Loading Backlog…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isSearching
                        && store.presentation.taskCount == 0
                        && store.presentation.outsideBacklogResults.isEmpty {
                ContentUnavailableView.search(text: store.searchText)
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.presentation.isEmpty
                        && store.presentation.outsideBacklogResults.isEmpty {
                ContentUnavailableView(
                    "Backlog is clear",
                    systemImage: "tray",
                    description: Text("Move a task here from the main task list, or create a Backlog section in Settings.")
                )
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(store.presentation.sections) { section in
                            backlogSection(section)
                        }

                        if !store.presentation.hiddenByFlagTasks.isEmpty {
                            automaticFlagSection
                        }

                        if !store.presentation.outsideBacklogResults.isEmpty {
                            outsideBacklogSection
                        }
                    }
                    .padding(10)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    @ViewBuilder
    private var detail: some View {
        if let detailStore = store.scope(
            state: \.taskDetailState,
            action: \.taskDetail
        ) {
            TaskDetailTCAView(
                store: detailStore,
                showsPrincipalToolbarTitle: false
            )
        } else {
            ContentUnavailableView(
                "Select a backlog task",
                systemImage: "tray.full",
                description: Text("Open a task to review its details or edit it without bringing it back to the main sidebar.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
