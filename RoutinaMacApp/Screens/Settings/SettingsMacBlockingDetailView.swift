import SwiftData
import SwiftUI

#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

struct SettingsMacBlockingDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var enabledModes = FocusShieldSupport.loadEnabledBlockingModes()

    #if os(macOS)
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacFocusAppBlockingEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isMacAppBlockingEnabled = true
    @State private var blockedApps = FocusShieldSupport.loadMacBlockedApps()
    @State private var blockedWebsiteDomains = FocusShieldSupport.loadBlockedWebsiteDomains()
    @State private var websiteDraft = ""
    @State private var statusMessage: String?
    @State private var websiteStatusMessage: String?
    @State private var websiteBlockingStatus = FocusShieldSupport.macWebsiteBlockingStatus()
    #endif

    var body: some View {
        SettingsMacDetailShell(
            title: "Blocking",
            subtitle: "Manage one distraction list and choose which protected modes use it."
        ) {
            SettingsMacDetailCard(title: "Protected Modes") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(ProtectionBlockingMode.allCases) { mode in
                        Toggle(isOn: binding(for: mode)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Label(mode.label, systemImage: mode.systemImage)
                                    .font(.subheadline.weight(.semibold))
                                Text(mode.settingsDescription)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                    }

                    Text("Enabled modes: \(FocusShieldSupport.enabledBlockingModesSummaryText(enabledModes)).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            #if os(macOS)
            SettingsMacDetailCard(title: "Mac Apps") {
                Toggle("Block selected Mac apps", isOn: $isMacAppBlockingEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: isMacAppBlockingEnabled) { _, _ in
                        syncBlocking()
                    }

                HStack(spacing: 10) {
                    Button {
                        chooseBlockedApps()
                    } label: {
                        Label("Choose Apps", systemImage: "plus.app")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        blockedApps = []
                        FocusShieldSupport.saveMacBlockedApps(blockedApps)
                        statusMessage = FocusShieldSupport.macBlockedAppsSummaryText(blockedApps)
                        syncBlocking()
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(blockedApps.isEmpty)
                }

                if blockedApps.isEmpty {
                    Text("No Mac apps selected.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(blockedApps) { app in
                            SettingsMacBlockedAppRow(
                                app: app,
                                onRemove: { removeBlockedApp(app) },
                                onModeChanged: { mode, isEnabled in
                                    setMode(mode, isEnabled: isEnabled, for: app)
                                }
                            )
                        }
                    }
                }

                Text(macDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            SettingsMacDetailCard(title: "Websites") {
                HStack(spacing: 10) {
                    TextField("example.com", text: $websiteDraft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addWebsiteDomain)

                    Button {
                        addWebsiteDomain()
                    } label: {
                        Label("Add Website", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(websiteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let websiteStatusMessage {
                    Text(websiteStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let message = websiteBlockingStatus.message {
                    Label(message, systemImage: websiteBlockingStatusSystemImage)
                        .font(.footnote)
                        .foregroundStyle(websiteBlockingStatusForegroundStyle)
                }

                if blockedWebsiteDomains.isEmpty {
                    Text("No websites entered.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(blockedWebsiteDomains) { website in
                            SettingsMacBlockedWebsiteRow(
                                website: website,
                                onRemove: { removeWebsiteDomain(website) },
                                onModeChanged: { mode, isEnabled in
                                    setWebsiteMode(mode, isEnabled: isEnabled, for: website)
                                }
                            )
                        }
                    }
                }

                Text("Routina redirects matching tabs in Safari, Chrome, Edge, Brave, Arc, Opera, Vivaldi, and Chromium while blocking is active. macOS may ask for permission to control each browser. Firefox support needs a future browser extension.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            #endif
        }
        .onAppear {
            enabledModes = FocusShieldSupport.loadEnabledBlockingModes()
            #if os(macOS)
            blockedApps = FocusShieldSupport.loadMacBlockedApps()
            blockedWebsiteDomains = FocusShieldSupport.loadBlockedWebsiteDomains()
            websiteBlockingStatus = FocusShieldSupport.macWebsiteBlockingStatus()
            #endif
        }
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: .routinaMacWebsiteBlockingStatusDidChange)) { _ in
            websiteBlockingStatus = FocusShieldSupport.macWebsiteBlockingStatus()
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
        #if os(macOS)
        FocusShieldSupport.syncFocusShield(using: modelContext)
        #endif
    }

    #if os(macOS)
    private var macDescription: String {
        if let statusMessage {
            return "\(statusMessage). Routina closes selected Mac apps during enabled protected modes."
        }
        return "\(FocusShieldSupport.macBlockedAppsSummaryText(blockedApps)). Routina closes selected Mac apps during enabled protected modes."
    }

    private var websiteBlockingStatusSystemImage: String {
        switch websiteBlockingStatus.kind {
        case .inactive:
            return "info.circle"
        case .active:
            return "checkmark.shield"
        case .warning:
            return "exclamationmark.triangle"
        }
    }

    private var websiteBlockingStatusForegroundStyle: Color {
        switch websiteBlockingStatus.kind {
        case .warning:
            return .orange
        case .inactive, .active:
            return .secondary
        }
    }

    private func chooseBlockedApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Choose apps to block during enabled protected modes."
        panel.prompt = "Choose"

        guard panel.runModal() == .OK else { return }

        let newApps = panel.urls.compactMap(FocusShieldSupport.macBlockedApp(from:))
        guard !newApps.isEmpty else {
            statusMessage = "No valid apps selected"
            return
        }

        blockedApps.append(contentsOf: newApps)
        FocusShieldSupport.saveMacBlockedApps(blockedApps)
        blockedApps = FocusShieldSupport.loadMacBlockedApps()
        statusMessage = FocusShieldSupport.macBlockedAppsSummaryText(blockedApps)
        syncBlocking()
    }

    private func removeBlockedApp(_ app: MacFocusBlockedApp) {
        blockedApps.removeAll { $0.id == app.id }
        FocusShieldSupport.saveMacBlockedApps(blockedApps)
        blockedApps = FocusShieldSupport.loadMacBlockedApps()
        statusMessage = FocusShieldSupport.macBlockedAppsSummaryText(blockedApps)
        syncBlocking()
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

    private func setMode(
        _ mode: ProtectionBlockingMode,
        isEnabled: Bool,
        for app: MacFocusBlockedApp
    ) {
        guard let index = blockedApps.firstIndex(where: { $0.id == app.id }) else { return }
        if isEnabled {
            blockedApps[index].enabledModes.insert(mode)
        } else {
            blockedApps[index].enabledModes.remove(mode)
        }
        FocusShieldSupport.saveMacBlockedApps(blockedApps)
        blockedApps = FocusShieldSupport.loadMacBlockedApps()
        syncBlocking()
    }
    #endif
}

#if os(macOS)
private struct SettingsMacBlockedWebsiteRow: View {
    let website: BlockingWebsiteDomain
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

                Button {
                    onRemove()
                } label: {
                    Label("Remove \(website.domain)", systemImage: "minus.circle")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Remove")
            }

            HStack(spacing: 14) {
                ForEach(ProtectionBlockingMode.allCases) { mode in
                    Toggle(mode.title, isOn: modeBinding(mode))
                        .toggleStyle(.checkbox)
                        .font(.caption)
                }
            }
            .padding(.leading, 32)
        }
        .padding(10)
        .routinaGlassCard(cornerRadius: 10, tint: .secondary, tintOpacity: 0.04)
    }

    private func modeBinding(_ mode: ProtectionBlockingMode) -> Binding<Bool> {
        Binding(
            get: { website.enabledModes.contains(mode) },
            set: { onModeChanged(mode, $0) }
        )
    }
}

private struct SettingsMacBlockedAppRow: View {
    let app: MacFocusBlockedApp
    let onRemove: () -> Void
    let onModeChanged: (ProtectionBlockingMode, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "app.dashed")
                    .foregroundStyle(.secondary)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(app.bundleIdentifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 10)

                Button {
                    onRemove()
                } label: {
                    Label("Remove \(app.displayName)", systemImage: "minus.circle")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Remove")
            }

            HStack(spacing: 14) {
                ForEach(ProtectionBlockingMode.allCases) { mode in
                    Toggle(mode.title, isOn: modeBinding(mode))
                        .toggleStyle(.checkbox)
                        .font(.caption)
                }
            }
            .padding(.leading, 32)
        }
        .padding(10)
        .routinaGlassCard(cornerRadius: 10, tint: .secondary, tintOpacity: 0.04)
    }

    private func modeBinding(_ mode: ProtectionBlockingMode) -> Binding<Bool> {
        Binding(
            get: { app.enabledModes.contains(mode) },
            set: { onModeChanged(mode, $0) }
        )
    }
}
#endif
