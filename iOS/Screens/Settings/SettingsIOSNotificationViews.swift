import ComposableArchitecture
import Foundation
import SwiftUI

struct SettingsNotificationsDetailView: View {
    let store: StoreOf<SettingsFeature>
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacEventEmotionActionsEnabled.rawValue,
        store: SharedDefaults.app
    ) private var areEventEmotionActionsEnabled = false

    var body: some View {
        List {
            Section("Reminders") {
                Toggle("Enable notifications", isOn: notificationsBinding)

                DatePicker(
                    "Default time for untimed repeating tasks",
                    selection: reminderTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .disabled(store.notifications.notificationsEnabled == false)
            }

            Section("Info") {
                Text("Timed repeating tasks alert at their scheduled time. Notifications include quick actions for Done and Snooze.")
                    .foregroundStyle(.secondary)
            }

            Section {
                if store.notifications.hasLoadedScheduledNotifications == false {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading scheduled notifications…")
                            .foregroundStyle(.secondary)
                    }
                } else if visibleScheduledNotifications.isEmpty {
                    Text(scheduledNotificationsEmptyText)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(visibleScheduledNotificationGroups) { group in
                        SettingsIOSScheduledNotificationGroup(
                            group: group,
                            store: store
                        )
                    }
                }
            } header: {
                Text(scheduledNotificationsTitle)
            } footer: {
                Text(scheduledNotificationsFooterText)
            }

            if store.notifications.systemSettingsNotificationsEnabled == false {
                Section("System Settings") {
                    Button("Allow Notifications in System Settings") {
                        store.send(.openAppSettingsTapped)
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { store.notifications.notificationsEnabled },
            set: { store.send(.toggleNotifications($0)) }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: { store.notifications.notificationReminderTime },
            set: { store.send(.notificationReminderTimeChanged($0)) }
        )
    }

    private var scheduledNotificationsTitle: String {
        let count = visibleScheduledNotifications.count
        return count == 0 ? "Scheduled Notifications" : "Scheduled Notifications (\(count))"
    }

    private var visibleScheduledNotifications: [ScheduledNotificationSummary] {
        store.notifications.scheduledNotifications.filter {
            areEventEmotionActionsEnabled || $0.sourceKind != .event
        }
    }

    private var visibleScheduledNotificationGroups: [ScheduledNotificationGroup] {
        ScheduledNotificationGroup.groups(from: visibleScheduledNotifications)
    }

    private var scheduledNotificationsFooterText: String {
        let sources = areEventEmotionActionsEnabled ? "task or event" : "task"
        return
            "Notifications are grouped by \(sources). Expand a group to review its queued alerts, postpone one, or remove only that occurrence from this device."
    }

    private var scheduledNotificationsEmptyText: String {
        if store.notifications.notificationsEnabled == false {
            return "Turn on notifications to schedule reminders."
        }
        if store.notifications.systemSettingsNotificationsEnabled == false {
            return "Notifications are disabled in system settings, so nothing is scheduled."
        }
        return "No notifications are currently scheduled."
    }
}

private struct SettingsIOSScheduledNotificationGroup: View {
    let group: ScheduledNotificationGroup
    let store: StoreOf<SettingsFeature>

    var body: some View {
        DisclosureGroup {
            ForEach(group.notifications) { notification in
                SettingsIOSScheduledNotificationRow(
                    notification: notification,
                    store: store
                )
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: group.sourceKind == .event ? "calendar" : "bell")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.title)
                        .font(.body.weight(.medium))
                    Text(group.queueSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
    }
}

private struct SettingsIOSScheduledNotificationRow: View {
    let notification: ScheduledNotificationSummary
    let store: StoreOf<SettingsFeature>
    @State private var isCustomPausePresented = false
    @State private var customPauseDate = Date()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Label(scheduledTimeText, systemImage: notification.isPaused ? "clock.badge" : "clock")
                    .font(.subheadline.weight(.medium))

                Text(notification.title.isEmpty ? "Routina notification" : notification.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if notification.isPaused, let originalScheduledAt = notification.originalScheduledAt {
                    Text("Originally \(originalScheduledAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !notification.detailText.isEmpty {
                    Text(notification.detailText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            notificationActionsMenu
        }
        .sheet(isPresented: $isCustomPausePresented) {
            SettingsIOSCustomNotificationPauseSheet(
                pauseDate: $customPauseDate,
                minimumDate: customPauseMinimumDate,
                sourceKind: notification.sourceKind,
                onCancel: { isCustomPausePresented = false },
                onPause: {
                    pause(until: customPauseDate)
                    isCustomPausePresented = false
                }
            )
            .presentationDetents([.medium])
        }
    }

    private var scheduledTimeText: String {
        notification.scheduledAt?.formatted(date: .abbreviated, time: .shortened)
            ?? "Scheduled time unavailable"
    }

    private var notificationActionsMenu: some View {
        Menu {
            Menu("Snooze") {
                Button("15 Minutes") {
                    pause(by: 15 * 60)
                }
                Button("1 Hour") {
                    pause(by: 60 * 60)
                }
                Button("Tomorrow") {
                    pauseUntilTomorrow()
                }
                Button("Choose Date & Time…") {
                    customPauseDate = pauseBaseDate.addingTimeInterval(60 * 60)
                    isCustomPausePresented = true
                }
            }

            Divider()

            Button("Remove This Alert", role: .destructive) {
                store.send(.removeScheduledNotificationTapped(notification))
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Actions for scheduled notification")
    }

    private func pause(by interval: TimeInterval) {
        pause(until: pauseBaseDate.addingTimeInterval(interval))
    }

    private func pauseUntilTomorrow() {
        pause(
            until: Calendar.current.date(byAdding: .day, value: 1, to: pauseBaseDate)
                ?? pauseBaseDate.addingTimeInterval(24 * 60 * 60)
        )
    }

    private func pause(until date: Date) {
        store.send(
            .pauseScheduledNotificationTapped(
                notification,
                until: date
            )
        )
    }

    private var pauseBaseDate: Date {
        max(notification.scheduledAt ?? Date(), Date())
    }

    private var customPauseMinimumDate: Date {
        pauseBaseDate.addingTimeInterval(60)
    }
}

private struct SettingsIOSCustomNotificationPauseSheet: View {
    @Binding var pauseDate: Date
    let minimumDate: Date
    let sourceKind: ScheduledNotificationSourceKind
    let onCancel: () -> Void
    let onPause: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "Snooze until",
                        selection: $pauseDate,
                        in: minimumDate...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                } footer: {
                    Text("This changes only the selected notification occurrence, not the \(sourceName) schedule.")
                }
            }
            .navigationTitle("Snooze Notification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Snooze", action: onPause)
                }
            }
        }
    }

    private var sourceName: String {
        sourceKind == .event ? "event" : "task"
    }
}
