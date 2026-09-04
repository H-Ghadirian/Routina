import SwiftData
import SwiftUI

struct AwaySessionEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [RoutineTask]
    let session: AwaySession
    @State private var selectedPreset: AwaySessionPreset
    @State private var title: String
    @State private var linkedTaskID: UUID?
    @State private var timerMode: AwaySessionTimerMode
    @State private var durationMinutes: Int
    @State private var startedAt: Date
    @State private var finishedAt: Date
    @State private var errorText: String?

    init(session: AwaySession) {
        self.session = session
        _selectedPreset = State(initialValue: session.preset)
        _title = State(initialValue: session.displayTitle)
        _linkedTaskID = State(initialValue: session.linkedTaskID)
        _timerMode = State(initialValue: session.isCountUp ? .countUp : .fixedDuration)
        _durationMinutes = State(initialValue: max(1, Int((session.plannedDurationSeconds / 60).rounded())))
        _startedAt = State(initialValue: session.startedAt ?? Date())
        _finishedAt = State(initialValue: session.finishedAt ?? session.plannedEndAt ?? Date())
    }

    var body: some View {
        NavigationStack {
            editContent
                .navigationTitle(session.isActive ? "Edit Away" : "Edit Away Session")
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            save()
                        }
                        .fontWeight(.semibold)
                    }
                }
        }
    }

    private var editContent: some View {
        ZStack {
            LinearGradient(
                colors: [
                    selectedPreset.tint.opacity(0.18),
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
                        option: .away(selectedPreset),
                        timerMode: timerMode,
                        durationMinutes: durationMinutes,
                        titleOverride: displayTitle,
                        subtitleOverride: session.isActive ? "Adjust this running away session." : "Adjust this protected away window."
                    )

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 16) {
                                AwayEditDetailsPanel(
                                    title: $title,
                                    startedAt: $startedAt,
                                    finishedAt: $finishedAt,
                                    isActive: session.isActive,
                                    tint: selectedPreset.tint
                                )

                                AwayPresetPickerPanel(
                                    selectedPreset: $selectedPreset,
                                    selectedTint: selectedPreset.tint
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .top)

                            VStack(spacing: 16) {
                                AwayTimerSetupPanel(
                                    timerMode: $timerMode,
                                    durationMinutes: $durationMinutes,
                                    tint: selectedPreset.tint
                                )

                                AwayTaskLinkPanel(
                                    linkedTaskID: $linkedTaskID,
                                    tasks: sortedTasks,
                                    tint: selectedPreset.tint
                                )

                                AwayEditSummaryPanel(
                                    preset: selectedPreset,
                                    timerMode: timerMode,
                                    durationMinutes: durationMinutes,
                                    startedAt: startedAt,
                                    finishedAt: session.isActive ? nil : finishedAt,
                                    errorText: errorText,
                                    onSave: save
                                )
                            }
                            .frame(width: 330)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            AwayEditDetailsPanel(
                                title: $title,
                                startedAt: $startedAt,
                                finishedAt: $finishedAt,
                                isActive: session.isActive,
                                tint: selectedPreset.tint
                            )

                            AwayPresetPickerPanel(
                                selectedPreset: $selectedPreset,
                                selectedTint: selectedPreset.tint
                            )

                            AwayTimerSetupPanel(
                                timerMode: $timerMode,
                                durationMinutes: $durationMinutes,
                                tint: selectedPreset.tint
                            )

                            AwayTaskLinkPanel(
                                linkedTaskID: $linkedTaskID,
                                tasks: sortedTasks,
                                tint: selectedPreset.tint
                            )

                            AwayEditSummaryPanel(
                                preset: selectedPreset,
                                timerMode: timerMode,
                                durationMinutes: durationMinutes,
                                startedAt: startedAt,
                                finishedAt: session.isActive ? nil : finishedAt,
                                errorText: errorText,
                                onSave: save
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

    private var sortedTasks: [RoutineTask] {
        AwayTaskLinkPresentation.sortedTasks(tasks)
    }

    private var displayTitle: String {
        AwaySession.cleanedDisplayTitle(title, fallback: selectedPreset.title)
    }

    @MainActor
    private func save() {
        do {
            _ = try AwaySessionSupport.update(
                session,
                preset: selectedPreset,
                title: title,
                linkedTaskID: linkedTaskID,
                startedAt: startedAt,
                plannedDurationSeconds: timerMode == .fixedDuration ? TimeInterval(durationMinutes * 60) : 0,
                finishedAt: session.isActive ? nil : finishedAt,
                in: modelContext
            )
            errorText = nil
            dismiss()
        } catch {
            errorText = error.localizedDescription
            NSLog("Failed to edit away session: \(error.localizedDescription)")
        }
    }
}

enum AwayTaskLinkPresentation {
    static func sortedTasks(_ tasks: [RoutineTask]) -> [RoutineTask] {
        tasks.sorted { lhs, rhs in
            displayName(for: lhs).localizedCaseInsensitiveCompare(displayName(for: rhs)) == .orderedAscending
        }
    }

    static func displayName(for task: RoutineTask) -> String {
        let trimmedName = task.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedName.isEmpty ? "Untitled Task" : trimmedName
    }
}

struct AwayTaskLinkFormSection: View {
    @Binding var linkedTaskID: UUID?
    let tasks: [RoutineTask]

    var body: some View {
        Section("Task") {
            Picker("Linked task", selection: $linkedTaskID) {
                Text("No linked task")
                    .tag(Optional<UUID>.none)
                ForEach(tasks) { task in
                    Text(AwayTaskLinkPresentation.displayName(for: task))
                        .tag(Optional(task.id))
                }
            }
        }
    }
}

struct AwayTaskLinkPanel: View {
    @Binding var linkedTaskID: UUID?
    let tasks: [RoutineTask]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Task", systemImage: "checklist")
                .font(.headline)

            Picker("Linked task", selection: $linkedTaskID) {
                Text("No linked task")
                    .tag(Optional<UUID>.none)
                ForEach(tasks) { task in
                    Text(AwayTaskLinkPresentation.displayName(for: task))
                        .tag(Optional(task.id))
                }
            }
            .pickerStyle(.menu)

            if let linkedTask = tasks.first(where: { $0.id == linkedTaskID }) {
                AwayStartSummaryRow(
                    title: "Linked",
                    value: AwayTaskLinkPresentation.displayName(for: linkedTask),
                    systemImage: "link",
                    tint: tint
                )
            }
        }
        .padding(16)
        .routinaGlassPanel(cornerRadius: 16, tint: tint, tintOpacity: 0.06)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct AwayEditDetailsPanel: View {
    @Binding var title: String
    @Binding var startedAt: Date
    @Binding var finishedAt: Date
    let isActive: Bool
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Details", systemImage: "slider.horizontal.3")
                .font(.headline)

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            VStack(spacing: 10) {
                DatePicker("Started", selection: $startedAt)

                if !isActive {
                    DatePicker("Ended", selection: $finishedAt)
                }
            }
            .font(.subheadline)
        }
        .padding(16)
        .routinaGlassPanel(cornerRadius: 16, tint: tint, tintOpacity: 0.06)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct AwayEditSummaryPanel: View {
    let preset: AwaySessionPreset
    let timerMode: AwaySessionTimerMode
    let durationMinutes: Int
    let startedAt: Date
    let finishedAt: Date?
    let errorText: String?
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Ready", systemImage: "checkmark.circle.fill")
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
                    title: "Started",
                    value: timeText(startedAt),
                    systemImage: "play.fill",
                    tint: preset.tint
                )

                if let finishedAt {
                    AwayStartSummaryRow(
                        title: "Ended",
                        value: timeText(finishedAt),
                        systemImage: "flag.checkered",
                        tint: preset.tint
                    )
                }
            }

            Button {
                onSave()
            } label: {
                Label("Save Away", systemImage: "checkmark.circle.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(preset.actionForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(preset.actionTint, in: Capsule())
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
        .routinaGlassPanel(cornerRadius: 16, tint: preset.tint, tintOpacity: 0.08)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(preset.tint.opacity(0.18), lineWidth: 1)
        }
    }

    private var timerText: String {
        timerMode == .fixedDuration ? "\(durationMinutes)m duration" : "Count up"
    }

    private func timeText(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
