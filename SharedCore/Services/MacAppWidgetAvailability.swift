import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum MacAppWidgetAvailability {
    static var isEnabled: Bool {
#if os(macOS)
        // See docs/decisions/0313-disable-mac-app-widgets-in-app-targets.md.
        // Keep widget source/targets around, but do not ship Mac widget behavior until re-enabled deliberately.
        return false
#else
        return true
#endif
    }

    @MainActor
    static func refreshOrReloadAfterPreferenceChange() {
#if os(macOS)
        guard isEnabled else { return }

        WidgetStatsService.refreshAndReload(using: PersistenceController.shared.container)
        FocusTimerWidgetService.refreshAndReload(using: PersistenceController.shared.container)
        GitHubWidgetService.reload()
        GitLabWidgetService.reload()
#endif
    }

    @MainActor
    static func reloadTimelines() {
        guard isEnabled else { return }

#if canImport(WidgetKit)
        for kind in widgetKinds {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
#endif
    }

    private static var widgetKinds: [String] {
        WidgetStatsService.reloadWidgetKinds + [
            FocusTimerWidgetService.widgetKind,
            GitHubWidgetService.widgetKind,
            GitLabWidgetService.widgetKind
        ]
    }
}
