import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct PlaceCheckInDockView: View {
    var maximumPlaceButtons = 4
    var onMapRequested: ((PlaceCheckInActivity?) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RoutinePlace.name) private var places: [RoutinePlace]
    @Query(sort: \PlaceCheckInSession.startedAt, order: .reverse) private var sessions: [PlaceCheckInSession]
    @State private var selectedActivity: PlaceCheckInActivity?
    @State private var isMapSheetPresented = false
    @State private var errorText: String?

    var body: some View {
        if shouldShowDock {
            SwiftUI.TimelineView(.periodic(from: .now, by: 60)) { timeline in
                dockContent(now: timeline.date)
            }
        }
    }

    private var shouldShowDock: Bool {
        true
    }

    private var activeSession: PlaceCheckInSession? {
        sessions.first { $0.endedAt == nil }
    }

    private var suggestedPlaces: [RoutinePlace] {
        PlaceCheckInSupport.suggestedPlaces(
            places: places,
            sessions: sessions,
            limit: maximumPlaceButtons
        )
    }

    private func dockContent(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Image(systemName: activeSession == nil ? "mappin.and.ellipse" : "location.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.teal)
                    .frame(width: 32, height: 32)
                    .routinaGlassPill(tint: .teal, tintOpacity: 0.16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(titleText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(subtitleText(now: now))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 8)

                Button {
                    presentMap()
                } label: {
                    Image(systemName: "map")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 30, height: 28)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Map check-in")

                activityMenu

                if activeSession != nil {
                    Button("End") {
                        endActiveSession()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if !suggestedPlaces.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestedPlaces) { place in
                            Button {
                                checkIn(at: place)
                            } label: {
                                Label(place.displayName, systemImage: placeButtonSystemImage(for: place))
                                    .lineLimit(1)
                                    .labelStyle(.titleAndIcon)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(isActivePlace(place) ? .teal : nil)
                            .accessibilityLabel("Check in at \(place.displayName)")
                        }
                    }
                    .padding(.vertical, 1)
                }
            }

            if let errorText {
                Text(errorText)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .routinaGlassPanel(cornerRadius: 8, tint: .teal, tintOpacity: 0.08, interactive: true)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 12, y: 6)
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $isMapSheetPresented) {
            PlaceCheckInMapSheet(selectedActivity: selectedActivity)
        }
    }

    private var activityMenu: some View {
        Menu {
            Button("No Activity") {
                updateActivity(nil)
            }

            ForEach(PlaceCheckInActivity.allCases) { activity in
                Button {
                    updateActivity(activity)
                } label: {
                    Label(activity.title, systemImage: activity.systemImage)
                }
            }
        } label: {
            Image(systemName: "tag")
                .font(.subheadline.weight(.semibold))
                .frame(width: 30, height: 28)
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel("Place activity")
    }

    private var titleText: String {
        if let activeSession {
            return activeSession.displayPlaceName
        }
        return "Check in"
    }

    private func subtitleText(now: Date) -> String {
        if let activeSession {
            let duration = PlaceCheckInFormatting.durationText(
                seconds: activeSession.durationSeconds(referenceDate: now)
            )
            if let activity = activeSession.activity {
                return "\(duration) here · \(activity.title)"
            }
            return "\(duration) here"
        }

        if let selectedActivity {
            return "Next check-in tagged \(selectedActivity.title)"
        }
        return "Record where you are now"
    }

    private func placeButtonSystemImage(for place: RoutinePlace) -> String {
        isActivePlace(place) ? "location.fill" : "mappin"
    }

    private func isActivePlace(_ place: RoutinePlace) -> Bool {
        activeSession?.placeID == place.id
    }

    @MainActor
    private func presentMap() {
        if let onMapRequested {
            onMapRequested(selectedActivity)
        } else {
            isMapSheetPresented = true
        }
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
            signalSuccess()
        } catch {
            errorText = "Could not check in."
            NSLog("Failed to check in at place: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func endActiveSession() {
        do {
            _ = try PlaceCheckInSupport.endActiveSession(in: modelContext)
            errorText = nil
            signalSuccess()
        } catch {
            errorText = "Could not end check-in."
            NSLog("Failed to end place check-in: \(error.localizedDescription)")
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
            NSLog("Failed to update place check-in activity: \(error.localizedDescription)")
        }
    }

    private func signalSuccess() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
