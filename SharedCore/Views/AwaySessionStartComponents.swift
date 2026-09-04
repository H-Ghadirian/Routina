import SwiftUI

struct AwayStartHeroCard: View {
    let option: AwayStartPresetOption
    let timerMode: AwaySessionTimerMode
    let durationMinutes: Int
    var titleOverride: String?
    var subtitleOverride: String?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 18) {
                heroIcon
                titleBlock
                Spacer(minLength: 16)
                heroMetric
            }

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    heroIcon
                    titleBlock
                }
                heroMetric
            }
        }
        .padding(20)
        .routinaGlassPanel(cornerRadius: 18, tint: option.tint, tintOpacity: 0.10)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(option.tint.opacity(0.22), lineWidth: 1)
        }
    }

    private var heroIcon: some View {
        Image(systemName: option.systemImage)
            .font(.system(size: 30, weight: .semibold))
            .foregroundStyle(.white)
            .symbolRenderingMode(.hierarchical)
            .frame(width: 62, height: 62)
            .background(
                LinearGradient(
                    colors: [
                        option.tint,
                        option.tint.opacity(0.58),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(option.modeEyebrow)
                .font(.caption.weight(.bold))
                .foregroundStyle(option.tint)
                .textCase(.uppercase)

            Text(titleOverride ?? option.title)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(subtitleOverride ?? option.startLine)
                .font(.headline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var heroMetric: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(option.timerSummary(timerMode: timerMode, durationMinutes: durationMinutes))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(option.timerCaption(timerMode: timerMode))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .routinaGlassCard(cornerRadius: 14, tint: option.tint, tintOpacity: 0.08)
    }
}

struct AwayStartPresetPickerPanel: View {
    @Binding var selectedOption: AwayStartPresetOption
    let options: [AwayStartPresetOption]
    let selectedTint: Color

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Preset", systemImage: "square.grid.2x2.fill")
                .font(.headline)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(options) { option in
                    AwayPresetCard(
                        title: option.title,
                        systemImage: option.systemImage,
                        defaultDurationText: option.defaultDurationText,
                        presetTint: option.tint,
                        isSelected: selectedOption == option,
                        selectedTint: selectedTint
                    ) {
                        selectedOption = option
                    }
                }
            }
        }
        .padding(16)
        .routinaGlassPanel(cornerRadius: 16, tint: selectedTint, tintOpacity: 0.06)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

struct AwayPresetPickerPanel: View {
    @Binding var selectedPreset: AwaySessionPreset
    let selectedTint: Color

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Preset", systemImage: "square.grid.2x2.fill")
                .font(.headline)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(AwaySessionPreset.allCases) { preset in
                    AwayPresetCard(
                        title: preset.title,
                        systemImage: preset.systemImage,
                        defaultDurationText: preset.defaultDurationText,
                        presetTint: preset.tint,
                        isSelected: selectedPreset == preset,
                        selectedTint: selectedTint
                    ) {
                        selectedPreset = preset
                    }
                }
            }
        }
        .padding(16)
        .routinaGlassPanel(cornerRadius: 16, tint: selectedTint, tintOpacity: 0.06)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct AwayPresetCard: View {
    let title: String
    let systemImage: String
    let defaultDurationText: String
    let presetTint: Color
    let isSelected: Bool
    let selectedTint: Color
    let action: () -> Void

    private var tint: Color {
        isSelected ? selectedTint : presetTint
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : tint)
                        .frame(width: 34, height: 34)
                        .background(
                            isSelected ? tint : tint.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )

                    Spacer(minLength: 8)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isSelected ? tint : .secondary.opacity(0.55))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(defaultDurationText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 98, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(isSelected ? 0.16 : 0.06))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(tint.opacity(isSelected ? 0.55 : 0.14), lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct AwayTimerSetupPanel: View {
    @Binding var timerMode: AwaySessionTimerMode
    @Binding var durationMinutes: Int
    let tint: Color

    private let quickDurations = [10, 15, 20, 30, 45, 60, 90]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Timer", systemImage: "timer")
                .font(.headline)

            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Timer",
                options: AwaySessionTimerMode.allCases,
                selection: $timerMode,
                fillsAvailableWidth: true
            ) { mode in
                Text(mode.title)
            }

            if timerMode == .fixedDuration {
                fixedDurationControls
            } else {
                countUpContent
            }
        }
        .padding(16)
        .routinaGlassPanel(cornerRadius: 16, tint: tint, tintOpacity: 0.06)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var fixedDurationControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(durationMinutes)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("min")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Slider(value: durationSliderBinding, in: 1...180, step: 5)
                .tint(tint)

            HomeFilterFlowLayout(horizontalSpacing: 7, verticalSpacing: 7) {
                ForEach(quickDurations, id: \.self) { minutes in
                    Button {
                        durationMinutes = minutes
                    } label: {
                        Text("\(minutes)m")
                            .font(.caption.weight(.semibold))
                            .frame(minWidth: 42)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(durationMinutes == minutes ? .white : tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        durationMinutes == minutes ? tint : tint.opacity(0.12),
                        in: Capsule()
                    )
                }
            }

            Stepper(
                "Fine tune: \(durationMinutes)m",
                value: $durationMinutes,
                in: 1...720,
                step: 5
            )
            .font(.subheadline)
        }
    }

    private var countUpContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Open-ended")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text("Start now and stop it when you return.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var durationSliderBinding: Binding<Double> {
        Binding(
            get: { Double(min(durationMinutes, 180)) },
            set: { durationMinutes = max(1, Int($0.rounded())) }
        )
    }
}

struct AwayStartSummaryPanel: View {
    let option: AwayStartPresetOption
    let timerMode: AwaySessionTimerMode
    let durationMinutes: Int
    let errorText: String?
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Ready", systemImage: "play.circle.fill")
                .font(.headline)

            VStack(spacing: 10) {
                AwayStartSummaryRow(
                    title: "Preset",
                    value: option.title,
                    systemImage: option.systemImage,
                    tint: option.tint
                )
                AwayStartSummaryRow(
                    title: "Timer",
                    value: option.timerText(timerMode: timerMode, durationMinutes: durationMinutes),
                    systemImage: option.timerSystemImage(timerMode: timerMode),
                    tint: option.tint
                )
                AwayStartSummaryRow(
                    title: "Starts",
                    value: "Now",
                    systemImage: "paperplane.fill",
                    tint: option.tint
                )
            }

            Button {
                onStart()
            } label: {
                Label(option.startActionTitle, systemImage: option.startActionSystemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(option.actionForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(option.actionTint, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(0.16), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .contentShape(Capsule())
            .keyboardShortcut(.defaultAction)

            if let errorText {
                Text(errorText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .routinaGlassPanel(cornerRadius: 16, tint: option.tint, tintOpacity: 0.08)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(option.tint.opacity(0.18), lineWidth: 1)
        }
    }
}

struct AwayStartSummaryRow: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 10)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
    }
}
