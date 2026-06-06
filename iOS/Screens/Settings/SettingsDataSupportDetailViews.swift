import SwiftUI
import ComposableArchitecture

struct SettingsAboutDetailView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
List {
    Section("Contact") {
        Button {
            store.send(.contactUsTapped)
        } label: {
            Label("Email Support", systemImage: "envelope")
        }

        HStack {
            Text("Email")
            Spacer()
            Text("h.qadirian@gmail.com")
                .foregroundStyle(.secondary)
        }
    }

    Section("App") {
        HStack {
            Text("Version")
            Spacer()
            Text(store.diagnostics.appVersion)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 5) {
            store.send(.aboutSectionLongPressed)
        }
    }

    if store.diagnostics.isDebugSectionVisible {
        Section("Diagnostics") {
            SettingsInfoRow(title: "Data Mode", value: store.diagnostics.dataModeDescription)
            SettingsInfoRow(title: "iCloud Container", value: store.diagnostics.iCloudContainerDescription)

            Text("Last CloudKit Event: \(store.diagnostics.cloudDiagnosticsTimestamp)")
                .foregroundStyle(.secondary)
            Text(store.diagnostics.cloudDiagnosticsSummary)
                .foregroundStyle(.secondary)
            Text(store.diagnostics.pushDiagnosticsStatus)
                .foregroundStyle(.secondary)
        }
    }
}
.listStyle(.insetGrouped)
.navigationTitle("Support & About")
.navigationBarTitleDisplayMode(.inline)
    }
}
