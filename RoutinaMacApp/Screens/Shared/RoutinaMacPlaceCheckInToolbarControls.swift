import SwiftData
import SwiftUI

struct RoutinaMacPlaceCheckInToolbarItem: ToolbarContent {
    let onMapRequested: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            RoutinaMacPlaceCheckInToolbarButton(onMapRequested: onMapRequested)
        }
    }
}

private struct RoutinaMacPlaceCheckInToolbarButton: View {
    let onMapRequested: () -> Void

    @Query(sort: \PlaceCheckInSession.startedAt, order: .reverse) private var sessions: [PlaceCheckInSession]

    var body: some View {
        SwiftUI.TimelineView(.periodic(from: .now, by: 60)) { timeline in
            Button {
                onMapRequested()
            } label: {
                toolbarLabel
            }
            .buttonStyle(.plain)
            .controlSize(.small)
            .help(helpText(now: timeline.date))
            .accessibilityLabel(accessibilityLabel(now: timeline.date))
            .padding(.trailing, 8)
        }
    }

    private var activeSession: PlaceCheckInSession? {
        sessions.first { $0.endedAt == nil }
    }

    private var labelSystemImage: String {
        activeSession == nil ? "mappin.and.ellipse" : "location.fill"
    }

    private var toolbarLabel: some View {
        HStack(spacing: 7) {
            Image(systemName: labelSystemImage)
                .font(.caption.weight(.semibold))
                .symbolRenderingMode(.hierarchical)

            Text(labelTitle)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: labelMaxWidth, alignment: .leading)
        }
        .foregroundStyle(toolbarForegroundStyle)
        .padding(.horizontal, 12)
        .frame(height: 28)
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

    private func helpText(now: Date) -> String {
        if let activeSession {
            return "Open Places, \(activeStatusText(for: activeSession, now: now))"
        }
        return "Open Places"
    }

    private func accessibilityLabel(now: Date) -> String {
        if let activeSession {
            return "Open Places, current check-in: \(activeStatusText(for: activeSession, now: now))"
        }
        return "Open Places"
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
}
