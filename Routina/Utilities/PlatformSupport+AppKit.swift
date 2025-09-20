#if canImport(AppKit)
import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension PlatformSupport {
    static var didBecomeActiveNotification: Notification.Name {
        NSApplication.didBecomeActiveNotification
    }

    static var notificationSettingsURL: URL? {
        URL(string: "x-apple.systempreferences:com.apple.preference.notifications")
    }

    @MainActor
    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    @MainActor
    static func selectRoutineDataExportURL(suggestedFileName: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = "Save Routine Data"
        panel.prompt = "Save"
        panel.nameFieldStringValue = suggestedFileName
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.json]
        panel.isExtensionHidden = false

        return panel.runModal() == .OK ? panel.url : nil
    }

    @MainActor
    static func selectRoutineDataImportURL() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Load Routine Data"
        panel.prompt = "Load"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.json]

        return panel.runModal() == .OK ? panel.url : nil
    }
}

extension View {
    func routinaInlineTitleDisplayMode() -> some View {
        self
    }
}
#endif
