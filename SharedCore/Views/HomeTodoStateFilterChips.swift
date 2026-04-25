import SwiftUI

struct HomeTodoStateFilterChips: View {
    enum LayoutStyle {
        case flow(horizontalSpacing: CGFloat = 8, verticalSpacing: CGFloat = 8)
        case adaptiveGrid(minimumWidth: CGFloat = 80, spacing: CGFloat = 8)
    }

    @Binding var selectedTodoStateFilter: TodoState?
    let layoutStyle: LayoutStyle
    let selectedForegroundColor: Color?
    let unselectedForegroundColor: Color
    let selectedBackgroundOpacity: Double
    let fillsAvailableWidth: Bool
    let verticalPadding: CGFloat

    init(
        selectedTodoStateFilter: Binding<TodoState?>,
        layoutStyle: LayoutStyle = .flow(),
        selectedForegroundColor: Color? = nil,
        unselectedForegroundColor: Color = .secondary,
        selectedBackgroundOpacity: Double = 0.16,
        fillsAvailableWidth: Bool = false,
        verticalPadding: CGFloat = 7
    ) {
        self._selectedTodoStateFilter = selectedTodoStateFilter
        self.layoutStyle = layoutStyle
        self.selectedForegroundColor = selectedForegroundColor
        self.unselectedForegroundColor = unselectedForegroundColor
        self.selectedBackgroundOpacity = selectedBackgroundOpacity
        self.fillsAvailableWidth = fillsAvailableWidth
        self.verticalPadding = verticalPadding
    }

    @ViewBuilder
    var body: some View {
        switch layoutStyle {
        case let .flow(horizontalSpacing, verticalSpacing):
            HomeFilterFlowLayout(horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing) {
                chips
            }
        case let .adaptiveGrid(minimumWidth, spacing):
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: minimumWidth), spacing: spacing, alignment: .leading)],
                alignment: .leading,
                spacing: spacing
            ) {
                chips
            }
        }
    }

    @ViewBuilder
    private var chips: some View {
        HomeFilterChipButton(
            title: "Any State",
            isSelected: selectedTodoStateFilter == nil,
            selectedForegroundColor: selectedForegroundColor,
            unselectedForegroundColor: unselectedForegroundColor,
            selectedBackgroundOpacity: selectedBackgroundOpacity,
            fillsAvailableWidth: fillsAvailableWidth,
            verticalPadding: verticalPadding
        ) {
            selectedTodoStateFilter = nil
        }

        ForEach(TodoState.filterableCases) { state in
            HomeFilterChipButton(
                title: state.displayTitle,
                isSelected: selectedTodoStateFilter == state,
                selectedForegroundColor: selectedForegroundColor,
                unselectedForegroundColor: unselectedForegroundColor,
                selectedBackgroundOpacity: selectedBackgroundOpacity,
                fillsAvailableWidth: fillsAvailableWidth,
                verticalPadding: verticalPadding
            ) {
                selectedTodoStateFilter = selectedTodoStateFilter == state ? nil : state
            }
        }
    }
}
