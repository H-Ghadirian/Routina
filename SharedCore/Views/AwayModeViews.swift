import SwiftData
import SwiftUI

extension View {
    func awayModeGate() -> some View {
        modifier(AwayModeRootModifier())
    }
}

private struct AwayModeRootModifier: ViewModifier {
    @Query private var activeAwaySessions: [AwaySession]

    init() {
        _activeAwaySessions = Query(
            filter: #Predicate<AwaySession> { session in
                session.completedAt == nil && session.endedEarlyAt == nil
            },
            sort: \.startedAt,
            order: .reverse
        )
    }

    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(activeAwaySession != nil)

            if let activeAwaySession {
                AwayModeFullScreenView(session: activeAwaySession)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: activeAwaySession?.id)
        #if os(macOS)
        .toolbarVisibility(activeAwaySession == nil ? .automatic : .hidden, for: .windowToolbar)
        #endif
    }

    private var activeAwaySession: AwaySession? {
        activeAwaySessions.first
    }
}

private enum AwaySessionTimerMode: String, CaseIterable, Identifiable {
    case fixedDuration
    case countUp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fixedDuration:
            return "Duration"
        case .countUp:
            return "Count Up"
        }
    }
}

enum AwaySessionStartPresentation {
    case sheet
    case inline
}

