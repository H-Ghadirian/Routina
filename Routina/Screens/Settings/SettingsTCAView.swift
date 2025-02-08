import ComposableArchitecture
import SwiftUI

struct SettingsTCAView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            Form {
                Section {
                    Toggle("Enable notifications", isOn: viewStore.binding(
                        get: \.notificationsEnabled,
                        send: SettingsFeature.Action.toggleNotifications
                    ))
                }

                Section {
                    Button("Open app settings") {
                        viewStore.send(.openAppSettingsTapped)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
