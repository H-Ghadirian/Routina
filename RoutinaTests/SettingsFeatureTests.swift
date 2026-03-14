import ComposableArchitecture
import Testing
@testable @preconcurrency import Routina

@MainActor
@Suite(.serialized)
struct SettingsFeatureTests {
    @Test
    func appIconOptionMappings_matchExpectedAlternateIconNames() {
        #expect(AppIconOption.orange.iOSAlternateIconName == nil)
        #expect(AppIconOption.yellow.iOSAlternateIconName == "AppIconYellow")
        #expect(AppIconOption.teal.iOSAlternateIconName == "AppIconTeal")
        #expect(AppIconOption.lightBlue.iOSAlternateIconName == "AppIconLightBlue")
        #expect(AppIconOption.darkBlue.iOSAlternateIconName == "AppIconDarkBlue")
    }

    @Test
    func appIconSelected_successUpdatesSelection() async {
        let previousSelection = SharedDefaults.app[.selectedMacAppIcon]
        defer {
            SharedDefaults.app[.selectedMacAppIcon] = previousSelection
        }

        SharedDefaults.app[.selectedMacAppIcon] = AppIconOption.orange.rawValue

        let store = TestStore(
            initialState: SettingsFeature.State(selectedAppIcon: .orange)
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appIconClient.requestChange = { option in
                #expect(option == .yellow)
                return nil
            }
        }

        await store.send(.appIconSelected(.yellow))

        await store.receive(.appIconChangeFinished(requestedOption: .yellow, errorMessage: nil)) {
            $0.selectedAppIcon = .yellow
        }
    }

    @Test
    func appIconSelected_failureKeepsCurrentSelectionAndShowsError() async {
        let previousSelection = SharedDefaults.app[.selectedMacAppIcon]
        defer {
            SharedDefaults.app[.selectedMacAppIcon] = previousSelection
        }

        SharedDefaults.app[.selectedMacAppIcon] = AppIconOption.orange.rawValue

        let store = TestStore(
            initialState: SettingsFeature.State(
                appIconStatusMessage: "Old status",
                selectedAppIcon: .orange
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appIconClient.requestChange = { option in
                #expect(option == .darkBlue)
                return "Resource temporarily unavailable"
            }
        }

        await store.send(.appIconSelected(.darkBlue)) {
            $0.appIconStatusMessage = ""
        }

        await store.receive(
            .appIconChangeFinished(
                requestedOption: .darkBlue,
                errorMessage: "Resource temporarily unavailable"
            )
        ) {
            $0.appIconStatusMessage = "App icon update failed: Resource temporarily unavailable"
        }

        #expect(store.state.selectedAppIcon == .orange)
        #expect(SharedDefaults.app[.selectedMacAppIcon] == AppIconOption.orange.rawValue)
    }
}
