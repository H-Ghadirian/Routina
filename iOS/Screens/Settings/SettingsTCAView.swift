import Combine
import ComposableArchitecture
import SwiftUI

struct SettingsTCAView: View {
    let store: StoreOf<SettingsFeature>
    let ownsCompactNavigationStack: Bool

    init(
        store: StoreOf<SettingsFeature>,
        ownsCompactNavigationStack: Bool = true
    ) {
        self.store = store
        self.ownsCompactNavigationStack = ownsCompactNavigationStack
    }

    var body: some View {
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

    @ViewBuilder
    var settingsContent: some View {
        platformSettingsContent
    }
}
