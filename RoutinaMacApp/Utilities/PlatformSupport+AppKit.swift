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
        if openWithAppleMailIfNeeded(for: url) {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @MainActor
    static func selectRoutineDataExportURL(suggestedFileName: String) async -> URL? {
        let panel = NSSavePanel()
        panel.title = "Save Routine Data"
        panel.prompt = "Save"
        panel.nameFieldStringValue = suggestedFileName
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.json]
        panel.isExtensionHidden = false

        return await presentDataTransferPanel(panel)
    }

    @MainActor
    static func selectRoutineDataImportURL() async -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Load Routine Data"
        panel.prompt = "Load"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.json]

        return await presentDataTransferPanel(panel)
    }

    @MainActor
    static func applyAppIcon(_ option: AppIconOption) {
        guard let image = NSImage(named: option.assetName) else {
            NSLog("Missing app icon asset named '\(option.assetName)'")
            return
        }
        NSApplication.shared.applicationIconImage = image
    }

    @MainActor
    static func requestAppIconChange(to option: AppIconOption) async -> String? {
        applyAppIcon(option)
        return nil
    }

    @MainActor
    private static func presentDataTransferPanel(_ panel: NSSavePanel) async -> URL? {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else {
            return panel.runModal() == .OK ? panel.url : nil
        }

        return await withCheckedContinuation { continuation in
            panel.beginSheetModal(for: window) { response in
                continuation.resume(returning: response == .OK ? panel.url : nil)
            }
        }
    }

    @MainActor
    private static func openWithAppleMailIfNeeded(for url: URL) -> Bool {
        guard url.scheme?.lowercased() == "mailto",
              let mailAppURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.mail")
        else {
            return false
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([url], withApplicationAt: mailAppURL, configuration: configuration)
        return true
    }
}

extension View {
    func routinaInlineTitleDisplayMode() -> some View {
        self
    }
}
#endif
