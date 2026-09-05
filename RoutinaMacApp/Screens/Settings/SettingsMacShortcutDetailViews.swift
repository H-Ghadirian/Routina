import SwiftUI
import ComposableArchitecture

struct SettingsMacShortcutsDetailView: View {
    @AppStorage(
        UserDefaultStringValueKey.macQuickAddShortcut.rawValue,
        store: SharedDefaults.app
    ) private var quickAddShortcutRawValue = MacQuickAddShortcut.defaultValue.rawValue
    @AppStorage(
        UserDefaultBoolValueKey.appSettingGoalsTabEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isGoalsTabEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacEventEmotionActionsEnabled.rawValue,
        store: SharedDefaults.app
    ) private var areMacEventEmotionActionsEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isPlacesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isNotesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isAwayEnabled = false

    private let appShortcuts: [SettingsMacShortcutRowModel] = [
        SettingsMacShortcutRowModel(title: "Quick Add", detail: "“Quick add in Routina” or “Add a task in Routina”"),
        SettingsMacShortcutRowModel(title: "Mark Done", detail: "“Mark task done in Routina” or “Complete a task in Routina”"),
        SettingsMacShortcutRowModel(title: "Start Focus", detail: "“Start focus in Routina” or “Focus with Routina”"),
        SettingsMacShortcutRowModel(title: "Sleep", detail: "“I am going to sleep in Routina” or “Start sleep mode in Routina”"),
        SettingsMacShortcutRowModel(title: "Wake Up", detail: "“I woke up in Routina” or “I am awake in Routina”"),
        SettingsMacShortcutRowModel(title: "Today", detail: "“What's due in Routina” or “Today in Routina”"),
    ]

