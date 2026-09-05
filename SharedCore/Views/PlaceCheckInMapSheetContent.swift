import Foundation
import SwiftUI

struct PlaceCheckInDayTimelineList: View {
    let sections: [PlaceCheckInDaySection]
    let calendar: Calendar
    let canFocusOnSession: (PlaceCheckInSession) -> Bool
    let canSaveSessionAsPlace: (PlaceCheckInSession) -> Bool
    let onFocusSession: (PlaceCheckInSession) -> Void
    let onEditSession: (PlaceCheckInSession) -> Void
    let onDeleteSession: (PlaceCheckInSession) -> Void
    let onSaveSessionAsPlace: (PlaceCheckInSession) -> Void
    let onConfirmAutomaticSession: (PlaceCheckInSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if sections.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(sections) { section in
                            PlaceCheckInDayTimelineSectionView(
                                section: section,
                                calendar: calendar,
                                currentActiveSessionID: currentActiveSessionID,
                                canFocusOnSession: canFocusOnSession,
                                canSaveSessionAsPlace: canSaveSessionAsPlace,
                                onFocusSession: onFocusSession,
                                onEditSession: onEditSession,
                                onDeleteSession: onDeleteSession,
                                onSaveSessionAsPlace: onSaveSessionAsPlace,
                                onConfirmAutomaticSession: onConfirmAutomaticSession
                            )
                        }
                    }
                }
            }
        }
    }

    private var currentActiveSessionID: UUID? {
        PlaceCheckInSupport.currentActiveSessionID(
            in: sections.flatMap(\.sessions)
        )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No check-ins")
                .font(.subheadline.weight(.semibold))
            Text("Your place sessions will appear here grouped by date.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .routinaGlassCard(cornerRadius: 8, tint: .secondary, tintOpacity: 0.08)
    }
}

private struct PlaceCheckInDayTimelineSectionView: View {
    let section: PlaceCheckInDaySection
    let calendar: Calendar
    let currentActiveSessionID: UUID?
    let canFocusOnSession: (PlaceCheckInSession) -> Bool
    let canSaveSessionAsPlace: (PlaceCheckInSession) -> Bool
    let onFocusSession: (PlaceCheckInSession) -> Void
    let onEditSession: (PlaceCheckInSession) -> Void
    let onDeleteSession: (PlaceCheckInSession) -> Void
    let onSaveSessionAsPlace: (PlaceCheckInSession) -> Void
    let onConfirmAutomaticSession: (PlaceCheckInSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(TimelineLogic.daySectionTitle(for: section.date, calendar: calendar))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)

            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(section.sessions) { session in
                    PlaceCheckInDayTimelineRow(
                        session: session,
                        isCurrent: session.id == currentActiveSessionID,
                        canFocus: canFocusOnSession(session),
                        canSaveAsPlace: canSaveSessionAsPlace(session),
                        onFocus: { onFocusSession(session) },
                        onEdit: { onEditSession(session) },
                        onDelete: { onDeleteSession(session) },
                        onSaveAsPlace: { onSaveSessionAsPlace(session) },
                        onConfirm: { onConfirmAutomaticSession(session) }
                    )
                }
            }
        }
    }
}

private struct PlaceCheckInDayTimelineRow: View {
    let session: PlaceCheckInSession
    let isCurrent: Bool
    let canFocus: Bool
    let canSaveAsPlace: Bool
    let onFocus: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSaveAsPlace: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Button {
                    onFocus()
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        timelineMarker
                        content
                        Spacer(minLength: 8)
                        imagePreview

                        Image(systemName: canFocus ? "scope" : "mappin.slash")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .buttonStyle(.plain)
                .disabled(!canFocus)

                PlaceCheckInSessionActionsMenu(
                    showsConfirm: session.requiresConfirmation,
                    showsSaveAsPlace: canSaveAsPlace,
                    onConfirm: onConfirm,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onSaveAsPlace: onSaveAsPlace
                )
            }

            if canSaveAsPlace {
                saveAsPlaceButton
                    .padding(.leading, 28)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinaGlassCard(cornerRadius: 8, tint: .secondary, tintOpacity: 0.07, interactive: true)
        .contextMenu {
            if session.requiresConfirmation {
                Button {
                    onConfirm()
                } label: {
                    Label("Confirm Auto Check-In", systemImage: "checkmark.circle")
                }

                Divider()
            }

            Button {
                onEdit()
            } label: {
                Label("Edit Check-In", systemImage: "pencil")
            }

            if canSaveAsPlace {
                Button {
                    onSaveAsPlace()
                } label: {
                    Label("Save as Place", systemImage: "mappin.and.ellipse")
                }
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Check-In", systemImage: "trash")
            }
        }
        .modifier(
            PlaceCheckInConfirmSwipeModifier(
                showsConfirm: session.requiresConfirmation,
                action: onConfirm
            )
        )
        .accessibilityLabel("Show \(session.displayPlaceName) on map")
    }

    private var timelineMarker: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(isCurrent ? Color.teal : Color.accentColor)
                .frame(width: 10, height: 10)
            Rectangle()
                .fill(Color.secondary.opacity(0.22))
                .frame(width: 2, height: 34)
        }
        .frame(width: 18)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(session.displayPlaceName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if isCurrent {
                    Text("Now")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.teal)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .routinaGlassPill(tint: .teal, tintOpacity: 0.12)
                }

                if session.isAutomatic {
                    let autoTint = session.requiresConfirmation ? Color.orange : Color.secondary
                    Text("Auto")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(autoTint)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .routinaGlassPill(
                            tint: autoTint,
                            tintOpacity: session.requiresConfirmation ? 0.14 : 0.10
                        )
                }
            }

            Text(sessionTimelineSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let activity = session.activity {
                Label(activity.title, systemImage: activity.systemImage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var saveAsPlaceButton: some View {
        Button {
            onSaveAsPlace()
        } label: {
            Label("Save as Place", systemImage: "mappin.and.ellipse")
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let imageData = session.imageData, !imageData.isEmpty {
            PlaceCheckInImagePreview(data: imageData, contentMode: .fill)
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                )
        }
    }

    private var sessionTimelineSubtitle: String {
        guard let start = session.startedAt ?? session.createdAt else {
            return "Time unavailable"
        }

        return start.formatted(date: .omitted, time: .shortened)
    }
}

private struct PlaceCheckInSessionActionsMenu: View {
    let showsConfirm: Bool
    let showsSaveAsPlace: Bool
    let onConfirm: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSaveAsPlace: () -> Void

    var body: some View {
        Menu {
            if showsConfirm {
                Button {
                    onConfirm()
                } label: {
                    Label("Confirm Auto Check-In", systemImage: "checkmark.circle")
                }

                Divider()
            }

            Button {
                onEdit()
            } label: {
                Label("Edit Check-In", systemImage: "pencil")
            }

            if showsSaveAsPlace {
                Button {
                    onSaveAsPlace()
                } label: {
                    Label("Save as Place", systemImage: "mappin.and.ellipse")
                }
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Check-In", systemImage: "trash")
            }
        } label: {
            Label("Check-in actions", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Check-in actions")
        .help("More actions")
    }
}
