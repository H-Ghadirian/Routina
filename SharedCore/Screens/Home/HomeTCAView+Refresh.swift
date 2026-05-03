import Combine
import CoreData
import SwiftUI

// Compiled by the app targets only. This keeps HomeTCAView from owning the
// notification fan-in directly while preserving the existing refresh throttling.
extension HomeTCAView {
    func applyHomeRefreshObservers<Content: View>(to content: Content) -> some View {
        content
            .onAppear {
                requestRefresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .routineDidUpdate)
                    .receive(on: RunLoop.main)
            ) { _ in
                requestRefresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
                    .receive(on: RunLoop.main)
            ) { _ in
                requestRefresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
                    .receive(on: RunLoop.main)
            ) { _ in
                requestRefresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: PlatformSupport.didBecomeActiveNotification)
                    .receive(on: RunLoop.main)
            ) { _ in
                requestRefresh()
            }
    }

    @MainActor
    func requestRefresh() {
        guard !isRefreshScheduled else { return }
        isRefreshScheduled = true

        Task { @MainActor in
            defer { isRefreshScheduled = false }
            await Task.yield()
            store.send(.onAppear)
        }
    }
}