    var body: some View {
        SettingsMacDetailShell(
            title: "Shortcuts",
            subtitle: "Review keyboard shortcuts and Apple Shortcuts that Routina exposes."
        ) {
            SettingsMacDetailCard(title: "Search or Create") {
                Picker("Shortcut", selection: quickAddShortcutBinding) {
                    ForEach(MacQuickAddShortcut.allCases) { shortcut in
                        Text("\(shortcut.title) · \(shortcut.detail)")
                            .tag(shortcut.rawValue)
                    }
                }
                .pickerStyle(.menu)

                Text("Focuses the Home toolbar search field. Press Return with a new query to create a task.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            SettingsMacDetailCard(title: "Keyboard") {
                ForEach(keyboardShortcuts) { shortcut in
                    SettingsMacShortcutRow(shortcut: shortcut)
                }
            }

            SettingsMacDetailCard(title: "Add Menu") {
                ForEach(addMenuShortcuts) { shortcut in
                    SettingsMacShortcutRow(
                        shortcut: SettingsMacShortcutRowModel(
                            title: shortcut.commandTitle,
                            detail: shortcut.detail,
                            shortcut: shortcut.shortcutTitle
                        )
                    )
                }
            }

            SettingsMacDetailCard(title: "Apple Shortcuts & Siri") {
                ForEach(appShortcuts) { shortcut in
                    SettingsMacShortcutRow(shortcut: shortcut)
                }
            }
        }
    }

    private var quickAddShortcut: MacQuickAddShortcut {
        MacQuickAddShortcut(rawValue: quickAddShortcutRawValue) ?? .defaultValue
    }

    private var quickAddShortcutBinding: Binding<String> {
        Binding(
            get: { quickAddShortcutRawValue },
            set: { rawValue in
                quickAddShortcutRawValue = rawValue
                RoutinaMacGlobalHotKeyManager.shared.registerQuickAddHotKey()
            }
        )
    }

    private var keyboardShortcuts: [SettingsMacShortcutRowModel] {
        [
            SettingsMacShortcutRowModel(
                title: "Search or Create",
                detail: "Focus Home search and create a task from a new query.",
                shortcut: quickAddShortcut.title
            ),
            SettingsMacShortcutRowModel(title: "Back", detail: "Return to the previous Home view.", shortcut: "⌘←"),
            SettingsMacShortcutRowModel(title: "Forward", detail: "Move forward after going back.", shortcut: "⌘→"),
            SettingsMacShortcutRowModel(title: "Planner", detail: "Switch the sidebar back to tasks.", shortcut: "⌥⌘1"),
            SettingsMacShortcutRowModel(title: "Stats", detail: "Open stats from anywhere in the app.", shortcut: "⌥⌘2"),
            SettingsMacShortcutRowModel(title: "Timeline", detail: "Open Planner List.", shortcut: "⌥⌘3"),
            SettingsMacShortcutRowModel(title: "Save", detail: "Confirm supported edit sheets and dialogs.", shortcut: "Return"),
            SettingsMacShortcutRowModel(title: "Cancel", detail: "Dismiss supported edit sheets and dialogs.", shortcut: "Esc"),
            SettingsMacShortcutRowModel(title: "Quit", detail: "Quit Routina from the menu bar extra or app menu.", shortcut: "⌘Q"),
        ]
    }

    private var addMenuShortcuts: [MacAddMenuShortcut] {
        MacAddMenuShortcut.visibleActions(
            eventEmotionEnabled: areMacEventEmotionActionsEnabled,
            notesEnabled: isNotesEnabled,
            goalsEnabled: isGoalsTabEnabled,
            placesEnabled: isPlacesEnabled,
            awayEnabled: isAwayEnabled
        )
    }
}
struct SettingsMacQuickAddDetailView: View {
    @AppStorage(
        UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isPlacesEnabled = false

    var body: some View {
        SettingsMacDetailShell(
            title: "Quick Add",
            subtitle: quickAddSubtitle
        ) {
            SettingsMacDetailCard(title: "Examples") {
                ForEach(SettingsQuickAddSyntaxGuide.visibleExamples(includingPlaces: isPlacesEnabled)) { example in
                    SettingsQuickAddExampleBlock(example: example)
                }
            }

            ForEach(SettingsQuickAddSyntaxGuide.visibleSyntaxGroups(includingPlaces: isPlacesEnabled)) { group in
                SettingsMacDetailCard(title: group.title) {
                    ForEach(group.rows) { row in
                        SettingsQuickAddSyntaxBlock(row: row, style: .badge)
                    }
                }
            }

            SettingsMacDetailCard(title: "Tips") {
                ForEach(SettingsQuickAddSyntaxGuide.visibleNotes(includingPlaces: isPlacesEnabled), id: \.self) { note in
                    SettingsQuickAddNoteBlock(note: note, style: .labeled)
                }
            }
        }
    }

    private var quickAddSubtitle: String {
        if isPlacesEnabled {
            return "Use compact phrases to create one-time tasks, repeating tasks, deadlines, tags, places, priority, and focus estimates."
        }
        return "Use compact phrases to create one-time tasks, repeating tasks, deadlines, tags, priority, and focus estimates."
    }
}

private struct SettingsMacShortcutRowModel: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    var shortcut: String?
}

private struct SettingsMacShortcutRow: View {
    let shortcut: SettingsMacShortcutRowModel

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(shortcut.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(shortcut.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            if let shortcut = shortcut.shortcut {
                Spacer(minLength: 12)

                SettingsMacShortcutKeyCluster(shortcut: shortcut)
                    .frame(minWidth: 120, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

private struct SettingsMacShortcutKeyCluster: View {
    let shortcut: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tokens.indices, id: \.self) { index in
                Text(tokens[index])
                    .font(.callout.weight(.bold).monospaced())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .padding(.horizontal, horizontalPadding(for: tokens[index]))
                    .frame(minWidth: minimumWidth(for: tokens[index]), minHeight: 30)
                    .routinaGlassCard(cornerRadius: 7, tint: .accentColor, tintOpacity: 0.16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.42), lineWidth: 1)
                    )
            }
        }
        .accessibilityLabel(shortcut)
    }

    private var tokens: [String] {
        switch shortcut {
        case "Return", "Esc":
            return [shortcut]
        default:
            return shortcut.map(String.init)
        }
    }

    private func minimumWidth(for token: String) -> CGFloat {
        token.count == 1 ? 30 : 74
    }

    private func horizontalPadding(for token: String) -> CGFloat {
        token.count == 1 ? 0 : 10
    }
}
