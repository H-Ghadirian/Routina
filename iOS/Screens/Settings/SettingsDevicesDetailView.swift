import ComposableArchitecture
import SwiftUI

struct SettingsDevicesDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        List {
            if let currentDevice {
                Section("This Device") {
                    SettingsDeviceSessionRow(session: currentDevice)
                }
            }

            let otherDevices = store.devices.sessions.filter { !$0.isCurrentDevice }
            if !otherDevices.isEmpty {
                Section("Active Devices") {
                    ForEach(otherDevices) { session in
                        SettingsDeviceSessionRow(session: session)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Devices")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var currentDevice: RoutinaDeviceSessionSummary? {
        store.devices.sessions.first(where: \.isCurrentDevice)
    }
}

private struct SettingsDeviceSessionRow: View {
    let session: RoutinaDeviceSessionSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: session.platform.systemImage)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.accentColor.gradient))

            VStack(alignment: .leading, spacing: 4) {
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
        }
        .padding(.vertical, 4)
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
