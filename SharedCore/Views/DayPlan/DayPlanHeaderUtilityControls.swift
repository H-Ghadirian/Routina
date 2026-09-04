import SwiftData
import SwiftUI

struct DayPlanHeaderDateNavigationControls: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var planner: DayPlanPlannerState

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if shouldShowTodayButton {
                todayButton
            }
            rangeNavigationButtons
        }
    }

    private var todayButton: some View {
        Button("Show today") {
            planner.moveToToday(calendar: calendar, context: modelContext)
        }
        .buttonStyle(.bordered)
    }

    private var shouldShowTodayButton: Bool {
        !planner.visibleDates(calendar: calendar).contains { date in
            calendar.isDateInToday(date)
        }
    }

    private var rangeNavigationButtons: some View {
        HStack(spacing: 4) {
            rangeNavigationButton(
                systemName: "chevron.left",
                accessibilityLabel: previousRangeAccessibilityLabel
            ) {
                planner.moveVisibleRange(by: -1, calendar: calendar, context: modelContext)
            }

            rangeNavigationButton(
                systemName: "chevron.right",
                accessibilityLabel: nextRangeAccessibilityLabel
            ) {
                planner.moveVisibleRange(by: 1, calendar: calendar, context: modelContext)
            }
        }
    }

    private func rangeNavigationButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.secondary)
                .frame(width: 34, height: 34)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.07))
                }
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .help(accessibilityLabel)
    }

    private var previousRangeAccessibilityLabel: String {
        switch planner.visibleRangeMode {
        case .day:
            return "Previous day"
        case .threeDays:
            return "Previous 3 days"
        case .week:
            return "Previous week"
        }
    }

    private var nextRangeAccessibilityLabel: String {
        switch planner.visibleRangeMode {
        case .day:
            return "Next day"
        case .threeDays:
            return "Next 3 days"
        case .week:
            return "Next week"
        }
    }
}

struct DayPlanHeaderUtilityCluster: View {
    @Environment(\.calendar) private var calendar
    @ObservedObject var planner: DayPlanPlannerState
    let calendarFilters: DayPlanCalendarFilterState
    let isCalendarFilterSidebarPresented: Binding<Bool>
    let isDatePickerSidebarPresented: Binding<Bool>
    let isCalendarFilterDetailPresented: Bool
    let showsCalendarFilterButton: Bool
    let effectiveDisplayMode: DayPlanDisplayMode
    let listFilterButtonIsActive: Bool
    let listFilterButtonAccessibilityValue: String?
    let onCalendarFilterButtonPressed: (() -> Void)?
    let forceIconOnlyDatePickerButton: Bool?
    @AppStorage(
        UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isAwayEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacEventEmotionActionsEnabled.rawValue,
        store: SharedDefaults.app
    ) private var areMacEventEmotionActionsEnabled = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if showsCalendarFilterButton {
                calendarFilterButton
            }

            #if os(macOS)
                if effectiveDisplayMode == .calendar {
                    DayPlanHeaderDateNavigationControls(planner: planner)
                }
            #endif

            if showsPlannerDatePickerButton {
                plannerDatePickerButton(forceIconOnly: forceIconOnlyDatePickerButton)
            }
        }
    }

    private var showsPlannerDatePickerButton: Bool {
        effectiveDisplayMode == .calendar || effectiveDisplayMode == .list
    }

    private var calendarFilterButton: some View {
        let isPresented =
            onCalendarFilterButtonPressed == nil
            ? isCalendarFilterSidebarPresented.wrappedValue
            : isCalendarFilterDetailPresented
        let availability = calendarFilterAvailability
        let isListMode = effectiveDisplayMode == .list
        let isActive =
            isListMode
            ? listFilterButtonIsActive
            : calendarFilters.hasActiveFilters(availability: availability)
        let accessibilityLabel = isListMode ? "Timeline filters" : "Planner filters"
        let accessibilityValue =
            isListMode
            ? (listFilterButtonAccessibilityValue ?? "No timeline filters")
            : calendarFilters.summaryText(availability: availability)

        return Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                if let onCalendarFilterButtonPressed {
                    onCalendarFilterButtonPressed()
                    return
                }
                let shouldPresent = !isCalendarFilterSidebarPresented.wrappedValue
                isCalendarFilterSidebarPresented.wrappedValue = shouldPresent
                if shouldPresent {
                    isDatePickerSidebarPresented.wrappedValue = false
                }
            }
        } label: {
            Image(
                systemName: isActive
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
            .font(.title3)
            .foregroundStyle(isPresented || isActive ? Color.accentColor : Color.secondary)
            .frame(width: 34, height: 34)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isPresented ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.07))
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .help(accessibilityLabel)
    }

    private func plannerDatePickerButton(forceIconOnly: Bool?) -> some View {
        let title = plannerDatePickerButtonTitle
        let isPresented = isDatePickerSidebarPresented.wrappedValue
        let usesIconOnly = forceIconOnly ?? false

        return Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                let shouldPresent = !isDatePickerSidebarPresented.wrappedValue
                isDatePickerSidebarPresented.wrappedValue = shouldPresent
                if shouldPresent {
                    isCalendarFilterSidebarPresented.wrappedValue = false
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: isPresented ? "calendar.circle.fill" : "calendar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                if !usesIconOnly {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(.primary)

                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(minHeight: 34)
            .frame(
                minWidth: usesIconOnly ? 34 : plannerDatePickerButtonMinimumWidth,
                maxWidth: plannerDatePickerButtonMaximumWidth(usesCompactWidth: usesIconOnly),
                alignment: usesIconOnly ? .center : .leading
            )
            .routinaGlassCard(
                cornerRadius: 8,
                tint: isPresented ? Color.accentColor : nil,
                tintOpacity: 0.14,
                interactive: true
            )
        }
        .layoutPriority(3)
        .buttonStyle(.plain)
        .accessibilityLabel("Go to date")
        .accessibilityValue(title)
        .accessibilityHint(plannerDatePickerAccessibilityHint)
        .help("Go to date")
    }

    private var plannerDatePickerButtonTitle: String {
        switch effectiveDisplayMode {
        case .calendar:
            return planner.visibleRangeTitle(calendar: calendar)
        case .list:
            return planner.selectedDate.formatted(date: .abbreviated, time: .omitted)
        }
    }

    private var plannerDatePickerAccessibilityHint: String {
        let plannedText = DayPlanFormatting.durationText(planner.plannedMinutes)
        switch effectiveDisplayMode {
        case .calendar:
            return "\(planner.blocks.count) blocks on selected day, \(plannedText) planned"
        case .list:
            return
                "\(planner.selectedDate.formatted(date: .abbreviated, time: .omitted)), \(planner.blocks.count) blocks, \(plannedText) planned"
        }
    }

    private var plannerDatePickerButtonMinimumWidth: CGFloat? {
        nil
    }

    private func plannerDatePickerButtonMaximumWidth(usesCompactWidth: Bool) -> CGFloat? {
        usesCompactWidth ? 34 : nil
    }

    private var calendarFilterAvailability: DayPlanCalendarFilterAvailability {
        DayPlanCalendarFilterAvailability(
            includesEvents: areMacEventEmotionActionsEnabled,
            includesAway: isAwayEnabled,
            includesSleep: isAwayEnabled
        )
    }
}
