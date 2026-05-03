import SwiftUI
import ComposableArchitecture

struct SettingsAppearanceDetailView: View {
    let store: StoreOf<SettingsFeature>
    @State private var resetFeedbackTrigger = false

    private let columns = [
        GridItem(.adaptive(minimum: 108), spacing: 12)
    ]

    var body: some View {
        WithPerceptionTracking {
            List {
                Section("App Theme") {
                    Picker("Theme", selection: appColorSchemeBinding) {
                        ForEach(AppColorScheme.allCases) { scheme in
                            Text(scheme.title).tag(scheme)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(store.appearance.appColorScheme.subtitle)
                        .foregroundStyle(.secondary)
                }

                Section("Routine List") {
                    Picker("Grouping", selection: routineListSectioningModeBinding) {
                        ForEach(RoutineListSectioningMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(store.appearance.routineListSectioningSubtitle)
                        .foregroundStyle(.secondary)
                }

                Section("Tag Counters") {
                    Picker("Display", selection: tagCounterDisplayModeBinding) {
                        ForEach(TagCounterDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(store.appearance.tagCounterDisplayMode.subtitle)
                        .foregroundStyle(.secondary)
                }

                Section("App Lock") {
                    Toggle("Require unlock when opening Routina", isOn: appLockBinding)
                        .disabled(store.appearance.isAppLockToggleInProgress)

                    if store.appearance.isAppLockToggleInProgress {
                        ProgressView("Verifying device authentication…")
                    }

                    Text(store.appearance.appLockDetailText)
                        .foregroundStyle(.secondary)
                }

                Section("Advanced") {
                    Toggle("Enable Git features", isOn: gitFeaturesBinding)

                    Text("Shows GitHub and GitLab connection settings and contribution activity in Stats.")
                        .foregroundStyle(.secondary)
                }

                Section("Temporary View State") {
                    Button {
                        guard store.appearance.hasTemporaryViewStateToReset else { return }
                        resetFeedbackTrigger.toggle()
                        store.send(.resetTemporaryViewStateTapped)
                    } label: {
                        Label(resetButtonTitle, systemImage: resetButtonSystemImage)
                            .foregroundStyle(resetButtonForegroundStyle)
                    }
                    .disabled(!store.appearance.hasTemporaryViewStateToReset)

                    Text(resetButtonDescription)
                        .foregroundStyle(.secondary)
                }

                Section("App Icon") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AppIconOption.allCases) { option in
                            SettingsAppIconButton(
                                option: option,
                                isSelected: store.appearance.selectedAppIcon == option
                            ) {
                                store.send(.appIconSelected(option))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

                    Text("iOS confirms icon changes before applying them.")
                        .foregroundStyle(.secondary)
                }

                if !store.appearance.appIconStatusMessage.isEmpty {
                    Section("Status") {
                        Text(store.appearance.appIconStatusMessage)
                            .foregroundStyle(.secondary)
                    }
                }

                if !store.appearance.appLockStatusMessage.isEmpty {
                    Section("Status") {
                        Text(store.appearance.appLockStatusMessage)
                            .foregroundStyle(.secondary)
                    }
                }

                if !store.appearance.temporaryViewStateStatusMessage.isEmpty {
                    Section("Status") {
                        Text(store.appearance.temporaryViewStateStatusMessage)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.success, trigger: resetFeedbackTrigger)
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

    private var resetButtonForegroundStyle: AnyShapeStyle {
        store.appearance.hasTemporaryViewStateToReset
            ? AnyShapeStyle(Color.red)
            : AnyShapeStyle(Color.secondary)
    }
}
