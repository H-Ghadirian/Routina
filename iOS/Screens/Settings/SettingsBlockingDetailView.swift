import SwiftData
import SwiftUI

#if canImport(FamilyControls) && canImport(ManagedSettings)
import FamilyControls
import ManagedSettings
#endif

struct SettingsBlockingDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var enabledModes = FocusShieldSupport.loadEnabledBlockingModes()
    @State private var blockedWebsiteDomains = FocusShieldSupport.loadBlockedWebsiteDomains()
    @State private var websiteDraft = ""
    @State private var websiteStatusMessage: String?
    @AppStorage(
        UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isAwayEnabled = false

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
                ForEach(visibleBlockingModes) { mode in
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

            Section("Entered Websites") {
                HStack(spacing: 10) {
                    TextField("example.com", text: $websiteDraft)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()

                    Button {
                        addWebsiteDomain()
                    } label: {
                        Label("Add Website", systemImage: "plus.circle.fill")
                            .labelStyle(.iconOnly)
                    }
                    .disabled(websiteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let websiteStatusMessage {
                    Text(websiteStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if blockedWebsiteDomains.isEmpty {
                    Text("No entered websites.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(blockedWebsiteDomains) { website in
                        SettingsBlockedWebsiteRow(
                            website: website,
                            includesAway: isAwayEnabled,
                            onRemove: { removeWebsiteDomain(website) },
                            onModeChanged: { mode, isEnabled in
                                setWebsiteMode(mode, isEnabled: isEnabled, for: website)
                            }
                        )
                    }
                }

                Text("Entered websites are enforced on iPhone and iPad through Screen Time web content filtering.")
                    .font(.footnote)
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
            blockedWebsiteDomains = FocusShieldSupport.loadBlockedWebsiteDomains()
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
            statusMessage = selection.routinaSummaryText(
                includingEnteredWebsiteCount: blockedWebsiteDomains.count
            )
            syncBlocking()
        }
        .onChange(of: isFocusShieldEnabled) { _, _ in
            statusMessage = focusShieldSelection.routinaSummaryText(
                includingEnteredWebsiteCount: blockedWebsiteDomains.count
            )
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

    private var visibleBlockingModes: [ProtectionBlockingMode] {
        ProtectionBlockingMode.visibleCases(includingAway: isAwayEnabled)
    }

    private func addWebsiteDomain() {
        guard let website = FocusShieldSupport.blockedWebsiteDomain(from: websiteDraft) else {
            websiteStatusMessage = "Enter a valid website domain."
            return
        }

        blockedWebsiteDomains.append(website)
        FocusShieldSupport.saveBlockedWebsiteDomains(blockedWebsiteDomains)
        blockedWebsiteDomains = FocusShieldSupport.loadBlockedWebsiteDomains()
        websiteDraft = ""
        websiteStatusMessage = "\(website.domain) added."
        syncBlocking()
    }

    private func removeWebsiteDomain(_ website: BlockingWebsiteDomain) {
        blockedWebsiteDomains.removeAll { $0.id == website.id }
        FocusShieldSupport.saveBlockedWebsiteDomains(blockedWebsiteDomains)
        blockedWebsiteDomains = FocusShieldSupport.loadBlockedWebsiteDomains()
        websiteStatusMessage = FocusShieldSupport.blockedWebsiteDomainsSummaryText(blockedWebsiteDomains)
        syncBlocking()
    }

    private func setWebsiteMode(
        _ mode: ProtectionBlockingMode,
        isEnabled: Bool,
        for website: BlockingWebsiteDomain
    ) {
        guard let index = blockedWebsiteDomains.firstIndex(where: { $0.id == website.id }) else { return }
        if isEnabled {
            blockedWebsiteDomains[index].enabledModes.insert(mode)
        } else {
            blockedWebsiteDomains[index].enabledModes.remove(mode)
        }
        FocusShieldSupport.saveBlockedWebsiteDomains(blockedWebsiteDomains)
        blockedWebsiteDomains = FocusShieldSupport.loadBlockedWebsiteDomains()
        syncBlocking()
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
            return focusShieldSelection.routinaSummaryText(
                includingEnteredWebsiteCount: blockedWebsiteDomains.count
            )
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

private struct SettingsBlockedWebsiteRow: View {
    let website: BlockingWebsiteDomain
    let includesAway: Bool
    let onRemove: () -> Void
    let onModeChanged: (ProtectionBlockingMode, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .foregroundStyle(.secondary)
                    .frame(width: 22)

                Text(website.domain)
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: 10)

                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Label("Remove \(website.domain)", systemImage: "minus.circle")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(ProtectionBlockingMode.visibleCases(includingAway: includesAway)) { mode in
                    Toggle(mode.title, isOn: modeBinding(mode))
                        .font(.footnote)
                }
            }
            .padding(.leading, 32)
        }
    }

    private func modeBinding(_ mode: ProtectionBlockingMode) -> Binding<Bool> {
        Binding(
            get: { website.enabledModes.contains(mode) },
            set: { onModeChanged(mode, $0) }
        )
    }
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
