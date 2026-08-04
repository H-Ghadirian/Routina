import AppKit
import SwiftData
import SwiftUI

struct SettingsMacAIConnectionsDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacLocalAIAccessEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isLocalAIAccessEnabled = false
    @State private var lastUpdatedAt: Date?
    @State private var statusMessage: String?

    var body: some View {
        SettingsMacDetailShell(
            title: "AI Connections",
            subtitle: "Ask an AI client about your Routina tasks without giving it direct database access."
        ) {
            SettingsMacDetailCard(title: "Local AI Access") {
                Toggle("Allow read-only task access", isOn: localAIAccessBinding)
                    .toggleStyle(.switch)

                Text("Routina creates a private, read-only snapshot containing task names, schedules, dates, tags, descriptions, notes, links, goals, places, and progress. The AI connection cannot edit Routina.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                settingsInfoRow(
                    title: "Status",
                    value: isLocalAIAccessEnabled ? "Enabled" : "Disabled"
                )

                if let lastUpdatedAt {
                    settingsInfoRow(
                        title: "Data updated",
                        value: lastUpdatedAt.formatted(date: .abbreviated, time: .shortened)
                    )
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button("Refresh shared data now") {
                    refreshSnapshot()
                }
                .buttonStyle(.bordered)
                .disabled(!isLocalAIAccessEnabled)
            }

            SettingsMacDetailCard(title: "Connect ChatGPT or Codex") {
                Text("1. Enable Local AI Access above.\n2. Copy the setup command and paste it into Terminal once.\n3. Start a new AI task and ask: “What Routina tasks are overdue?”")
                    .font(.callout)

                Button {
                    if let setupCommand = RoutinaMacAIConnectionSupport.setupCommand {
                        copyToPasteboard(setupCommand)
                        statusMessage = "Setup command copied. Paste it into Terminal."
                    }
                } label: {
                    Label("Copy setup command", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!RoutinaMacAIConnectionSupport.isSetupAvailable)

                if !RoutinaMacAIConnectionSupport.isHelperAvailable {
                    Text("The MCP helper is not included in this build of Routina.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                } else if !RoutinaMacAIConnectionSupport.isCodexCLIAvailable {
                    Text("The Codex or ChatGPT desktop CLI was not found in Applications. Install or update the AI desktop app, then return here.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                Button {
                    copyToPasteboard("What Routina tasks are overdue, and what should I focus on today?")
                    statusMessage = "Example question copied."
                } label: {
                    Label("Copy example question", systemImage: "text.bubble")
                }
                .buttonStyle(.bordered)
            }

            SettingsMacDetailCard(title: "Privacy") {
                Text("Routina has no AI backend in this flow. Your AI client runs the local helper and may send the task details needed to answer your question to its own AI provider. Review that provider’s privacy settings before connecting.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear(perform: loadStatus)
    }

    private var localAIAccessBinding: Binding<Bool> {
        Binding(
            get: { isLocalAIAccessEnabled },
            set: { newValue in
                isLocalAIAccessEnabled = newValue
                if newValue {
                    refreshSnapshot()
                } else {
                    removeSnapshot()
                }
            }
        )
    }

    private func refreshSnapshot() {
        do {
            let catalog = try RoutinaAIReadOnlySnapshotStore.refresh(using: modelContext)
            lastUpdatedAt = catalog.generatedAt
            statusMessage = "Read-only data is ready for connected AI clients."
        } catch {
            statusMessage = "Could not prepare AI data: \(error.localizedDescription)"
        }
    }

    private func removeSnapshot() {
        do {
            try RoutinaAIReadOnlySnapshotStore.remove()
            lastUpdatedAt = nil
            statusMessage = "Shared AI data removed."
        } catch {
            statusMessage = "Could not remove shared AI data: \(error.localizedDescription)"
        }
    }

    private func loadStatus() {
        guard isLocalAIAccessEnabled else {
            lastUpdatedAt = nil
            return
        }
        lastUpdatedAt = try? RoutinaAIReadOnlySnapshotStore.load().generatedAt
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

private enum RoutinaMacAIConnectionSupport {
    static var helperExecutableURL: URL {
        Bundle.main.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Helpers", isDirectory: true)
            .appendingPathComponent("RoutinaAIMCPServer", isDirectory: false)
    }

    static var isHelperAvailable: Bool {
        FileManager.default.isExecutableFile(atPath: helperExecutableURL.path)
    }

    static var isCodexCLIAvailable: Bool {
        codexExecutablePath != nil
    }

    static var isSetupAvailable: Bool {
        isHelperAvailable && isCodexCLIAvailable
    }

    static var setupCommand: String? {
        guard let codexExecutablePath else { return nil }
        let mode = AppEnvironment.isSandboxDataMode ? "--sandbox" : "--production"
        return "\(shellQuoted(codexExecutablePath)) mcp add routina -- \(shellQuoted(helperExecutableURL.path)) \(mode)"
    }

    private static var codexExecutablePath: String? {
        let candidates = [
            "/Applications/Codex.app/Contents/Resources/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex"
        ]
        return candidates.first(where: FileManager.default.isExecutableFile(atPath:))
    }

    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
