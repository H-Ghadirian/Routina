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
            subtitle: "Ask a connected AI to explain Routina or answer questions about your tasks."
        ) {
            SettingsMacDetailCard(title: "Local AI Access") {
                Toggle("Allow read-only task access", isOn: localAIAccessBinding)
                    .toggleStyle(.switch)

                Text("The connection can explain Routina features without reading your task data. When this setting is enabled, it can also use a private, read-only snapshot containing task names, schedules, dates, tags, descriptions, notes, links, goals, places, and progress.")
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
                Text("1. Copy the setup command and paste it into Terminal once.\n2. Start a new AI task so it discovers Routina.\n3. Ask a question from the guide below. Enable Local AI Access only when you also want answers about your personal tasks.")
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

            }

            SettingsMacDetailCard(title: "Questions you can ask") {
                Text("Ask what a feature means, why something appears, or how two Routina concepts differ. Select a question to copy it.")
                    .font(.callout)

                VStack(spacing: 8) {
                    ForEach(RoutinaHelpCatalog.starterQuestions, id: \.self) { question in
                        guideQuestionButton(question)
                    }
                }

                Divider()

                Text("With Local AI Access enabled, you can also ask about your own data:")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                guideQuestionButton("What Routina tasks are overdue, and what should I focus on today?")
            }

            SettingsMacDetailCard(title: "What the connection can do") {
                Label("Explain Routina features and interface concepts", systemImage: "questionmark.bubble")
                Label("Search and summarize your tasks when read-only access is enabled", systemImage: "magnifyingglass")
                Label("Show when the shared task data was last refreshed", systemImage: "clock")

                Text("The connection cannot create, edit, complete, archive, or delete anything in Routina. Product help is built into the connection and does not require access to personal task data.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            SettingsMacDetailCard(title: "Privacy") {
                Text("Routina has no AI backend in this flow. Your AI client runs the local helper and may send the task details needed to answer your question to its own AI provider. Review that provider’s privacy settings before connecting.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            SettingsMacDetailCard(title: "If a question does not work") {
                Text("Start a new AI task after running the setup command so the client reloads its available Routina tools. If a personal-task answer is missing or outdated, open Routina, enable Local AI Access, and choose Refresh shared data now. If setup is unavailable, install or update the Codex or ChatGPT desktop app and return here.")
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

    private func guideQuestionButton(_ question: String) -> some View {
        Button {
            copyToPasteboard(question)
            statusMessage = "Question copied. Paste it into a new AI task."
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(question)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 12)
                Image(systemName: "doc.on.doc")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary.opacity(0.55))
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .help("Copy question")
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
