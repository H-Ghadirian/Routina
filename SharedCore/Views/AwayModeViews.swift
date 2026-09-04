import SwiftData
import SwiftUI

extension View {
    func awayModeGate() -> some View {
        modifier(AwayModeRootModifier())
    }

    func awaySessionEditorSheet(session: Binding<AwaySession?>) -> some View {
        modifier(AwaySessionEditorSheetModifier(editingSession: session))
    }
}

private struct AwaySessionEditorSheetModifier: ViewModifier {
    @Binding var editingSession: AwaySession?
    @AppStorage(
        UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isAwayEnabled = false

    func body(content: Content) -> some View {
        content.sheet(isPresented: isPresented) {
            if isAwayEnabled, let editingSession {
                AwaySessionEditSheet(session: editingSession)
                    .id(editingSession.id)
            }
        }
    }

    private var isPresented: Binding<Bool> {
        Binding(
            get: { isAwayEnabled && editingSession != nil },
            set: { isPresented in
                if !isPresented {
                    editingSession = nil
                }
            }
        )
    }
}

private struct AwayModeRootModifier: ViewModifier {
    @Query private var activeAwaySessions: [AwaySession]
    @AppStorage(
        UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isAwayEnabled = false

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
                .disabled(visibleActiveAwaySession != nil)

            if let activeAwaySession = visibleActiveAwaySession {
                AwayModeFullScreenView(session: activeAwaySession)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: visibleActiveAwaySession?.id)
        #if os(macOS)
            .toolbarVisibility(visibleActiveAwaySession == nil ? .automatic : .hidden, for: .windowToolbar)
        #endif
    }

    private var visibleActiveAwaySession: AwaySession? {
        guard isAwayEnabled else { return nil }
        return activeAwaySession
    }

    private var activeAwaySession: AwaySession? {
        activeAwaySessions.first
    }
}

private struct AwayModeFullScreenView: View {
    @Environment(\.modelContext) private var modelContext
    let session: AwaySession
    @State private var errorText: String?
    @State private var isEditing = false

    var body: some View {
        ZStack {
            awayBackground

            SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { timeline in
                AwayModeContent(
                    session: session,
                    now: timeline.date,
                    errorText: errorText,
                    onEdit: { isEditing = true },
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
        .sheet(isPresented: $isEditing) {
            AwaySessionEditSheet(session: session)
                .id(session.id)
        }
        .accessibilityElement(children: .contain)
    }

    private var awayBackground: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.04, green: 0.12, blue: 0.12),
                Color(red: 0.09, green: 0.10, blue: 0.15),
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
    let onEdit: () -> Void
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
                Button {
                    onEdit()
                } label: {
                    Label("Edit away", systemImage: "slider.horizontal.3")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.white)

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
