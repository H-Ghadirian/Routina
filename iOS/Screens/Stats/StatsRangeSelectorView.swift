import SwiftUI

struct StatsRangeSelectorView: View {
    let selectedRange: DoneChartRange
    let onSelectRange: (DoneChartRange) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
    @State private var customEnd = Date()

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(DoneChartRange.allCases) { range in
                    rangeButton(for: range)
                }
            }

            customRangeButton

            if selectedRange.kind == .custom {
                customDateFields
            }
        }
        .padding(6)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(selectorBackground)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white, lineWidth: 1)
                .opacity(selectorOutlineOpacity)
        )
        .onAppear(perform: syncCustomDates)
        .onChange(of: selectedRange) { _, _ in syncCustomDates() }
    }

    private var customRangeButton: some View {
        Button {
            onSelectRange(.custom(from: customStart, through: customEnd))
        } label: {
            Label(
                selectedRange.kind == .custom ? selectedRange.periodDescription : "Custom range",
                systemImage: "calendar.badge.plus"
            )
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var customDateFields: some View {
        HStack(spacing: 12) {
            DatePicker("From", selection: $customStart, in: ...customEnd, displayedComponents: .date)
            DatePicker("Through", selection: $customEnd, in: customStart..., displayedComponents: .date)
        }
        .font(.caption)
        .onChange(of: customStart) { _, _ in applyCustomDates() }
        .onChange(of: customEnd) { _, _ in applyCustomDates() }
    }

    private func applyCustomDates() {
        onSelectRange(.custom(from: customStart, through: customEnd))
    }

    private func syncCustomDates() {
        guard selectedRange.kind == .custom else { return }
        customStart = selectedRange.customStart ?? customStart
        customEnd = selectedRange.customEnd ?? customEnd
    }

    private func rangeButton(for range: DoneChartRange) -> some View {
        let isSelected = selectedRange == range

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                onSelectRange(range)
            }
        } label: {
            VStack(spacing: 4) {
                Text(range.rawValue)
                    .font(.subheadline.weight(.semibold))

                Text(subtitle(for: range))
                    .font(.caption2.weight(.medium))
                    .opacity(isSelected ? 0.9 : 0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background {
                buttonBackground(isSelected: isSelected)
            }
        }
        .buttonStyle(.plain)
    }

    private func subtitle(for range: DoneChartRange) -> String {
        switch range.kind {
        case .today:
            return "1 day"
        case .week:
            return "7 days"
        case .month:
            return "30 days"
        case .year:
            return "1 year"
        case .custom:
            return "Custom"
        }
    }

    private var selectorBackground: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color.white.opacity(0.06),
                    Color.white.opacity(0.03)
                ]
                : [
                    Color.white.opacity(0.96),
                    Color.white.opacity(0.82)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var selectorActiveFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.95),
                Color.blue.opacity(0.75)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var selectorOutlineOpacity: Double {
        colorScheme == .dark ? 0.08 : 0.45
    }

    @ViewBuilder
    private func buttonBackground(isSelected: Bool) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(selectorActiveFill)
                .shadow(color: Color.accentColor.opacity(0.28), radius: 16, y: 8)
        }
    }
}
