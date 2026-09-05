import SwiftUI

extension FocusSessionCard {
    func focusHeader(
        snapshot: FocusSessionCardSnapshot,
        isContentExpanded: Bool,
        showsDisclosureIndicator: Bool
    ) -> some View {
        HStack(alignment: isEmbedded ? .center : .top, spacing: isEmbedded ? 8 : 12) {
            if !isEmbedded {
                Image(systemName: "timer")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.teal)
                    .frame(width: 30, height: 30)
                    .routinaGlassPill(tint: .teal, tintOpacity: 0.14)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Focus")
                    .font(isEmbedded ? .subheadline.weight(.semibold) : .headline)
                    .foregroundStyle(.primary)

                if !isEmbedded {
                    Text(focusSubtitle(snapshot: snapshot))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let statusText = embeddedFocusStatusText(snapshot: snapshot) {
                    Text(statusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if showsDisclosureIndicator {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isContentExpanded ? 180 : 0))
                    .padding(.top, isEmbedded ? 0 : 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    var startFocusControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    countUpStartButton
                    if !isEmbedded {
                        durationStartButtons
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    countUpStartButton
                    if !isEmbedded {
                        durationStartButtons
                    }
                }
            }

            if !isEmbedded {
                Text(focusTrackingDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var countUpStartButton: some View {
        Button {
            startCountUpSession()
        } label: {
            Label(isEmbedded ? "Count up" : "Start count up", systemImage: "stopwatch")
        }
        .buttonStyle(.borderedProminent)
        .tint(.teal)
        .controlSize(.regular)
    }

    var durationStartButtons: some View {
        HStack(spacing: 8) {
            ForEach(durationOptions.prefix(3), id: \.self) { seconds in
                Button(FocusSessionFormatting.compactDurationText(seconds: seconds)) {
                    startSession(duration: seconds)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }

            Menu {
                ForEach(durationOptions.dropFirst(3), id: \.self) { seconds in
                    Button(FocusSessionFormatting.compactDurationText(seconds: seconds)) {
                        startSession(duration: seconds)
                    }
                }
            } label: {
                Label("More durations", systemImage: "ellipsis.circle")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("More focus durations")
        }
    }

    var focusTrackingDescription: String {
        return "Focus time is tracked separately from completions."
    }

    var sleepModeActiveContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Sleep mode is active", systemImage: "bed.double.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Wake up before starting a focus timer.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func activeSessionContent(_ session: FocusSession, snapshot: FocusSessionCardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
                let isCountUp = session.plannedDurationSeconds <= 0
                let elapsedSeconds = elapsedSeconds(for: session, now: context.date)
                let progress = progress(for: session, now: context.date)
                let displaySeconds =
                    isCountUp
                    ? elapsedSeconds
                    : remainingSeconds(for: session, now: context.date)
                let timerStateLabel =
                    session.isPaused
                    ? "paused"
                    : (isCountUp ? "elapsed" : "remaining")

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .lastTextBaseline) {
                        Text(FocusSessionFormatting.durationText(seconds: displaySeconds))
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .monospacedDigit()
                        Text(timerStateLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                    }

                    if isCountUp {
                        FocusSessionBlockProgressView(elapsedSeconds: elapsedSeconds)
                    } else {
                        ProgressView(value: progress)
                            .tint(.teal)
                    }

                    HStack(spacing: 10) {
                        Button {
                            if session.isPaused {
                                resume(session)
                            } else {
                                pause(session)
                            }
                        } label: {
                            Label(
                                session.isPaused ? "Resume" : "Pause",
                                systemImage: session.isPaused ? "play.circle.fill" : "pause.circle.fill"
                            )
                        }
                        .buttonStyle(.bordered)
                        .tint(.teal)

                        Button {
                            finish(session)
                        } label: {
                            Label("Finish", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)

                        Button(role: .destructive) {
                            abandon(session)
                        } label: {
                            Label("Abandon", systemImage: "xmark.circle")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    func otherTaskActiveContent(_ session: FocusSession) -> some View {
        let taskName =
            session.focusTagTitle
            ?? (session.isUnassigned
                ? "unassigned focus"
                : allTasks.first { $0.id == session.taskID }?.name ?? "another task")

        return VStack(alignment: .leading, spacing: 10) {
            Label("Focusing on \(taskName)", systemImage: "timer")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Finish or abandon that session before starting a task focus session.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func blockingFocusContent(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Focusing on \(title)", systemImage: "timer")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Stop that focus timer before starting a task focus session.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func progress(for session: FocusSession, now: Date) -> Double {
        let elapsed = session.activeDurationSeconds(at: now)
        guard session.plannedDurationSeconds > 0 else { return 1 }
        return min(1, elapsed / session.plannedDurationSeconds)
    }

    func elapsedSeconds(for session: FocusSession, now: Date) -> TimeInterval {
        session.activeDurationSeconds(at: now)
    }

    func remainingSeconds(for session: FocusSession, now: Date) -> TimeInterval {
        let elapsed = session.activeDurationSeconds(at: now)
        return max(0, session.plannedDurationSeconds - elapsed)
    }

}
