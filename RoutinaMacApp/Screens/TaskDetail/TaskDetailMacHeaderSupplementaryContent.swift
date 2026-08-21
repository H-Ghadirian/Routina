import SwiftUI

struct TaskDetailMacHeaderSupplementaryContent<CalendarContent: View>: View {
    let task: RoutineTask
    let goals: [RoutineGoalSummary]
    let selectedDate: Date
    let showPersianDates: Bool
    @Binding var isCalendarExpanded: Bool
    let sectionCardStroke: Color
    let tagTint: (String) -> Color
    let onTagFilterSelected: ((String) -> Void)?
    let calendarContent: CalendarContent

    init(
        task: RoutineTask,
        goals: [RoutineGoalSummary],
        selectedDate: Date,
        showPersianDates: Bool,
        isCalendarExpanded: Binding<Bool>,
        sectionCardStroke: Color,
        tagTint: @escaping (String) -> Color,
        onTagFilterSelected: ((String) -> Void)? = nil,
        @ViewBuilder calendarContent: () -> CalendarContent
    ) {
        self.task = task
        self.goals = goals
        self.selectedDate = selectedDate
        self.showPersianDates = showPersianDates
        _isCalendarExpanded = isCalendarExpanded
        self.sectionCardStroke = sectionCardStroke
        self.tagTint = tagTint
        self.onTagFilterSelected = onTagFilterSelected
        self.calendarContent = calendarContent()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            calendarDisclosure
            metadataRow
            goalsBox
        }
    }

    @ViewBuilder
    private var metadataRow: some View {
        let flags = RoutineFlag.deduplicated(task.flags)
        let hasLabels = !task.tags.isEmpty || !flags.isEmpty
        let hasPoints = !task.isOneOffTask && task.storyPoints != nil

        if hasLabels && hasPoints {
            ViewThatFits(in: .horizontal) {
                TaskDetailEqualHeightPairRow(spacing: 8) { minHeight in
                    labelsBox(flags: flags, minHeight: minHeight)
                } trailing: { minHeight in
                    pointsBox(minHeight: minHeight)
                }

                VStack(alignment: .leading, spacing: 8) {
                    labelsBox(flags: flags)
                    pointsBox()
                }
            }
        } else if hasLabels {
            labelsBox(flags: flags)
        } else if hasPoints {
            pointsBox()
        }
    }

    private func labelsBox(flags: [String], minHeight: CGFloat? = nil) -> some View {
        ViewThatFits(in: .horizontal) {
            singleLineLabelsRow(flags: flags)
            wrappedLabelsRows(flags: flags)
        }
        .detailHeaderBoxStyle(minHeight: minHeight)
    }

    private func singleLineLabelsRow(flags: [String]) -> some View {
        HStack(alignment: .center, spacing: 10) {
            if !task.tags.isEmpty {
                labelsHeading("TAGS")

                HStack(spacing: 6) {
                    ForEach(task.tags, id: \.self) { tag in
                        statusTagChip(tag)
                    }
                }
            }

            if !task.tags.isEmpty && !flags.isEmpty {
                Divider()
                    .frame(height: 28)
            }

            if !flags.isEmpty {
                labelsHeading("FLAGS")

                HStack(spacing: 6) {
                    ForEach(flags, id: \.self) { flag in
                        TaskDetailFlagChip(flag: flag)
                    }
                }
            }
        }
        .fixedSize(horizontal: true, vertical: true)
    }

    private func wrappedLabelsRows(flags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !task.tags.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    labelsHeading("TAGS")
                        .frame(minHeight: 28, alignment: .center)

                    HomeFilterFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                        ForEach(task.tags, id: \.self) { tag in
                            statusTagChip(tag)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !task.tags.isEmpty && !flags.isEmpty {
                Divider()
                    .padding(.vertical, 2)
            }

            if !flags.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    labelsHeading("FLAGS")
                        .frame(minHeight: 28, alignment: .center)

                    HomeFilterFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                        ForEach(flags, id: \.self) { flag in
                            TaskDetailFlagChip(flag: flag)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func labelsHeading(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .fixedSize()
    }

    @ViewBuilder
    private func pointsBox(minHeight: CGFloat? = nil) -> some View {
        if let storyPoints = task.storyPoints {
            VStack(alignment: .leading, spacing: 4) {
                Text("POINTS")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(TaskDetailHeaderBadgePresentation.storyPointsText(for: storyPoints))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .detailHeaderBoxStyle(tint: .purple, minHeight: minHeight)
        }
    }

    @ViewBuilder
    private var goalsBox: some View {
        if !goals.isEmpty {
            TaskDetailGoalsHeaderBoxView(goals: goals)
        }
    }

    private var calendarDisclosure: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isCalendarExpanded.toggle()
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CALENDAR")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.blue)
                            Text(calendarSummaryText)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isCalendarExpanded ? 180 : 0))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isCalendarExpanded {
                Divider()
                calendarContent
                    .taskDetailScrollCardSurface(
                        cornerRadius: 12,
                        tint: .secondary,
                        tintOpacity: 0.06,
                        stroke: sectionCardStroke
                    )
            }
        }
        .detailHeaderBoxStyle(tint: .blue)
    }

    private var calendarSummaryText: String {
        let dateText = PersianDateDisplay.appendingSupplementaryDate(
            to: selectedDate.formatted(date: .abbreviated, time: .omitted),
            for: selectedDate,
            enabled: showPersianDates
        )
        if Calendar.current.isDateInToday(selectedDate) {
            return "Today • \(dateText)"
        }
        return dateText
    }

    private func statusTagChip(_ tag: String) -> some View {
        TaskDetailMacFilterableTagChip(
            tag: tag,
            tint: tagTint(tag),
            onSelect: onTagFilterSelected
        )
    }
}

struct TaskDetailMacFilterableTagChip: View {
    let tag: String
    let tint: Color
    let onSelect: ((String) -> Void)?

    var body: some View {
        if let onSelect {
            Button {
                onSelect(tag)
            } label: {
                label
            }
            .buttonStyle(.plain)
            .contentShape(Capsule(style: .continuous))
            .accessibilityLabel("Filter task list by \(tag) tag")
            .help("Filter task list by #\(tag)")
        } else {
            label
        }
    }

    private var label: some View {
        Text("#\(tag)")
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .routinaGlassPill(tint: tint, tintOpacity: 0.13)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tint.opacity(0.25), lineWidth: 1)
            )
            .contentShape(Capsule(style: .continuous))
    }
}
