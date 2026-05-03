import SwiftUI
import ComposableArchitecture

struct SettingsMacAppearanceDetailView: View {
    let store: StoreOf<SettingsFeature>

    @AppStorage("macTodoBoardCompactCards", store: SharedDefaults.app)
    private var isMacTodoBoardCompactCards = false

    private let columns = [
        GridItem(.adaptive(minimum: 124), spacing: 12)
    ]

    var body: some View {
        WithPerceptionTracking {
            SettingsMacDetailShell(
                title: "Appearance",
                subtitle: "Choose the app theme, pick the Dock icon, and decide how the home list is grouped."
            ) {
                SettingsMacDetailCard(title: "App Theme") {
                    Picker("Theme", selection: appColorSchemeBinding) {
                        ForEach(AppColorScheme.allCases) { scheme in
                            Text(scheme.title).tag(scheme)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(store.appearance.appColorScheme.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                SettingsMacDetailCard(title: "Routine List") {
                    Picker("Grouping", selection: routineListSectioningModeBinding) {
                        ForEach(RoutineListSectioningMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(store.appearance.routineListSectioningSubtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                SettingsMacDetailCard(title: "Todo Board") {
                    Toggle("Compact cards", isOn: $isMacTodoBoardCompactCards)
                        .toggleStyle(.switch)

                    Text(
                        isMacTodoBoardCompactCards
                            ? "Shows a denser board for longer columns."
                            : "Shows fuller cards with a little more breathing room."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                SettingsMacDetailCard(title: "Tag Counters") {
                    Picker("Display", selection: tagCounterDisplayModeBinding) {
                        ForEach(TagCounterDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(store.appearance.tagCounterDisplayMode.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                SettingsMacDetailCard(title: "App Lock") {
                    Toggle("Require unlock when opening Routina", isOn: appLockBinding)
                        .toggleStyle(.switch)
                        .disabled(store.appearance.isAppLockToggleInProgress)

                    if store.appearance.isAppLockToggleInProgress {
                        ProgressView("Verifying device authentication…")
                            .controlSize(.small)
                    }

                    Text(store.appearance.appLockDetailText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                SettingsMacDetailCard(title: "Advanced") {
                    Toggle("Enable Git features", isOn: gitFeaturesBinding)
                        .toggleStyle(.switch)

                    Text("Shows GitHub and GitLab connection settings and contribution activity in Stats.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                SettingsMacDetailCard(title: "Temporary View State") {
                    Button {
                        guard store.appearance.hasTemporaryViewStateToReset else { return }
                        store.send(.resetTemporaryViewStateTapped)
                    } label: {
                        Label(resetButtonTitle, systemImage: resetButtonSystemImage)
                    }
                    .buttonStyle(.bordered)
                    .tint(store.appearance.hasTemporaryViewStateToReset ? .red : .gray)
                    .disabled(!store.appearance.hasTemporaryViewStateToReset)

                    Text(resetButtonDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                SettingsMacDetailCard(title: "App Icon") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AppIconOption.allCases) { option in
                            SettingsMacAppIconButton(
                                option: option,
                                isSelected: store.appearance.selectedAppIcon == option
                            ) {
                                store.send(.appIconSelected(option))
                            }
                        }
                    }

                    Text("Changes the Dock and app switcher icon immediately. Finder keeps the bundled app icon.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !store.appearance.appIconStatusMessage.isEmpty {
                    SettingsMacDetailCard(title: "Status") {
                        Text(store.appearance.appIconStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !store.appearance.appLockStatusMessage.isEmpty {
                    SettingsMacDetailCard(title: "Status") {
                        Text(store.appearance.appLockStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !store.appearance.temporaryViewStateStatusMessage.isEmpty {
                    SettingsMacDetailCard(title: "Status") {
                        Text(store.appearance.temporaryViewStateStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var routineListSectioningModeBinding: Binding<RoutineListSectioningMode> {
        Binding(
            get: { store.appearance.routineListSectioningMode },
            set: { store.send(.routineListSectioningModeChanged($0)) }
        )
    }

    private var appColorSchemeBinding: Binding<AppColorScheme> {
        Binding(
            get: { store.appearance.appColorScheme },
            set: { store.send(.appColorSchemeChanged($0)) }
        )
    }

    private var appLockBinding: Binding<Bool> {
        Binding(
            get: { store.appearance.isAppLockEnabled },
            set: { store.send(.appLockToggled($0)) }
        )
    }

    private var gitFeaturesBinding: Binding<Bool> {
        Binding(
            get: { store.appearance.isGitFeaturesEnabled },
            set: { store.send(.gitFeaturesToggled($0)) }
        )
    }

    private var resetButtonTitle: String {
        store.appearance.hasTemporaryViewStateToReset
            ? "Reset Filters and Selections"
            : "Filters and Selections Are Clear"
    }

    private var tagCounterDisplayModeBinding: Binding<TagCounterDisplayMode> {
        Binding(
            get: { store.appearance.tagCounterDisplayMode },
            set: { store.send(.tagCounterDisplayModeChanged($0)) }
        )
    }

    private var resetButtonSystemImage: String {
        store.appearance.hasTemporaryViewStateToReset
            ? "arrow.counterclockwise"
            : "checkmark.circle"
    }

    private var resetButtonDescription: String {
        store.appearance.hasTemporaryViewStateToReset
            ? "Clears saved filters, list mode choices, and other temporary view selections so the app opens with defaults again."
            : "Everything is already using the default filters and temporary selections."
    }
}
