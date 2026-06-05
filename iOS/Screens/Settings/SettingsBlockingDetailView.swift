import SwiftData
import SwiftUI

#if canImport(FamilyControls) && canImport(ManagedSettings)
import FamilyControls
import ManagedSettings
#endif

struct SettingsBlockingDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var enabledModes = FocusShieldSupport.loadEnabledBlockingModes()

    #if canImport(FamilyControls) && canImport(ManagedSettings)
    @AppStorage(
        UserDefaultBoolValueKey.appSettingFocusShieldEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isFocusShieldEnabled = false
    @State private var focusShieldSelection = FocusShieldSupport.loadSelection()
    @State private var isFocusShieldPickerPresented = false
    @State private var isRequestingFocusShieldAuthorization = false
    @State private var statusMessage: String?
    #endif

    var body: some View {
        List {
            Section("Applies During") {
                ForEach(ProtectionBlockingMode.allCases) { mode in
                    Toggle(isOn: binding(for: mode)) {
                        SettingsBlockingModeLabel(mode: mode)
                    }
                }
            }

            #if canImport(FamilyControls) && canImport(ManagedSettings)
            Section("Apps & Websites") {
                Toggle("Block selected apps and websites", isOn: $isFocusShieldEnabled)

                HStack(spacing: 10) {
                    Button {
                        requestAuthorization()
                    } label: {
                        Label(authorizationButtonTitle, systemImage: "person.badge.key")
                    }
                    .disabled(isRequestingFocusShieldAuthorization)

                    Button {
                        focusShieldSelection = FocusShieldSupport.loadSelection()
                        isFocusShieldPickerPresented = true
                    } label: {
                        Label("Choose", systemImage: "slider.horizontal.3")
                    }
                    .disabled(authorizationState != .approved)
                }

                Text(descriptionText)
                    .foregroundStyle(.secondary)
            }
            #else
            Section("Apps & Websites") {
                Text("App and website blocking is available on iPhone and iPad through Screen Time.")
                    .foregroundStyle(.secondary)
            }
            #endif
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Blocking")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            enabledModes = FocusShieldSupport.loadEnabledBlockingModes()
            #if canImport(FamilyControls) && canImport(ManagedSettings)
            focusShieldSelection = FocusShieldSupport.loadSelection()
            #endif
        }
        #if canImport(FamilyControls) && canImport(ManagedSettings)
        .familyActivityPicker(
            title: "Blocked During Protected Modes",
            headerText: "Choose the apps, categories, and websites Routina should block during enabled protected modes.",
            footerText: "Routina only receives private tokens for your choices.",
            isPresented: $isFocusShieldPickerPresented,
            selection: $focusShieldSelection
        )
        .onChange(of: focusShieldSelection) { _, selection in
            FocusShieldSupport.saveSelection(selection)
            statusMessage = selection.routinaSummaryText
            syncBlocking()
        }
        .onChange(of: isFocusShieldEnabled) { _, _ in
            statusMessage = focusShieldSelection.routinaSummaryText
            syncBlocking()
        }
        #endif
    }

    private func binding(for mode: ProtectionBlockingMode) -> Binding<Bool> {
        Binding(
            get: { enabledModes.contains(mode) },
            set: { isEnabled in
                enabledModes = FocusShieldSupport.setBlockingMode(mode, isEnabled: isEnabled)
                syncBlocking()
            }
        )
    }

    private func syncBlocking() {
        #if canImport(FamilyControls) && canImport(ManagedSettings)
        FocusShieldSupport.syncFocusShield(using: modelContext)
        #endif
    }

    #if canImport(FamilyControls) && canImport(ManagedSettings)
    private var authorizationState: FocusShieldAuthorizationState {
        FocusShieldSupport.authorizationState()
    }

    private var authorizationButtonTitle: String {
        switch authorizationState {
        case .approved:
            return "Allowed"
        case .denied, .notDetermined:
            return "Allow Access"
        case .unavailable:
            return "Unavailable"
        }
    }

    private var descriptionText: String {
        if enabledModes.isEmpty {
            return "No protected modes are enabled for blocking."
        }
        if !isFocusShieldEnabled {
            return "Turn blocking on, then choose apps and websites."
        }
        if let statusMessage {
            return statusMessage
        }

        switch authorizationState {
        case .approved:
            return focusShieldSelection.routinaSummaryText
        case .denied:
            return "Screen Time access is off. Allow access to block selected apps and websites."
        case .notDetermined:
            return "Allow Screen Time access, then choose what to block."
        case .unavailable:
            return "App and website blocking is available on iPhone and iPad."
        }
    }

    private func requestAuthorization() {
        isRequestingFocusShieldAuthorization = true
        Task { @MainActor in
            do {
                try await FocusShieldSupport.requestAuthorization()
                statusMessage = FocusShieldSupport.authorizationState() == .approved
                    ? focusShieldSelection.routinaSummaryText
                    : "Screen Time access was not approved."
                syncBlocking()
            } catch {
                statusMessage = "Screen Time access failed: \(error.localizedDescription)"
            }
            isRequestingFocusShieldAuthorization = false
        }
    }
    #endif
}

private struct SettingsBlockingModeLabel: View {
    let mode: ProtectionBlockingMode

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(mode.label)
                Text(mode.settingsDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: mode.systemImage)
        }
    }
}
