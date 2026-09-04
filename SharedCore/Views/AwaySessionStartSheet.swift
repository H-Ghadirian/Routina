import SwiftData
import SwiftUI

struct AwaySessionStartSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [RoutineTask]
    @State private var selectedOption: AwayStartPresetOption = .away(.wake)
    @State private var linkedTaskID: UUID?
    @State private var timerMode: AwaySessionTimerMode = .fixedDuration
    @State private var durationMinutes = AwaySessionPreset.wake.defaultDurationMinutes
    @State private var hasCustomizedDuration = false
    @State private var errorText: String?
    var presentation: AwaySessionStartPresentation = .sheet
    var onCancel: () -> Void = {}
    var onStarted: () -> Void = {}
    var onStartSleep: (() -> Void)?
    var dismissOnCompletion = true

    var body: some View {
        NavigationStack {
            startContent
                .navigationTitle(startTitle)
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
                            startSelectedOption()
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
                Picker("Preset", selection: selectedOptionBinding) {
                    ForEach(startPresetOptions) { option in
                        Label(option.title, systemImage: option.systemImage)
                            .tag(option)
                    }
                }
                .pickerStyle(.inline)
            }

            if !selectedOption.isSleep {
                Section("Timer") {
                    RoutinaGlassSegmentedControl(
                        accessibilityLabel: "Timer",
                        options: AwaySessionTimerMode.allCases,
                        selection: $timerMode,
                        fillsAvailableWidth: true
                    ) { mode in
                        Text(mode.title)
                    }

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

                AwayTaskLinkFormSection(
                    linkedTaskID: $linkedTaskID,
                    tasks: sortedTasks
                )
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
                    selectedOption.tint.opacity(0.18),
                    Color.secondary.opacity(0.04),
                    Color.clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AwayStartHeroCard(
                        option: selectedOption,
                        timerMode: timerMode,
                        durationMinutes: durationMinutes
                    )

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            AwayStartPresetPickerPanel(
                                selectedOption: selectedOptionBinding,
                                options: startPresetOptions,
                                selectedTint: selectedOption.tint
                            )
                            .frame(maxWidth: .infinity, alignment: .top)

                            VStack(spacing: 16) {
                                if !selectedOption.isSleep {
                                    AwayTimerSetupPanel(
                                        timerMode: $timerMode,
                                        durationMinutes: durationMinutesBinding,
                                        tint: selectedOption.tint
                                    )

                                    AwayTaskLinkPanel(
                                        linkedTaskID: $linkedTaskID,
                                        tasks: sortedTasks,
                                        tint: selectedOption.tint
                                    )
                                }

                                AwayStartSummaryPanel(
                                    option: selectedOption,
                                    timerMode: timerMode,
                                    durationMinutes: durationMinutes,
                                    errorText: errorText,
                                    onStart: startSelectedOption
                                )
                            }
                            .frame(width: 330)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            AwayStartPresetPickerPanel(
                                selectedOption: selectedOptionBinding,
                                options: startPresetOptions,
                                selectedTint: selectedOption.tint
                            )

                            if !selectedOption.isSleep {
                                AwayTimerSetupPanel(
                                    timerMode: $timerMode,
                                    durationMinutes: durationMinutesBinding,
                                    tint: selectedOption.tint
                                )

                                AwayTaskLinkPanel(
                                    linkedTaskID: $linkedTaskID,
                                    tasks: sortedTasks,
                                    tint: selectedOption.tint
                                )
                            }

                            AwayStartSummaryPanel(
                                option: selectedOption,
                                timerMode: timerMode,
                                durationMinutes: durationMinutes,
                                errorText: errorText,
                                onStart: startSelectedOption
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

    private var startPresetOptions: [AwayStartPresetOption] {
        AwayStartPresetOption.options(includesSleep: onStartSleep != nil)
    }

    private var sortedTasks: [RoutineTask] {
        AwayTaskLinkPresentation.sortedTasks(tasks)
    }

    private var startTitle: String {
        selectedOption.isSleep ? "Start Sleep" : "Start Away"
    }

    private var selectedOptionBinding: Binding<AwayStartPresetOption> {
        Binding(
            get: { selectedOption },
            set: { option in
                selectedOption = option
                if !hasCustomizedDuration, let preset = option.awayPreset {
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
    private func startSelectedOption() {
        switch selectedOption {
        case .away:
            startAway()
        case .sleep:
            startSleep()
        }
    }

    @MainActor
    private func startAway() {
        guard let selectedPreset = selectedOption.awayPreset else {
            startSleep()
            return
        }
        do {
            _ = try AwaySessionSupport.startAway(
                preset: selectedPreset,
                durationMinutes: timerMode == .fixedDuration ? durationMinutes : nil,
                countsUp: timerMode == .countUp,
                linkedTaskID: linkedTaskID,
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

    @MainActor
    private func startSleep() {
        guard let onStartSleep else {
            errorText = "Sleep is unavailable from here."
            return
        }
        errorText = nil
        onStartSleep()
        if dismissOnCompletion {
            dismiss()
        }
    }
}
