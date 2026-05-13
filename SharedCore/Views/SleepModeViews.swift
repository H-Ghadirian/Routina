import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#endif

extension View {
    func sleepModeGate() -> some View {
        modifier(SleepModeRootModifier())
    }
}

struct SleepHomeDockView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var activeSleepSessions: [SleepSession]
    @AppStorage(
        UserDefaultBoolValueKey.appSettingSleepHomeDockEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isSleepHomeDockEnabled = true
    @State private var errorText: String?
    @State private var focusStopWarningMessage: String?

    init() {
        _activeSleepSessions = Query(
            filter: #Predicate<SleepSession> { session in
                session.endedAt == nil
            },
            sort: \.startedAt,
            order: .reverse
        )
    }

    var body: some View {
        if isSleepHomeDockEnabled, activeSleepSession == nil {
            VStack(alignment: .leading, spacing: 5) {
                Button {
                    requestStartSleep()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bed.double.fill")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.indigo)
                            .frame(width: 32, height: 32)
                            .routinaGlassPill(tint: .indigo, tintOpacity: 0.16)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Going to sleep")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)

                            Text("Start sleep mode")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 10)

                        Image(systemName: "arrow.right")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 32)
                            .routinaGlassPill(tint: .indigo, tintOpacity: 0.72, interactive: true)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .routinaGlassPill(tint: .indigo, tintOpacity: 0.10, interactive: true)
                    .overlay(
                        Capsule()
                            .stroke(.primary.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Going to sleep")

                if let errorText {
                    Text(errorText)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .shadow(color: .black.opacity(0.12), radius: 14, y: 7)
            .accessibilityElement(children: .contain)
            .alert("Stop focus timer?", isPresented: focusStopWarningPresented) {
                Button("Start Sleep", role: .destructive) {
                    startSleep()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(focusStopWarningMessage ?? "Starting sleep mode will stop the current focus timer.")
            }
        }
    }

    private var activeSleepSession: SleepSession? {
        activeSleepSessions.first
    }

    @MainActor
    private func requestStartSleep() {
        do {
            if let warningMessage = try SleepSessionSupport.activeFocusTimerWarningMessage(in: modelContext) {
                focusStopWarningMessage = warningMessage
                return
            }

            startSleep()
        } catch {
            errorText = "Could not start sleep mode."
            NSLog("Failed to check active focus before starting sleep: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func startSleep() {
        do {
            _ = try SleepSessionSupport.startSleep(in: modelContext)
            errorText = nil
            focusStopWarningMessage = nil
        } catch {
            errorText = "Could not start sleep mode."
            NSLog("Failed to start sleep session: \(error.localizedDescription)")
        }
    }

    private var focusStopWarningPresented: Binding<Bool> {
        Binding(
            get: { focusStopWarningMessage != nil },
            set: { isPresented in
                if !isPresented {
                    focusStopWarningMessage = nil
                }
            }
        )
    }
}

private struct SleepModeRootModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Query private var activeSleepSessions: [SleepSession]
    @AppStorage(
        UserDefaultBoolValueKey.appSettingShakeToStartSleepEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isShakeToStartSleepEnabled = true
    @State private var isShakeConfirmationPresented = false
    @State private var focusStopWarningMessage: String?

    init() {
        _activeSleepSessions = Query(
            filter: #Predicate<SleepSession> { session in
                session.endedAt == nil
            },
            sort: \.startedAt,
            order: .reverse
        )
    }

    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(activeSleepSession != nil)

            if let activeSleepSession {
                SleepModeFullScreenView(session: activeSleepSession)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: activeSleepSession?.id)
        #if os(iOS)
        .background {
            if isShakeToStartSleepEnabled, activeSleepSession == nil {
                SleepShakeStartBridge {
                    prepareSleepConfirmation()
                }
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
            }
        }
        .alert(sleepConfirmationTitle, isPresented: $isShakeConfirmationPresented) {
            Button("Start Sleep", role: focusStopWarningMessage == nil ? nil : .destructive) {
                startSleep()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(sleepConfirmationMessage)
        }
        #endif
    }

    private var activeSleepSession: SleepSession? {
        activeSleepSessions.first
    }

    @MainActor
    private func prepareSleepConfirmation() {
        do {
            focusStopWarningMessage = try SleepSessionSupport.activeFocusTimerWarningMessage(in: modelContext)
        } catch {
            focusStopWarningMessage = nil
            NSLog("Failed to check active focus before shake sleep confirmation: \(error.localizedDescription)")
        }
        isShakeConfirmationPresented = true
    }

    @MainActor
    private func startSleep() {
        do {
            _ = try SleepSessionSupport.startSleep(in: modelContext)
            focusStopWarningMessage = nil
        } catch {
            NSLog("Failed to start sleep session from shake: \(error.localizedDescription)")
        }
    }

    private var sleepConfirmationTitle: String {
        focusStopWarningMessage == nil ? "Start sleep mode?" : "Stop focus timer?"
    }

    private var sleepConfirmationMessage: String {
        focusStopWarningMessage ?? "Shake can start sleep mode when Routina is open."
    }
}

private struct SleepModeFullScreenView: View {
    @Environment(\.modelContext) private var modelContext
    let session: SleepSession
    @State private var errorText: String?

    var body: some View {
        ZStack {
            sleepBackground

            SwiftUI.TimelineView(.periodic(from: .now, by: 60)) { timeline in
                VStack(spacing: 28) {
                    Spacer(minLength: 32)

                    VStack(spacing: 10) {
                        Image(systemName: "bed.double.fill")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(.white)
                            .symbolRenderingMode(.hierarchical)

                        Text("Rest well")
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)

                        Text("Routina is staying quiet while you sleep.")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.76))
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 12) {
                        SleepMetricRow(
                            title: "Started",
                            value: timeText(session.startedAt),
                            systemImage: "bed.double.fill"
                        )

                        SleepMetricRow(
                            title: "Estimated wake",
                            value: timeText(session.targetWakeAt),
                            systemImage: "alarm.fill"
                        )

                        SleepMetricRow(
                            title: "Asleep for",
                            value: SleepSessionFormatting.durationText(
                                seconds: session.durationSeconds(referenceDate: timeline.date)
                            ),
                            systemImage: "clock.fill"
                        )
                    }
                    .padding(18)
                    .routinaGlassPanel(cornerRadius: 18, tint: .white, tintOpacity: 0.14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )

                    Spacer(minLength: 16)

                    VStack(spacing: 10) {
                        Button {
                            endSleep()
                        } label: {
                            Label("I'm awake", systemImage: "checkmark.circle.fill")
                                .font(.headline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.orange)

                        Button(role: .destructive) {
                            undoSleep()
                        } label: {
                            Text("Undo sleep mode")
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
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
    }

    private var sleepBackground: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.07, green: 0.09, blue: 0.16),
                Color(red: 0.03, green: 0.13, blue: 0.14)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func timeText(_ date: Date?) -> String {
        guard let date else { return "Unknown" }
        return date.formatted(date: .omitted, time: .shortened)
    }

    @MainActor
    private func endSleep() {
        do {
            _ = try SleepSessionSupport.endActiveSleep(in: modelContext)
            errorText = nil
        } catch {
            errorText = "Could not save wake time."
            NSLog("Failed to end sleep session: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func undoSleep() {
        do {
            try SleepSessionSupport.delete(session, in: modelContext)
            errorText = nil
        } catch {
            errorText = "Could not undo sleep mode."
            NSLog("Failed to undo sleep session: \(error.localizedDescription)")
        }
    }
}

private struct SleepMetricRow: View {
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

#if os(iOS)
private struct SleepShakeStartBridge: UIViewControllerRepresentable {
    var onShake: () -> Void

    func makeUIViewController(context: Context) -> Controller {
        let controller = Controller()
        controller.onShake = onShake
        return controller
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.onShake = onShake
    }

    final class Controller: UIViewController {
        var onShake: () -> Void = {}

        override var canBecomeFirstResponder: Bool {
            true
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            becomeFirstResponder()
        }

        override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            guard motion == .motionShake else { return }
            onShake()
        }
    }
}
#endif
