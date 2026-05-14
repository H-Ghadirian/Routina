import SwiftData
import SwiftUI

struct RoutinaMacPlaceCheckInToolbarItem: ToolbarContent {
    let onMapRequested: (PlaceCheckInActivity?) -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            RoutinaMacPlaceCheckInToolbarButton(onMapRequested: onMapRequested)
        }
    }
}

private struct RoutinaMacPlaceCheckInToolbarButton: View {
    let onMapRequested: (PlaceCheckInActivity?) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RoutinePlace.name) private var places: [RoutinePlace]
    @Query(sort: \PlaceCheckInSession.startedAt, order: .reverse) private var sessions: [PlaceCheckInSession]
    @State private var selectedActivity: PlaceCheckInActivity?
    @State private var errorText: String?

    var body: some View {
        SwiftUI.TimelineView(.periodic(from: .now, by: 60)) { timeline in
            Menu {
                statusContent(now: timeline.date)

                Divider()

                Button {
                    onMapRequested(selectedActivity)
                } label: {
                    Label("Open Places", systemImage: "map")
                }

                activityMenuContent

                if !suggestedPlaces.isEmpty {
                    Divider()

                    Section("Check in") {
                        ForEach(suggestedPlaces) { place in
                            Button {
                                checkIn(at: place)
                            } label: {
                                Label(place.displayName, systemImage: placeSystemImage(for: place))
                            }
                        }
                    }
                }

                if activeSession != nil {
                    Divider()

                    Button(role: .destructive) {
                        endActiveSession()
                    } label: {
                        Label("End Check-In", systemImage: "stop.circle")
                    }
                }

                if let errorText {
                    Divider()
                    Text(errorText)
                }
            } label: {
                toolbarLabel
            }
            .menuStyle(.button)
            .controlSize(.small)
            .tint(.teal)
            .help(helpText(now: timeline.date))
            .accessibilityLabel(accessibilityLabel(now: timeline.date))
        }
    }

    private var activeSession: PlaceCheckInSession? {
        sessions.first { $0.endedAt == nil }
    }

    private var suggestedPlaces: [RoutinePlace] {
        PlaceCheckInSupport.suggestedPlaces(
            places: places,
            sessions: sessions,
            limit: 5
        )
    }

    @ViewBuilder
    private func statusContent(now: Date) -> some View {
        if let activeSession {
            Text(activeStatusText(for: activeSession, now: now))
        } else if let selectedActivity {
            Text("Next: \(selectedActivity.title)")
        } else {
            Text("Check in")
        }
    }

    @ViewBuilder
    private var activityMenuContent: some View {
        Menu {
            Button {
                updateActivity(nil)
            } label: {
                Label("No Activity", systemImage: selectedActivity == nil ? "checkmark" : "tag")
            }

            ForEach(PlaceCheckInActivity.allCases) { activity in
                Button {
                    updateActivity(activity)
                } label: {
                    Label(activity.title, systemImage: activity.systemImage)
                }
            }
        } label: {
            Label(activityMenuTitle, systemImage: selectedActivity?.systemImage ?? "tag")
        }
    }

    private var labelSystemImage: String {
        activeSession == nil ? "mappin.and.ellipse" : "location.fill"
    }

    private var toolbarLabel: some View {
        HStack(spacing: 7) {
            Image(systemName: labelSystemImage)
                .font(.system(size: 16, weight: .semibold))
                .symbolRenderingMode(.hierarchical)

            Text(labelTitle)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: labelMaxWidth, alignment: .leading)
        }
        .foregroundStyle(toolbarForegroundStyle)
        .padding(.horizontal, 12)
        .frame(minWidth: activeSession == nil ? 98 : 132, minHeight: 34)
        .background(
            Capsule(style: .continuous)
                .fill(Color.teal.opacity(activeSession == nil ? 0.12 : 0.18))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.teal.opacity(activeSession == nil ? 0.24 : 0.38), lineWidth: 1)
        )
        .fixedSize(horizontal: true, vertical: false)
    }

    private var toolbarForegroundStyle: Color {
        activeSession == nil ? .primary : .teal
    }

    private var labelMaxWidth: CGFloat? {
        activeSession == nil ? nil : 160
    }

    private var labelTitle: String {
        if let activeSession {
            return activeSession.displayPlaceName
        }
        return "Check In"
    }

    private var activityMenuTitle: String {
        selectedActivity?.title ?? "Activity"
    }

    private func helpText(now: Date) -> String {
        if let activeSession {
            return activeStatusText(for: activeSession, now: now)
        }
        return "Start a place check-in"
    }

    private func accessibilityLabel(now: Date) -> String {
        if let activeSession {
            return "Place check-in, \(activeStatusText(for: activeSession, now: now))"
        }
        return "Place check-in"
    }

    private func activeStatusText(for session: PlaceCheckInSession, now: Date) -> String {
        let duration = PlaceCheckInFormatting.durationText(
            seconds: session.durationSeconds(referenceDate: now)
        )

        if let activity = session.activity {
            return "\(session.displayPlaceName), \(duration) here, \(activity.title)"
        }
        return "\(session.displayPlaceName), \(duration) here"
    }

    private func placeSystemImage(for place: RoutinePlace) -> String {
        activeSession?.placeID == place.id ? "location.fill" : "mappin"
    }

    @MainActor
    private func checkIn(at place: RoutinePlace) {
        do {
            _ = try PlaceCheckInSupport.checkIn(
                at: place,
                activity: selectedActivity,
                in: modelContext
            )
            errorText = nil
        } catch {
            errorText = "Could not check in."
            NSLog("Failed to check in at place from toolbar: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func endActiveSession() {
        do {
            _ = try PlaceCheckInSupport.endActiveSession(in: modelContext)
            errorText = nil
        } catch {
            errorText = "Could not end check-in."
            NSLog("Failed to end place check-in from toolbar: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func updateActivity(_ activity: PlaceCheckInActivity?) {
        selectedActivity = activity
        guard activeSession != nil else { return }

        do {
            try PlaceCheckInSupport.updateActiveActivity(activity, in: modelContext)
            errorText = nil
        } catch {
            errorText = "Could not update activity."
            NSLog("Failed to update place check-in activity from toolbar: \(error.localizedDescription)")
        }
    }
}
