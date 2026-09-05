import SwiftUI

extension DayPlanWeekCalendarView {
    func presentSlotSidebar(on date: Date, startMinute: Int) {
        guard slotSidebarContent != nil else { return }
        onSidebarPresentationRequested?()
        isFilterSidebarPresented.wrappedValue = false
        isDatePickerSidebarPresented.wrappedValue = false
        draftResizeBaseline = nil
        selectedDayTaskListDate = nil
        selectedTagFocusSessionID = nil
        let clampedStartMinute = DayPlanBlock.clampedStartMinute(startMinute)
        selectedSlotDraft = DayPlanSelectedSlotDraft(
            date: calendar.startOfDay(for: date),
            startMinute: clampedStartMinute,
            durationMinutes: defaultSlotDraftDuration(startMinute: clampedStartMinute)
        )
    }

    func updateSelectedSlotDraft(on date: Date, startMinute: Int) {
        guard var draft = selectedSlotDraft else { return }

        let clampedStartMinute = DayPlanBlock.clampedStartMinute(startMinute)
        draft.date = calendar.startOfDay(for: date)
        draft.startMinute = clampedStartMinute
        draft.durationMinutes = DayPlanBlock.clampedDuration(
            draft.durationMinutes,
            startMinute: clampedStartMinute,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )
        selectedSlotDraft = draft
    }

    func presentDayTaskListSidebar(on date: Date) {
        guard calendarTaskViewMode == .schedule,
            dayTaskListSidebarContent != nil
        else {
            return
        }
        onSidebarPresentationRequested?()
        isFilterSidebarPresented.wrappedValue = false
        isDatePickerSidebarPresented.wrappedValue = false
        selectedSlotDraft = nil
        selectedTagFocusSessionID = nil
        draftResizeBaseline = nil
        selectedDayTaskListDate = calendar.startOfDay(for: date)
    }

    @discardableResult
    func presentTagFocusSidebar(for block: DayPlanBlock) -> Bool {
        guard tagFocusSidebarContent != nil,
            let sessionID = completedTagFocusSessionID(block)
        else {
            return false
        }

        onSidebarPresentationRequested?()
        isFilterSidebarPresented.wrappedValue = false
        isDatePickerSidebarPresented.wrappedValue = false
        selectedSlotDraft = nil
        selectedDayTaskListDate = nil
        draftResizeBaseline = nil
        selectedTagFocusSessionID = sessionID
        return true
    }

    @ViewBuilder
    func selectedSlotDraftLayer(
        dayWidth: CGFloat,
        timeAxis: DayPlanAdaptiveTimeAxis,
        timeColumnWidth: CGFloat,
        contentWidth: CGFloat,
        contentHeight: CGFloat
    ) -> some View {
        if let selectedSlotDraft {
            if let dayIndex = dates.firstIndex(where: {
                calendar.isDate($0, inSameDayAs: selectedSlotDraft.date)
            }) {
                let draftX = timeColumnWidth + CGFloat(dayIndex) * dayWidth + 5
                let draftWidth = max(dayWidth - 10, 90)
                let draftY = timeAxis.yOffset(forMinute: selectedSlotDraft.startMinute)
                let draftHeight = draftBlockHeight(for: selectedSlotDraft, timeAxis: timeAxis)

                ZStack(alignment: .topLeading) {
                    DayPlanSlotDraftBlock(
                        date: selectedSlotDraft.date,
                        startMinute: selectedSlotDraft.startMinute,
                        durationMinutes: selectedSlotDraft.durationMinutes,
                        renderedHeight: draftHeight,
                        calendar: calendar,
                        onResizeStarted: {
                            beginDraftResize(timeAxis: timeAxis)
                        },
                        onResizeChanged: { edge, verticalDelta in
                            resizeDraft(
                                edge: edge,
                                verticalDelta: verticalDelta,
                                timeAxis: timeAxis
                            )
                        },
                        onResizeEnded: endDraftResize
                    )
                    .frame(width: draftWidth, height: draftHeight)
                    .position(x: draftX + (draftWidth / 2), y: draftY + (draftHeight / 2))
                }
                .frame(width: contentWidth, height: contentHeight, alignment: .topLeading)
                .zIndex(70)
            }
        }
    }

