import AppKit

@MainActor
enum MacMenuCleanup {
    private static let rootMenusToRemove: Set<String> = [
        "File",
        "Edit",
        "View",
        "Window",
        "Help"
    ]

    private static let submenuTitlesToRemove: Set<String> = [
        "Hide Tab Bar",
        "Show Tab Bar",
        "Show All Tabs",
        "Merge All Windows",
        "Move Tab to New Window"
    ]

    private static let submenuActionsToRemove: Set<Selector> = [
        NSSelectorFromString("toggleTabBar:"),
        NSSelectorFromString("showAllTabs:"),
        NSSelectorFromString("toggleTabOverview:"),
        NSSelectorFromString("mergeAllWindows:"),
        NSSelectorFromString("moveTabToNewWindow:")
    ]

    static func removeUnneededMenus() {
        guard let mainMenu = NSApp.mainMenu else { return }

        removeRootMenus(from: mainMenu)
        removeSubmenuItems(from: mainMenu)
    }

    private static func removeRootMenus(from menu: NSMenu) {
        for item in Array(menu.items).reversed() {
            if rootMenusToRemove.contains(item.title) {
                menu.removeItem(item)
            }
        }
    }

    private static func removeSubmenuItems(from menu: NSMenu) {
        for item in Array(menu.items).reversed() {
            let matchesAction = item.action.map(submenuActionsToRemove.contains) ?? false

            if submenuTitlesToRemove.contains(item.title) || matchesAction {
                menu.removeItem(item)
                continue
            }

            if let submenu = item.submenu {
                removeSubmenuItems(from: submenu)
            }
        }
    }
}
