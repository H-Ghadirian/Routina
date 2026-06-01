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

struct AwaySessionStartSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedPreset: AwaySessionPreset = .wake
    @State private var durationMinutes = AwaySessionPreset.wake.defaultDurationMinutes
    @State private var hasCustomizedDuration = false
    @State private var errorText: String?
    var onStarted: () -> Void = {}

    var body: some View {
        NavigationStack {
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
                    Stepper(
                        "Duration: \(durationMinutes)m",
                        value: durationMinutesBinding,
                        in: 1...720,
                        step: 5
                    )
                }

                if let errorText {
                    Section {
                        Text(errorText)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Start Away")
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
                    Button("Start") {
                        startAway()
                    }
                    .fontWeight(.semibold)
                }
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
    private func startAway() {
        do {
            _ = try AwaySessionSupport.startAway(
                preset: selectedPreset,
                durationMinutes: durationMinutes,
                context: modelContext
            )
            errorText = nil
            onStarted()
            dismiss()
        } catch {
            errorText = error.localizedDescription
            NSLog("Failed to start away session: \(error.localizedDescription)")
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
                    onEndEarly: endEarly
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
    private func endEarly() {
        do {
            _ = try AwaySessionSupport.endActiveAwayEarly(in: modelContext)
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
    let onEndEarly: () -> Void

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
                        Text(AwaySessionFormatting.timerText(seconds: session.remainingSeconds(referenceDate: now)))
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()

                        Text("remaining")
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
                        value: timeText(session.plannedEndAt),
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

                Button(role: .destructive) {
                    onEndEarly()
                } label: {
                    Text("End early")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .buttonStyle(.plain)

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
