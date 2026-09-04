import SwiftData
import SwiftUI

struct DayPlanHeaderView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @ObservedObject var planner: DayPlanPlannerState
    var calendarFilters = DayPlanCalendarFilterState()
    var isCalendarFilterSidebarPresented: Binding<Bool> = .constant(false)
    var isDatePickerSidebarPresented: Binding<Bool> = .constant(false)
    var isCalendarFilterDetailPresented = false
    var showsCalendarFilterButton = false
    var displayMode: Binding<DayPlanDisplayMode> = .constant(.calendar)
    var calendarTaskViewMode: Binding<DayPlanCalendarTaskViewMode> = .constant(.schedule)
    var showsDisplayModePicker = false
    var isTaskDetailInspectorPresented = false
    var parentAvailableWidth: CGFloat?
    var listFilterButtonIsActive = false
    var listFilterButtonAccessibilityValue: String?
    var onCalendarFilterButtonPressed: (() -> Void)?
    @State private var expandedMacHeaderControl: DayPlanExpandedHeaderControl?
    @State private var macHeaderAvailableWidth: CGFloat = 0
    @State private var macHeaderExpandedControlsWidth: CGFloat = 0

    var body: some View {
        #if os(macOS)
            macHeader
        #else
            compactHeader
        #endif
    }

    private var macHeader: some View {
        ZStack(alignment: .leading) {
            macHeaderRow
                .background(macHeaderExpandedControlsWidthProbe)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .background(macHeaderAvailableWidthReader)
        .onPreferenceChange(DayPlanHeaderAvailableWidthPreferenceKey.self) { width in
            guard abs(macHeaderAvailableWidth - width) > 0.5 else { return }
            macHeaderAvailableWidth = width
        }
        .onPreferenceChange(DayPlanHeaderControlsWidthPreferenceKey.self) { width in
            guard abs(macHeaderExpandedControlsWidth - width) > 0.5 else { return }
            macHeaderExpandedControlsWidth = width
        }
    }

    private var needsCompactMacDateButtonForFit: Bool {
        #if os(macOS)
            DayPlanHeaderRangePickerVisibility.shouldUseCompactDateButtonForFit(
                availableWidth: Double(effectiveMacHeaderAvailableWidth),
                expandedControlsWidth: Double(macHeaderExpandedControlsWidth),
                showsCalendarControlSet: effectiveDisplayMode == .calendar
            )
        #else
            false
        #endif
    }

    private var macHeaderRow: some View {
        HStack(alignment: .center, spacing: 12) {
            plannerViewControlsCluster(expandedControl: expandedMacHeaderControl)

            Spacer(minLength: 16)

            plannerUtilityCluster(forceIconOnlyDatePickerButton: usesIconOnlyMacDatePickerButton)
        }
        .frame(maxWidth: .infinity)
    }

    private var macHeaderAvailableWidthReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: DayPlanHeaderAvailableWidthPreferenceKey.self,
                value: proxy.size.width
            )
        }
    }

    private var macHeaderExpandedControlsWidthProbe: some View {
        macHeaderFittingControls
            .fixedSize(horizontal: true, vertical: false)
            .hidden()
            .accessibilityHidden(true)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: DayPlanHeaderControlsWidthPreferenceKey.self,
                        value: proxy.size.width
                    )
                }
            }
    }

    private var macHeaderFittingControls: some View {
        HStack(alignment: .center, spacing: 12) {
            plannerViewControlsCluster(expandedControl: widestMacHeaderControlForMeasurement)
            Color.clear.frame(width: 16, height: 1)
            plannerUtilityCluster(forceIconOnlyDatePickerButton: false)
        }
    }

    private var widestMacHeaderControlForMeasurement: DayPlanExpandedHeaderControl? {
        if effectiveDisplayMode == .calendar {
            return .visibleRangeMode
        }
        return showsDisplayModePicker ? .displayMode : nil
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            if effectiveDisplayMode == .calendar {
                HStack(alignment: .center, spacing: 10) {
                    plannerDateNavigationCluster

                    Spacer(minLength: 8)

                    plannerUtilityCluster
                }
            }

            HStack(spacing: 8) {
                if showsDisplayModePicker {
                    displayModePicker
                }
                if effectiveDisplayMode == .calendar {
                    calendarTaskViewModePicker
                    visibleRangeModePicker
                }
            }
        }
    }

    private func plannerViewControlsCluster(
        expandedControl: DayPlanExpandedHeaderControl?
    ) -> some View {
        HStack(alignment: .center, spacing: DayPlanHeaderRangePickerVisibility.segmentedControlSpacing) {
            if showsDisplayModePicker {
                plannerDisplayModeControl(isExpanded: expandedControl == .displayMode)
            }
            if effectiveDisplayMode == .calendar {
                calendarTaskViewModeControl(isExpanded: expandedControl == .calendarTaskViewMode)
                visibleRangeModeControl(isExpanded: expandedControl == .visibleRangeMode)
            }
        }
    }

    private var plannerUtilityCluster: some View {
        plannerUtilityCluster(forceIconOnlyDatePickerButton: nil)
    }

    private func plannerUtilityCluster(forceIconOnlyDatePickerButton: Bool?) -> some View {
        DayPlanHeaderUtilityCluster(
            planner: planner,
            calendarFilters: calendarFilters,
            isCalendarFilterSidebarPresented: isCalendarFilterSidebarPresented,
            isDatePickerSidebarPresented: isDatePickerSidebarPresented,
            isCalendarFilterDetailPresented: isCalendarFilterDetailPresented,
            showsCalendarFilterButton: showsCalendarFilterButton,
            effectiveDisplayMode: effectiveDisplayMode,
            listFilterButtonIsActive: listFilterButtonIsActive,
            listFilterButtonAccessibilityValue: listFilterButtonAccessibilityValue,
            onCalendarFilterButtonPressed: onCalendarFilterButtonPressed,
            forceIconOnlyDatePickerButton: forceIconOnlyDatePickerButton
        )
    }

    private var plannerDateNavigationCluster: some View {
        DayPlanHeaderDateNavigationControls(planner: planner)
    }

    private var visibleRangeModePicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Planner range",
            options: planner.availableVisibleRangeModes,
            selection: visibleRangeModeBinding,
            label: { mode in Text(mode.title) }
        )
        .frame(width: DayPlanHeaderRangePickerVisibility.visibleRangeModePickerWidth)
        .accessibilityLabel("Planner range")
    }

    private var displayModePicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Planner view",
            options: DayPlanDisplayMode.allCases,
            selection: displayMode,
            minimumSegmentWidth: 84,
            horizontalPadding: 11,
            label: { mode in
                Label(mode.title, systemImage: mode.systemImage)
                    .labelStyle(.titleAndIcon)
            }
        )
        .frame(width: DayPlanHeaderRangePickerVisibility.displayModePickerWidth)
        .accessibilityLabel("Planner view")
    }

    private var calendarTaskViewModePicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Calendar task view",
            options: DayPlanCalendarTaskViewMode.allCases,
            selection: calendarTaskViewMode,
            minimumSegmentWidth: 74,
            horizontalPadding: 11,
            label: { mode in
                Label(mode.title, systemImage: mode.systemImage)
                    .labelStyle(.titleAndIcon)
            }
        )
        .frame(width: DayPlanHeaderRangePickerVisibility.calendarTaskViewModePickerWidth)
        .accessibilityLabel("Calendar task view")
    }

    private func plannerDisplayModeControl(isExpanded: Bool) -> some View {
        DayPlanExpandableHeaderSegmentedControl(
            accessibilityLabel: "Planner view",
            options: DayPlanDisplayMode.allCases,
            selection: displayMode.wrappedValue,
            optionTitle: { $0.title },
            expandedWidth: DayPlanHeaderRangePickerVisibility.displayModePickerWidth,
            collapsedWidth: DayPlanHeaderRangePickerVisibility.compactDisplayModePickerWidth,
            minimumSegmentWidth: 84,
            horizontalPadding: 11,
            isExpanded: isExpanded,
            onExpansionToggle: { toggleMacHeaderControl(.displayMode) },
            onSelection: { mode in
                animateMacHeaderExpansion {
                    displayMode.wrappedValue = mode
                    expandedMacHeaderControl = nil
                }
            },
            label: { mode in
                Label(mode.title, systemImage: mode.systemImage)
                    .labelStyle(.titleAndIcon)
            }
        )
    }

    private func calendarTaskViewModeControl(isExpanded: Bool) -> some View {
        DayPlanExpandableHeaderSegmentedControl(
            accessibilityLabel: "Calendar task view",
            options: DayPlanCalendarTaskViewMode.allCases,
            selection: calendarTaskViewMode.wrappedValue,
            optionTitle: { $0.title },
            expandedWidth: DayPlanHeaderRangePickerVisibility.calendarTaskViewModePickerWidth,
            collapsedWidth: DayPlanHeaderRangePickerVisibility.compactCalendarTaskViewModePickerWidth,
            minimumSegmentWidth: 74,
            horizontalPadding: 11,
            isExpanded: isExpanded,
            onExpansionToggle: { toggleMacHeaderControl(.calendarTaskViewMode) },
            onSelection: { mode in
                animateMacHeaderExpansion {
                    calendarTaskViewMode.wrappedValue = mode
                    expandedMacHeaderControl = nil
                }
            },
            label: { mode in
                Label(mode.title, systemImage: mode.systemImage)
                    .labelStyle(.titleAndIcon)
            }
        )
    }

    private func visibleRangeModeControl(isExpanded: Bool) -> some View {
        DayPlanExpandableHeaderSegmentedControl(
            accessibilityLabel: "Planner range",
            options: planner.availableVisibleRangeModes,
            selection: planner.visibleRangeMode,
            optionTitle: { $0.title },
            expandedWidth: DayPlanHeaderRangePickerVisibility.visibleRangeModePickerWidth,
            collapsedWidth: DayPlanHeaderRangePickerVisibility.compactVisibleRangeModePickerWidth,
            isExpanded: isExpanded,
            onExpansionToggle: { toggleMacHeaderControl(.visibleRangeMode) },
            onSelection: { mode in
                animateMacHeaderExpansion {
                    planner.setVisibleRangeMode(mode, calendar: calendar, context: modelContext)
                    expandedMacHeaderControl = nil
                }
            },
            label: { mode in Text(mode.title) }
        )
    }

    private func toggleMacHeaderControl(_ control: DayPlanExpandedHeaderControl) {
        animateMacHeaderExpansion {
            expandedMacHeaderControl = expandedMacHeaderControl == control ? nil : control
        }
    }

    private func animateMacHeaderExpansion(_ changes: () -> Void) {
        if accessibilityReduceMotion {
            changes()
        } else {
            withAnimation(.easeInOut(duration: 0.18), changes)
        }
    }

    private var visibleRangeModeBinding: Binding<DayPlanVisibleRangeMode> {
        Binding(
            get: {
                planner.visibleRangeMode
            },
            set: { mode in
                planner.setVisibleRangeMode(mode, calendar: calendar, context: modelContext)
            }
        )
    }

    private var effectiveDisplayMode: DayPlanDisplayMode {
        showsDisplayModePicker ? displayMode.wrappedValue : .calendar
    }

    private var usesIconOnlyMacDatePickerButton: Bool {
        #if os(macOS)
            DayPlanHeaderRangePickerVisibility.shouldUseIconOnlyDatePickerButton(
                needsCompactDateButtonForFit: needsCompactMacDateButtonForFit
            )
        #else
            false
        #endif
    }

    private var effectiveMacHeaderAvailableWidth: CGFloat {
        CGFloat(
            DayPlanHeaderRangePickerVisibility.effectiveAvailableWidth(
                parentWidth: parentAvailableWidth.map(Double.init),
                measuredWidth: Double(macHeaderAvailableWidth)
            )
        )
    }

}