struct AwaySessionStartSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedPreset: AwaySessionPreset = .wake
    @State private var timerMode: AwaySessionTimerMode = .fixedDuration
    @State private var durationMinutes = AwaySessionPreset.wake.defaultDurationMinutes
    @State private var hasCustomizedDuration = false
    @State private var errorText: String?
    var presentation: AwaySessionStartPresentation = .sheet
    var onCancel: () -> Void = {}
    var onStarted: () -> Void = {}
    var dismissOnCompletion = true

    var body: some View {
        NavigationStack {
            startContent
            .navigationTitle("Start Away")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        startAway()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private var startContent: some View {
        switch presentation {
        case .sheet:
            sheetContent
        case .inline:
            inlineContent
        }
    }

    private var sheetContent: some View {
        Form {
            Section("Preset") {
                Picker("Preset", selection: selectedPresetBinding) {
                    ForEach(AwaySessionPreset.allCases) { preset in
                        Label(preset.title, systemImage: preset.systemImage)
                            .tag(preset)
                    }
                }
                .pickerStyle(.inline)
            }

            Section("Timer") {
                Picker("Timer", selection: $timerMode) {
                    ForEach(AwaySessionTimerMode.allCases) { mode in
                        Text(mode.title)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if timerMode == .fixedDuration {
                    Stepper(
                        "Duration: \(durationMinutes)m",
                        value: durationMinutesBinding,
                        in: 1...720,
                        step: 5
                    )
                } else {
                    LabeledContent("Duration") {
                        Text("Open-ended")
                    }
                }
            }

            if let errorText {
                Section {
                    Text(errorText)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var inlineContent: some View {
        ZStack {
            LinearGradient(
                colors: [
                    selectedPreset.tint.opacity(0.18),
                    Color.secondary.opacity(0.04),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AwayStartHeroCard(
                        preset: selectedPreset,
                        timerMode: timerMode,
                        durationMinutes: durationMinutes
                    )

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            AwayPresetPickerPanel(
                                selectedPreset: selectedPresetBinding,
                                selectedTint: selectedPreset.tint
                            )
                            .frame(maxWidth: .infinity, alignment: .top)

                            VStack(spacing: 16) {
                                AwayTimerSetupPanel(
                                    timerMode: $timerMode,
                                    durationMinutes: durationMinutesBinding,
                                    tint: selectedPreset.tint
                                )

                                AwayStartSummaryPanel(
                                    preset: selectedPreset,
                                    timerMode: timerMode,
                                    durationMinutes: durationMinutes,
                                    errorText: errorText,
                                    onStart: startAway
                                )
                            }
                            .frame(width: 330)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            AwayPresetPickerPanel(
                                selectedPreset: selectedPresetBinding,
                                selectedTint: selectedPreset.tint
                            )

                            AwayTimerSetupPanel(
                                timerMode: $timerMode,
                                durationMinutes: durationMinutesBinding,
                                tint: selectedPreset.tint
                            )

                            AwayStartSummaryPanel(
                                preset: selectedPreset,
                                timerMode: timerMode,
                                durationMinutes: durationMinutes,
                                errorText: errorText,
                                onStart: startAway
                            )
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: 1020, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    private var selectedPresetBinding: Binding<AwaySessionPreset> {
        Binding(
            get: { selectedPreset },
            set: { preset in
                selectedPreset = preset
                if !hasCustomizedDuration {
                    durationMinutes = preset.defaultDurationMinutes
                }
            }
        )
    }

    private var durationMinutesBinding: Binding<Int> {
        Binding(
            get: { durationMinutes },
            set: { value in
                durationMinutes = value
                hasCustomizedDuration = true
            }
        )
    }

    @MainActor
    private func cancel() {
        onCancel()
        if dismissOnCompletion {
            dismiss()
        }
    }

    @MainActor
    private func startAway() {
        do {
            _ = try AwaySessionSupport.startAway(
                preset: selectedPreset,
                durationMinutes: timerMode == .fixedDuration ? durationMinutes : nil,
                countsUp: timerMode == .countUp,
                context: modelContext
            )
            errorText = nil
            onStarted()
            if dismissOnCompletion {
                dismiss()
            }
        } catch {
            errorText = error.localizedDescription
            NSLog("Failed to start away session: \(error.localizedDescription)")
        }
    }
}

private struct AwayStartHeroCard: View {
    let preset: AwaySessionPreset
    let timerMode: AwaySessionTimerMode
    let durationMinutes: Int

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
        .routinaGlassPanel(cornerRadius: 18, tint: preset.tint, tintOpacity: 0.10)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(preset.tint.opacity(0.22), lineWidth: 1)
        }
    }

    private var heroIcon: some View {
        Image(systemName: preset.systemImage)
            .font(.system(size: 30, weight: .semibold))
            .foregroundStyle(.white)
            .symbolRenderingMode(.hierarchical)
            .frame(width: 62, height: 62)
            .background(
                LinearGradient(
                    colors: [
                        preset.tint,
                        preset.tint.opacity(0.58)
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
            Text("Away mode")
                .font(.caption.weight(.bold))
                .foregroundStyle(preset.tint)
                .textCase(.uppercase)

            Text(preset.title)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(preset.startLine)
                .font(.headline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var heroMetric: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(timerSummary)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(timerMode == .fixedDuration ? "protected timer" : "open timer")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .routinaGlassCard(cornerRadius: 14, tint: preset.tint, tintOpacity: 0.08)
    }

    private var timerSummary: String {
        timerMode == .fixedDuration ? "\(durationMinutes)m" : "Count up"
    }
}

private struct AwayPresetPickerPanel: View {
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
                        preset: preset,
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
    let preset: AwaySessionPreset
    let isSelected: Bool
    let selectedTint: Color
    let action: () -> Void

    private var tint: Color {
        isSelected ? selectedTint : preset.tint
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: preset.systemImage)
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
                    Text(preset.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(preset.defaultDurationText)
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

private struct AwayTimerSetupPanel: View {
    @Binding var timerMode: AwaySessionTimerMode
    @Binding var durationMinutes: Int
    let tint: Color

    private let quickDurations = [10, 15, 20, 30, 45, 60, 90]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Timer", systemImage: "timer")
                .font(.headline)

            Picker("Timer", selection: $timerMode) {
                ForEach(AwaySessionTimerMode.allCases) { mode in
                    Text(mode.title)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)

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

private struct AwayStartSummaryPanel: View {
    let preset: AwaySessionPreset
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
                    value: preset.title,
                    systemImage: preset.systemImage,
                    tint: preset.tint
                )
                AwayStartSummaryRow(
                    title: "Timer",
                    value: timerText,
                    systemImage: timerMode == .fixedDuration ? "timer" : "infinity",
                    tint: preset.tint
                )
                AwayStartSummaryRow(
                    title: "Starts",
                    value: "Now",
                    systemImage: "paperplane.fill",
                    tint: preset.tint
                )
            }

            Button {
                onStart()
            } label: {
                Label("Start Away", systemImage: "lock.shield.fill")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(preset.tint)
            .keyboardShortcut(.defaultAction)

            if let errorText {
                Text(errorText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .routinaGlassPanel(cornerRadius: 16, tint: preset.tint, tintOpacity: 0.08)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(preset.tint.opacity(0.18), lineWidth: 1)
        }
    }

    private var timerText: String {
        timerMode == .fixedDuration ? "\(durationMinutes)m duration" : "Count up"
    }
}

private struct AwayStartSummaryRow: View {
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

private extension AwaySessionPreset {
    var tint: Color {
        switch self {
        case .wake:
            return .orange
        case .reset:
            return .teal
        case .outside:
            return .green
        case .windDown:
            return .indigo
        case .meal:
            return .pink
        case .custom:
            return .cyan
        }
    }

    var defaultDurationText: String {
        "\(defaultDurationMinutes)m default"
    }

    var startLine: String {
        switch self {
        case .wake:
            return "A clean first pocket away from the screen."
        case .reset:
            return "A short reset before the next thing."
        case .outside:
            return "A protected walk or errand."
        case .windDown:
            return "A softer landing before rest."
        case .meal:
            return "A meal without the app pulling you back."
        case .custom:
            return "A flexible away session."
        }
    }
}

private struct AwayModeFullScreenView: View {
    @Environment(\.modelContext) private var modelContext
    let session: AwaySession
    @State private var errorText: String?

    var body: some View {
        ZStack {
            awayBackground

            SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { timeline in
                AwayModeContent(
                    session: session,
                    now: timeline.date,
                    errorText: errorText,
                    onExtend: extendAway,
                    onEnd: endAway
                )
                .task(id: session.isExpired(at: timeline.date)) {
                    guard session.isExpired(at: timeline.date) else { return }
                    completeExpired(referenceDate: timeline.date)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
    }

    private var awayBackground: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.04, green: 0.12, blue: 0.12),
                Color(red: 0.09, green: 0.10, blue: 0.15)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @MainActor
    private func completeExpired(referenceDate: Date) {
        do {
            _ = try AwaySessionSupport.completeExpiredSessions(
                in: modelContext,
                referenceDate: referenceDate
            )
            errorText = nil
        } catch {
            errorText = "Could not save away time."
            NSLog("Failed to complete expired away session: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func extendAway() {
        do {
            _ = try AwaySessionSupport.extendActiveAway(
                byMinutes: 5,
                in: modelContext
            )
            errorText = nil
        } catch {
            errorText = "Could not extend away time."
            NSLog("Failed to extend away session: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func endAway() {
        do {
            if session.isCountUp {
                _ = try AwaySessionSupport.completeActiveAway(in: modelContext)
            } else {
                _ = try AwaySessionSupport.endActiveAwayEarly(in: modelContext)
            }
            errorText = nil
        } catch {
            errorText = "Could not end away time."
            NSLog("Failed to end away session: \(error.localizedDescription)")
        }
    }
}

private struct AwayModeContent: View {
    let session: AwaySession
    let now: Date
    let errorText: String?
    let onExtend: () -> Void
    let onEnd: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 32)

            VStack(spacing: 10) {
                Image(systemName: session.preset.systemImage)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)

                Text(session.displayTitle)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Routina is holding this window for you.")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.76))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.12), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: session.completionProgress(referenceDate: now))
                        .stroke(.teal, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 5) {
                        Text(AwaySessionFormatting.timerText(seconds: timerSeconds))
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()

                        Text(timerLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.62))
                    }
                }
                .frame(width: 190, height: 190)

                VStack(spacing: 12) {
                    AwayMetricRow(
                        title: "Started",
                        value: timeText(session.startedAt),
                        systemImage: "play.fill"
                    )
                    AwayMetricRow(
                        title: "Ends",
                        value: session.isCountUp ? "Open-ended" : timeText(session.plannedEndAt),
                        systemImage: "flag.checkered"
                    )
                    AwayMetricRow(
                        title: "Protected",
                        value: AwaySessionFormatting.durationText(
                            seconds: session.durationSeconds(referenceDate: now)
                        ),
                        systemImage: "lock.shield.fill"
                    )
                }
                .padding(18)
                .routinaGlassPanel(cornerRadius: 18, tint: .white, tintOpacity: 0.14)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
            }

            Spacer(minLength: 16)

            VStack(spacing: 10) {
                if !session.isCountUp {
                    Button {
                        onExtend()
                    } label: {
                        Label("Extend 5 min", systemImage: "plus.circle.fill")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.teal)
                }

                if session.isCountUp {
                    Button {
                        onEnd()
                    } label: {
                        Label("End away", systemImage: "checkmark.circle.fill")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.teal)
                } else {
                    Button(role: .destructive) {
                        onEnd()
                    } label: {
                        Text("End early")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .buttonStyle(.plain)
                }

                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.95))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var timerSeconds: TimeInterval {
        session.isCountUp
            ? session.durationSeconds(referenceDate: now)
            : session.remainingSeconds(referenceDate: now)
    }

    private var timerLabel: String {
        session.isCountUp ? "elapsed" : "remaining"
    }

    private func timeText(_ date: Date?) -> String {
        guard let date else { return "Unknown" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

private struct AwayMetricRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 28, height: 28)
                .routinaGlassPill(tint: .white, tintOpacity: 0.14)

            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.70))

            Spacer(minLength: 12)

            Text(value)
                .font(.headline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

extension AwaySessionPreset: Identifiable {
    var id: String { rawValue }
}
