import SwiftUI

enum RecurrenceSelectionPolicy {
    static func updating(
        value: Int,
        isSelected: Bool,
        selection: [Int],
        validRange: ClosedRange<Int>
    ) -> [Int] {
        let boundedValue = min(max(value, validRange.lowerBound), validRange.upperBound)
        var selectedValues = Set(selection.filter(validRange.contains))

        if selectedValues.isEmpty {
            selectedValues.insert(boundedValue)
        }

        if isSelected {
            selectedValues.insert(boundedValue)
        } else if selectedValues.count > 1 {
            selectedValues.remove(boundedValue)
        }

        return selectedValues.sorted()
    }

    static func isAdaptiveMonthDay(_ day: Int) -> Bool {
        (29...31).contains(day)
    }
}

struct RecurrenceWeekdaySelectionControl: View {
    @Binding var selectedWeekdays: [Int]
    let options: [(id: Int, name: String)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(options, id: \.id) { option in
                let isSelected = selectedWeekdays.contains(option.id)
                Button {
                    selectedWeekdays = RecurrenceSelectionPolicy.updating(
                        value: option.id,
                        isSelected: !isSelected,
                        selection: selectedWeekdays,
                        validRange: 1...7
                    )
                } label: {
                    Text(option.name)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .padding(.horizontal, 10)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(
                                    isSelected ? Color.accentColor.opacity(0.8) : Color.secondary.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.name)
                .accessibilityValue(isSelected ? "Selected" : "Not selected")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .frame(maxWidth: 680, alignment: .leading)
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 88), spacing: 8)]
    }
}

struct RecurrenceMonthDaySelectionControl: View {
    @Binding var selectedDays: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 7) {
                ForEach(1...31, id: \.self) { day in
                    monthDayButton(day)
                }
            }
            .frame(maxWidth: 420, alignment: .leading)

            HStack(spacing: 7) {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 7, height: 7)
                Text("29–31 use the month's last valid day when needed.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "Adaptive month days. Days 29 through 31 use the month's last valid day when needed."
            )
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 36), spacing: 7), count: 7)
    }

    private func monthDayButton(_ day: Int) -> some View {
        let isSelected = selectedDays.contains(day)
        let isAdaptive = RecurrenceSelectionPolicy.isAdaptiveMonthDay(day)

        return Button {
            selectedDays = RecurrenceSelectionPolicy.updating(
                value: day,
                isSelected: !isSelected,
                selection: selectedDays,
                validRange: 1...31
            )
        } label: {
            ZStack(alignment: .topTrailing) {
                Text("\(day)")
                    .font(.body.monospacedDigit())
                    .frame(maxWidth: .infinity, minHeight: 36)

                if isAdaptive {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                        .padding(5)
                }
            }
            .foregroundStyle(foregroundColor(isSelected: isSelected, isAdaptive: isAdaptive))
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(backgroundColor(isSelected: isSelected, isAdaptive: isAdaptive))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(borderColor(isSelected: isSelected, isAdaptive: isAdaptive), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(TaskFormPresentation.monthDayControlLabel(for: day))
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(
            isAdaptive ? "Uses the last valid day in shorter months." : ""
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func foregroundColor(isSelected: Bool, isAdaptive: Bool) -> Color {
        if isSelected {
            return .accentColor
        }
        return isAdaptive ? .orange : .primary
    }

    private func backgroundColor(isSelected: Bool, isAdaptive: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(0.18)
        }
        return isAdaptive ? Color.orange.opacity(0.12) : Color.secondary.opacity(0.08)
    }

    private func borderColor(isSelected: Bool, isAdaptive: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(0.8)
        }
        return isAdaptive ? Color.orange.opacity(0.65) : Color.secondary.opacity(0.2)
    }
}
