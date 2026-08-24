import SwiftUI

struct HomeMacCollapsibleFilterSection<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let title: String
    let summaryText: String
    let systemImage: String
    let tint: Color
    let externallyManagedExpansion: Binding<Bool>?
    @ViewBuilder let content: () -> Content
    @State private var locallyManagedExpansion = false
    @State private var contentHeight: CGFloat = 0

    init(
        title: String,
        summaryText: String = "",
        systemImage: String = "slider.horizontal.3",
        tint: Color = .accentColor,
        isExpanded: Binding<Bool>? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.summaryText = summaryText
        self.systemImage = systemImage
        self.tint = tint
        self.externallyManagedExpansion = isExpanded
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                toggleExpanded()
            } label: {
                disclosureHeader
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(accessibilityValue)
            .accessibilityHint(isExpanded ? "Hide options" : "Show all options")

            collapsibleContent
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .routinaGlassPanel(
            cornerRadius: 18,
            tint: tint,
            tintOpacity: isExpanded ? 0.10 : 0.08
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(isExpanded ? 0.28 : 0.18), lineWidth: 1)
        )
        .animation(
            accessibilityReduceMotion ? nil : .snappy(duration: 0.22),
            value: isExpanded
        )
    }

    private var collapsibleContent: some View {
        content()
            .padding(.top, 12)
            .padding(.horizontal, 4)
            .fixedSize(horizontal: false, vertical: true)
            .background(contentHeightReader)
            .frame(height: isExpanded ? contentHeight : 0, alignment: .top)
            .opacity(isExpanded ? 1 : 0)
            .clipped()
            .accessibilityHidden(!isExpanded)
    }

    private var contentHeightReader: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: HomeMacCollapsibleFilterSectionHeightPreferenceKey.self,
                    value: proxy.size.height
                )
        }
        .onPreferenceChange(HomeMacCollapsibleFilterSectionHeightPreferenceKey.self) { height in
            guard abs(height - contentHeight) > 0.5 else { return }
            contentHeight = height
        }
    }

    private var disclosureHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .frame(width: 14)

            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(tint.opacity(0.16))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !summaryText.isEmpty {
                    Text(summaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func toggleExpanded() {
        let newValue = !isExpanded
        if let externallyManagedExpansion {
            externallyManagedExpansion.wrappedValue = newValue
        } else {
            locallyManagedExpansion = newValue
        }
    }

    private var isExpanded: Bool {
        externallyManagedExpansion?.wrappedValue ?? locallyManagedExpansion
    }

    private var accessibilityValue: String {
        let expansionValue = isExpanded ? "Expanded" : "Collapsed"
        guard !summaryText.isEmpty else { return expansionValue }
        return "\(summaryText), \(expansionValue)"
    }
}

private struct HomeMacCollapsibleFilterSectionHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct HomeMacImportanceUrgencyDisclosureSection: View {
    @Binding var selectedFilter: ImportanceUrgencyFilterCell?
    let summaryText: String

    var body: some View {
        HomeMacCollapsibleFilterSection(
            title: "Importance & Urgency",
            summaryText: summaryText,
            systemImage: "square.grid.2x2",
            tint: .orange
        ) {
            HomeMacImportanceUrgencyMatrixView(
                selectedFilter: $selectedFilter,
                summaryText: summaryText
            )
        }
    }
}

struct HomeMacImportanceUrgencyMatrixView: View {
    @Binding var selectedFilter: ImportanceUrgencyFilterCell?
    let summaryText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(selectedFilter == nil ? "All levels selected" : "Show all levels") {
                selectedFilter = nil
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(selectedFilter == nil ? Color.accentColor : Color.primary)

            ImportanceUrgencyMatrixPicker(selectedFilter: $selectedFilter)
                .frame(maxWidth: 420, alignment: .leading)

            Text(summaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct HomeMacTaskLadderFiltersSection: View {
    @Binding var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    @Binding var selectedPressureFilter: RoutineTaskPressure?
    @Binding var selectedThinkingNeededFilter: RoutineTaskThinkingNeeded?
    @Binding var selectedEstimationFilter: TaskEstimationFilter

    var body: some View {
        HomeMacCollapsibleFilterSection(
            title: "Task Ladder values",
            summaryText: summaryText,
            systemImage: "list.number",
            tint: .orange
        ) {
            VStack(alignment: .leading, spacing: 16) {
                filterControl("Importance") {
                    RoutinaGlassSegmentedControl(
                        accessibilityLabel: "Minimum current importance",
                        options: importanceOptions,
                        selection: minimumImportanceBinding,
                        fillsAvailableWidth: true,
                        maximumSegmentsPerRow: 2
                    ) { value in
                        Text(value.map { "\($0.title)+" } ?? "All")
                    }
                }

                filterControl("Urgency") {
                    RoutinaGlassSegmentedControl(
                        accessibilityLabel: "Minimum current urgency",
                        options: urgencyOptions,
                        selection: minimumUrgencyBinding,
                        fillsAvailableWidth: true,
                        maximumSegmentsPerRow: 2
                    ) { value in
                        Text(value.map { "\($0.title)+" } ?? "All")
                    }
                }

                filterControl("Pressure") {
                    RoutinaGlassSegmentedControl(
                        accessibilityLabel: "Minimum current pressure",
                        options: pressureOptions,
                        selection: $selectedPressureFilter,
                        fillsAvailableWidth: true,
                        maximumSegmentsPerRow: 2
                    ) { value in
                        Text(value.map { "\($0.title)+" } ?? "All")
                    }
                }

                filterControl("Thinking needed") {
                    RoutinaGlassSegmentedControl(
                        accessibilityLabel: "Thinking needed",
                        options: thinkingOptions,
                        selection: $selectedThinkingNeededFilter,
                        fillsAvailableWidth: true,
                        maximumSegmentsPerRow: 2
                    ) { value in
                        Text(value?.title ?? "All")
                    }
                }

                filterControl("Estimated time") {
                    RoutinaGlassSegmentedControl(
                        accessibilityLabel: "Estimated time",
                        options: TaskEstimationFilter.allCases,
                        selection: $selectedEstimationFilter,
                        fillsAvailableWidth: true,
                        maximumSegmentsPerRow: 2
                    ) { value in
                        Label(value.title, systemImage: value.systemImage)
                    }
                }

                Text("Importance, Urgency, and Pressure use each task's current Now value.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func filterControl<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private var importanceOptions: [RoutineTaskImportance?] {
        [nil] + RoutineTaskImportance.allCases.dropFirst().map(Optional.some)
    }

    private var urgencyOptions: [RoutineTaskUrgency?] {
        [nil] + RoutineTaskUrgency.allCases.dropFirst().map(Optional.some)
    }

    private var pressureOptions: [RoutineTaskPressure?] {
        [nil] + RoutineTaskPressure.allCases.dropFirst().map(Optional.some)
    }

    private var thinkingOptions: [RoutineTaskThinkingNeeded?] {
        [nil] + RoutineTaskThinkingNeeded.allCases.map(Optional.some)
    }

    private var minimumImportanceBinding: Binding<RoutineTaskImportance?> {
        Binding(
            get: { selectedImportanceUrgencyFilter?.minimumImportance },
            set: {
                selectedImportanceUrgencyFilter = ImportanceUrgencyFilterCell.updatingMinimumImportance(
                    $0,
                    in: selectedImportanceUrgencyFilter
                )
            }
        )
    }

    private var minimumUrgencyBinding: Binding<RoutineTaskUrgency?> {
        Binding(
            get: { selectedImportanceUrgencyFilter?.minimumUrgency },
            set: {
                selectedImportanceUrgencyFilter = ImportanceUrgencyFilterCell.updatingMinimumUrgency(
                    $0,
                    in: selectedImportanceUrgencyFilter
                )
            }
        )
    }

    private var summaryText: String {
        var values: [String] = []
        if let importance = selectedImportanceUrgencyFilter?.minimumImportance {
            values.append("Importance \(importance.title)+")
        }
        if let urgency = selectedImportanceUrgencyFilter?.minimumUrgency {
            values.append("Urgency \(urgency.title)+")
        }
        if let pressure = selectedPressureFilter {
            values.append("Pressure \(pressure.title)+")
        }
        if let thinking = selectedThinkingNeededFilter {
            values.append("Thinking \(thinking.title)")
        }
        if selectedEstimationFilter != .all {
            values.append("Estimated time: \(selectedEstimationFilter.title)")
        }
        return values.isEmpty ? "No Task Ladder value filters" : values.joined(separator: " · ")
    }
}