    @ViewBuilder
    var plannerRightSidebar: some View {
        if isRightSidebarPresented {
            Divider()

            ScrollView {
                plannerRightSidebarContent
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.visible)
            .frame(width: DayPlanSlotSidebarPresentation.width)
            .background(Color.secondary.opacity(0.045))
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    var isRightSidebarPresented: Bool {
        !isExternalInspectorPresented
            && ((selectedSlotDraft != nil && slotSidebarContent != nil)
                || (calendarTaskViewMode == .schedule
                    && selectedDayTaskListDate != nil
                    && dayTaskListSidebarContent != nil)
                || (selectedTagFocusSessionID != nil && tagFocusSidebarContent != nil)
                || (isFilterSidebarPresented.wrappedValue && filterSidebarContent != nil)
                || (isDatePickerSidebarPresented.wrappedValue && datePickerSidebarContent != nil))
    }

    @ViewBuilder
    var plannerRightSidebarContent: some View {
        if let selectedSlotDraft, let slotSidebarContent {
            slotSidebarContent(
                selectedSlotDraft.date,
                selectedSlotDraft.startMinute,
                selectedSlotDurationBinding(for: selectedSlotDraft),
                dismissSelectedSlotSidebar
            )
        } else if calendarTaskViewMode == .schedule,
            let selectedDayTaskListDate,
            let dayTaskListSidebarContent
        {
            dayTaskListSidebarContent(
                selectedDayTaskListDate,
                dismissDayTaskListSidebar
            )
        } else if let selectedTagFocusSessionID, let tagFocusSidebarContent {
            tagFocusSidebarContent(
                selectedTagFocusSessionID,
                dismissTagFocusSidebar
            )
        } else if isFilterSidebarPresented.wrappedValue, let filterSidebarContent {
            filterSidebarContent(dismissFilterSidebar)
        } else if isDatePickerSidebarPresented.wrappedValue, let datePickerSidebarContent {
            datePickerSidebarContent(dismissDatePickerSidebar)
        }
    }

    func dismissSelectedSlotSidebar() {
        selectedSlotDraft = nil
        draftResizeBaseline = nil
    }

    func dismissDayTaskListSidebar() {
        selectedDayTaskListDate = nil
    }

    func dismissTagFocusSidebar() {
        selectedTagFocusSessionID = nil
    }

    func dismissFilterSidebar() {
        isFilterSidebarPresented.wrappedValue = false
    }

    func dismissDatePickerSidebar() {
        isDatePickerSidebarPresented.wrappedValue = false
    }

    func dismissPlannerRightSidebar() {
        selectedSlotDraft = nil
        selectedDayTaskListDate = nil
        selectedTagFocusSessionID = nil
        draftResizeBaseline = nil
        isFilterSidebarPresented.wrappedValue = false
        isDatePickerSidebarPresented.wrappedValue = false
    }

    func clearDayTaskListIfOutsideVisibleDates() {
        guard let selectedDayTaskListDate else { return }
        guard !dates.contains(where: { calendar.isDate($0, inSameDayAs: selectedDayTaskListDate) }) else {
            return
        }
        self.selectedDayTaskListDate = nil
    }

    func selectedSlotDurationBinding(for selection: DayPlanSelectedSlotDraft) -> Binding<Int> {
        Binding(
            get: {
                selectedSlotDraft?.durationMinutes ?? selection.durationMinutes
            },
            set: { newValue in
                guard var draft = selectedSlotDraft else { return }
                draft.durationMinutes = clampedSlotDraftDuration(newValue)
                selectedSlotDraft = draft
            }
        )
    }

    func defaultSlotDraftDuration(startMinute: Int) -> Int {
        DayPlanBlock.clampedDuration(
            max(dropDurationMinutes, DayPlanBlock.minimumDurationMinutes),
            startMinute: startMinute,
            minimumDurationMinutes: DayPlanBlock.minimumDurationMinutes
        )
    }

    func clampedSlotDraftDuration(_ durationMinutes: Int) -> Int {
        min(
            max(durationMinutes, DayPlanBlock.minimumStoredDurationMinutes),
            16 * 60
        )
    }

    func beginDraftResize(timeAxis: DayPlanAdaptiveTimeAxis) {
        draftResizeBaseline = selectedSlotDraft
        frozenTimeAxis = timeAxis
    }

    func resizeDraft(
        edge: DayPlanResizeEdge,
        verticalDelta: CGFloat,
        timeAxis: DayPlanAdaptiveTimeAxis
    ) {
        guard let baseline = draftResizeBaseline ?? selectedSlotDraft else { return }

        let originalStart = baseline.startMinute
        let visualOriginalEnd = min(
            DayPlanBlock.minutesPerDay,
            originalStart
                + max(
                    baseline.durationMinutes,
                    DayPlanBlock.minimumStoredDurationMinutes
                )
        )
        let deltaMinutes = timeAxis.minuteDelta(
            forVerticalDelta: verticalDelta,
            fromMinute: edge == .top ? originalStart : visualOriginalEnd,
            snappingTo: 15
        )
        let startMinute: Int
        let durationMinutes: Int

        switch edge {
        case .top:
            let maxStart = visualOriginalEnd - DayPlanBlock.minimumStoredDurationMinutes
            startMinute = min(max(originalStart + deltaMinutes, 0), maxStart)
            durationMinutes = visualOriginalEnd - startMinute
        case .bottom:
            let minEnd = originalStart + DayPlanBlock.minimumStoredDurationMinutes
            let endMinute = min(max(visualOriginalEnd + deltaMinutes, minEnd), DayPlanBlock.minutesPerDay)
            startMinute = originalStart
            durationMinutes = endMinute - originalStart
        }

        guard var draft = selectedSlotDraft else { return }
        draft.startMinute = DayPlanBlock.clampedStartMinute(startMinute)
        draft.durationMinutes = clampedSlotDraftDuration(durationMinutes)
        selectedSlotDraft = draft
    }

    func endDraftResize() {
        draftResizeBaseline = nil
        frozenTimeAxis = nil
    }

    func draftBlockHeight(
        for selection: DayPlanSelectedSlotDraft,
        timeAxis: DayPlanAdaptiveTimeAxis
    ) -> CGFloat {
        let visibleDurationMinutes = min(
            max(selection.durationMinutes, DayPlanBlock.minimumStoredDurationMinutes),
            DayPlanBlock.minutesPerDay - selection.startMinute
        )
        return max(
            timeAxis.height(
                startMinute: selection.startMinute,
                durationMinutes: visibleDurationMinutes
            ),
            DayPlanAdaptiveTimeAxis.minimumInteractiveBlockHeight
        )
    }
}
