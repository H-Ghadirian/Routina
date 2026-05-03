import SwiftUI

struct HomeIOSTaskListView<HeaderContent: View, EmptyRowContent: View, RowContent: View, DestinationContent: View>: View {
    let presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>
    let selectedTaskID: Binding<UUID?>
    let isCompactHeaderHidden: Bool
    let hasActiveOptionalFilters: Bool
    let headerContent: () -> HeaderContent
    let emptyRowContent: (HomeTaskListEmptyState) -> EmptyRowContent
    let rowContent: (HomeFeature.RoutineDisplay, Int, Bool, HomeTaskListMoveContext?) -> RowContent
    let onDelete: (IndexSet, [HomeFeature.RoutineDisplay]) -> Void
    let onScroll: (CGFloat, CGFloat) -> Void
    let destinationContent: (UUID) -> DestinationContent

    init(
        presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>,
        selectedTaskID: Binding<UUID?>,
        isCompactHeaderHidden: Bool,
        hasActiveOptionalFilters: Bool,
        @ViewBuilder headerContent: @escaping () -> HeaderContent,
        @ViewBuilder emptyRowContent: @escaping (HomeTaskListEmptyState) -> EmptyRowContent,
        @ViewBuilder rowContent: @escaping (HomeFeature.RoutineDisplay, Int, Bool, HomeTaskListMoveContext?) -> RowContent,
        onDelete: @escaping (IndexSet, [HomeFeature.RoutineDisplay]) -> Void,
        onScroll: @escaping (CGFloat, CGFloat) -> Void,
        @ViewBuilder destinationContent: @escaping (UUID) -> DestinationContent
    ) {
        self.presentation = presentation
        self.selectedTaskID = selectedTaskID
        self.isCompactHeaderHidden = isCompactHeaderHidden
        self.hasActiveOptionalFilters = hasActiveOptionalFilters
        self.headerContent = headerContent
        self.emptyRowContent = emptyRowContent
        self.rowContent = rowContent
        self.onDelete = onDelete
        self.onScroll = onScroll
        self.destinationContent = destinationContent
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isCompactHeaderHidden && hasActiveOptionalFilters {
                headerContent()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let emptyState = presentation.emptyState {
                emptyRowContent(emptyState)
            } else {
                taskList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.snappy(duration: 0.25), value: isCompactHeaderHidden)
    }

    private var taskList: some View {
        List(selection: selectedTaskID) {
            ForEach(presentation.sections) { section in
                Section(section.title) {
                    ForEach(Array(section.tasks.enumerated()), id: \.element.id) { index, task in
                        rowContent(
                            task,
                            section.rowNumber(forTaskAt: index),
                            section.includeMarkDone,
                            section.moveContext
                        )
                    }
                    .onDelete { offsets in
                        onDelete(offsets, section.tasks)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            max(geometry.contentOffset.y + geometry.contentInsets.top, 0)
        } action: { oldOffset, newOffset in
            onScroll(oldOffset, newOffset)
        }
        .navigationDestination(for: UUID.self) { taskID in
            destinationContent(taskID)
        }
    }
}
