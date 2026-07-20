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
        let hasTags = !task.tags.isEmpty
        let hasLinks = !task.resolvedLinkURLs.isEmpty
        let hasPoints = !task.isOneOffTask && task.storyPoints != nil

        if hasLinks && hasPoints {
            ViewThatFits(in: .horizontal) {
                TaskDetailEqualHeightPairRow(spacing: 8) { minHeight in
                    detailsBox(includesTags: hasTags, minHeight: minHeight)
                } trailing: { minHeight in
                    pointsBox(minHeight: minHeight)
                }

                VStack(alignment: .leading, spacing: 8) {
                    detailsBox(includesTags: hasTags)
                    pointsBox()
                }
            }
        } else if hasLinks {
            detailsBox(includesTags: hasTags)
        } else if hasTags && hasPoints {
            ViewThatFits(in: .horizontal) {
                TaskDetailEqualHeightPairRow(spacing: 8) { minHeight in
                    tagsBox(minHeight: minHeight)
                } trailing: { minHeight in
                    pointsBox(minHeight: minHeight)
                }

                VStack(alignment: .leading, spacing: 8) {
                    tagsBox()
                    pointsBox()
                }
            }
        } else if hasTags {
            tagsBox()
        } else if hasPoints {
            pointsBox()
        }
    }

    private func tagsBox(minHeight: CGFloat? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TAGS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            HomeFilterFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(task.tags, id: \.self) { tag in
                    statusTagChip(tag)
                }
            }
        }
        .detailHeaderBoxStyle(minHeight: minHeight)
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
    private func detailsBox(includesTags: Bool, minHeight: CGFloat? = nil) -> some View {
        let links = task.resolvedLinkURLs
        let tags = includesTags ? task.tags : []

        if !links.isEmpty || !tags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("DETAILS")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                if !tags.isEmpty {
                    HomeFilterFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            statusTagChip(tag)
                        }
                    }
                }

                if !tags.isEmpty && !links.isEmpty {
                    Divider()
                        .padding(.vertical, 2)
                }

                if !links.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(links) { link in
                            Link(destination: link.url) {
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Image(systemName: "link")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.blue)
                                    Text(link.text)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.blue)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .taskDetailCopyableText(link.text)
                        }
                    }
                }
            }
            .detailHeaderBoxStyle(minHeight: minHeight)
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
