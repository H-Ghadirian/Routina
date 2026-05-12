import ComposableArchitecture
import SwiftUI

struct SettingsMacDevicesDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            SettingsMacDetailShell(
                title: "Devices",
                subtitle: "Review the devices that have recently used Routina."
            ) {
                if let currentDevice {
                    SettingsMacDetailCard(title: "This Device") {
                        SettingsMacDeviceSessionRow(session: currentDevice)
                    }
                }

                let otherDevices = store.devices.sessions.filter { !$0.isCurrentDevice }
                if !otherDevices.isEmpty {
                    SettingsMacDetailCard(title: "Active Devices") {
                        VStack(spacing: 0) {
                            ForEach(otherDevices) { session in
                                SettingsMacDeviceSessionRow(session: session)
                                if session.id != otherDevices.last?.id {
                                    Divider()
                                        .padding(.vertical, 10)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var currentDevice: RoutinaDeviceSessionSummary? {
        store.devices.sessions.first(where: \.isCurrentDevice)
    }
}

private struct SettingsMacDeviceSessionRow: View {
    let session: RoutinaDeviceSessionSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: session.platform.systemImage)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.accentColor.gradient))

            VStack(alignment: .leading, spacing: 5) {
                Text(session.displayName)
                    .font(.headline)

                Text(deviceDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(activityDetail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var deviceDetail: String {
        let system = [session.systemName, session.systemVersion]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let app = session.appVersion.isEmpty ? nil : "Routina \(session.appVersion)"
        return [session.modelName, system, app]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " • ")
    }

    private var activityDetail: String {
        let lastSeen = Self.relativeFormatter.localizedString(for: session.lastSeenAt, relativeTo: Date())
        if let lastMutationAt = session.lastMutationAt {
            let mutation = Self.relativeFormatter.localizedString(for: lastMutationAt, relativeTo: Date())
            return "Active \(lastSeen) • Last change \(mutation)"
        }
        return "Active \(lastSeen)"
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
}
