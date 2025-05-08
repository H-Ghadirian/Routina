import Combine
import ComposableArchitecture
import SwiftUI

struct SettingsTCAView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            settingsContent
                .onAppear {
                    store.send(.onAppear)
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: PlatformSupport.didBecomeActiveNotification)
                        .receive(on: RunLoop.main)
                ) { _ in
                    store.send(.onAppBecameActive)
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: CloudKitSyncDiagnostics.didUpdateNotification)
                        .receive(on: RunLoop.main)
                ) { _ in
                    store.send(.cloudDiagnosticsUpdated)
                }
        }
    }

    @ViewBuilder
    var settingsContent: some View {
        platformSettingsContent
    }
}