private enum DayPlanExpandedHeaderControl: Hashable {
    case displayMode
    case calendarTaskViewMode
    case visibleRangeMode
}

private struct DayPlanExpandableHeaderSegmentedControl<Option: Hashable, Label: View>: View {
    let accessibilityLabel: String
    let options: [Option]
    let selection: Option
    let optionTitle: (Option) -> String
    let expandedWidth: CGFloat
    let collapsedWidth: CGFloat
    var minimumSegmentWidth: CGFloat = 68
    var horizontalPadding: CGFloat = 14
    let isExpanded: Bool
    let onExpansionToggle: () -> Void
    let onSelection: (Option) -> Void
    @ViewBuilder let label: (Option) -> Label

    var body: some View {
        ZStack(alignment: .leading) {
            if isExpanded {
                RoutinaGlassSegmentedControl(
                    accessibilityLabel: accessibilityLabel,
                    options: options,
                    selection: selection,
                    onSelect: onSelection,
                    minimumSegmentWidth: minimumSegmentWidth,
                    horizontalPadding: horizontalPadding,
                    label: label
                )
                .frame(width: expandedWidth)
                .transition(.dayPlanHeaderHorizontalReveal)
            } else {
                Button(action: onExpansionToggle) {
                    HStack(spacing: 7) {
                        Text(optionTitle(selection))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.forward")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .frame(width: collapsedWidth)
                    .frame(minHeight: 34)
                    .routinaGlassCard(cornerRadius: 8, interactive: true)
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(accessibilityLabel): \(optionTitle(selection))")
                .accessibilityHint("Show all options")
                .transition(.dayPlanHeaderHorizontalReveal)
            }
        }
        .frame(minHeight: 36, alignment: .leading)
    }
}

private struct DayPlanHeaderHorizontalRevealModifier: ViewModifier {
    let horizontalScale: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: horizontalScale, y: 1, anchor: .leading)
            .opacity(opacity)
    }
}

private extension AnyTransition {
    static var dayPlanHeaderHorizontalReveal: AnyTransition {
        .modifier(
            active: DayPlanHeaderHorizontalRevealModifier(horizontalScale: 0.72, opacity: 0),
            identity: DayPlanHeaderHorizontalRevealModifier(horizontalScale: 1, opacity: 1)
        )
    }
}

private struct DayPlanHeaderAvailableWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct DayPlanHeaderControlsWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
