import Foundation

#if os(macOS)
    import AppKit
    import ApplicationServices

    struct MacBrowserAutomationTarget: Sendable {
        enum Kind: Sendable {
            case safari
            case chromium
        }

        let bundleIdentifier: String
        let displayName: String
        let kind: Kind

        func requestAutomationPermission() throws {
            var targetDescription = AEAddressDesc()
            let createStatus = bundleIdentifier.withCString { pointer in
                AECreateDesc(
                    DescType(typeApplicationBundleID),
                    pointer,
                    bundleIdentifier.utf8.count,
                    &targetDescription
                )
            }
            guard createStatus == noErr else {
                throw MacBrowserAutomationError(
                    message: "Could not prepare the Automation permission request (\(createStatus))."
                )
            }
            defer {
                AEDisposeDesc(&targetDescription)
            }

            let permissionStatus = AEDeterminePermissionToAutomateTarget(
                &targetDescription,
                typeWildCard,
                typeWildCard,
                true
            )
            switch permissionStatus {
            case noErr:
                return
            case OSStatus(errAEEventNotPermitted):
                throw MacBrowserAutomationError(
                    message: "Automation permission is denied. Allow Routina under System Settings > Privacy & Security > Automation."
                )
            case OSStatus(errAEEventWouldRequireUserConsent):
                throw MacBrowserAutomationError(
                    message: "Automation permission is needed, but macOS did not show the permission prompt."
                )
            case -600:
                throw MacBrowserAutomationError(
                    message: "Browser automation target is not available.",
                    isTransient: true
                )
            default:
                throw MacBrowserAutomationError(
                    message: "Automation permission check failed (\(permissionStatus))."
                )
            }
        }

        func blockedTabs(against domains: [BlockingWebsiteDomain]) throws -> [MacBrowserTabReference] {
            try tabReferences().filter { tab in
                FocusShieldSupport.shouldBlockWebsiteURL(tab.url, against: domains)
            }
        }

        private func tabReferences() throws -> [MacBrowserTabReference] {
            let script: String
            switch kind {
            case .safari:
                script = """
                    tell application id "\(bundleIdentifier)"
                        if (count of windows) is 0 then return ""
                        set separator to character id 9
                        set oldDelimiters to AppleScript's text item delimiters
                        set tabRows to {}
                        repeat with windowIndex from 1 to count of windows
                            repeat with tabIndex from 1 to count of tabs of window windowIndex
                                set tabURL to URL of tab tabIndex of window windowIndex
                                if tabURL is not "" then
                                    set end of tabRows to (windowIndex as text) & separator & (tabIndex as text) & separator & tabURL
                                end if
                            end repeat
                        end repeat
                        set AppleScript's text item delimiters to linefeed
                        set rowText to tabRows as text
                        set AppleScript's text item delimiters to oldDelimiters
                        return rowText
                    end tell
                    """
            case .chromium:
                script = """
                    tell application id "\(bundleIdentifier)"
                        if (count of windows) is 0 then return ""
                        set separator to character id 9
                        set oldDelimiters to AppleScript's text item delimiters
                        set tabRows to {}
                        repeat with windowIndex from 1 to count of windows
                            repeat with tabIndex from 1 to count of tabs of window windowIndex
                                set tabURL to URL of tab tabIndex of window windowIndex
                                if tabURL is not "" then
                                    set end of tabRows to (windowIndex as text) & separator & (tabIndex as text) & separator & tabURL
                                end if
                            end repeat
                        end repeat
                        set AppleScript's text item delimiters to linefeed
                        set rowText to tabRows as text
                        set AppleScript's text item delimiters to oldDelimiters
                        return rowText
                    end tell
                    """
            }

            let value = try runAppleScript(script)
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmed.isEmpty else { return [] }

            return
                trimmed
                .split(separator: "\n", omittingEmptySubsequences: true)
                .compactMap { line in
                    let parts = line.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
                    guard parts.count == 3,
                        let windowIndex = Int(parts[0]),
                        let tabIndex = Int(parts[1])
                    else {
                        return nil
                    }

                    let url = String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !url.isEmpty else { return nil }
                    return MacBrowserTabReference(windowIndex: windowIndex, tabIndex: tabIndex, url: url)
                }
        }

        func redirectTabsToBlank(_ tabs: [MacBrowserTabReference]) throws {
            guard !tabs.isEmpty else { return }

            let commands = tabs.map { tab in
                """
                if (count of windows) >= \(tab.windowIndex) and (count of tabs of window \(tab.windowIndex)) >= \(tab.tabIndex) then
                    set URL of tab \(tab.tabIndex) of window \(tab.windowIndex) to "about:blank"
                end if
                """
            }
            .joined(separator: "\n")

            let script: String
            switch kind {
            case .safari:
                script = """
                    tell application id "\(bundleIdentifier)"
                        \(commands)
                    end tell
                    """
            case .chromium:
                script = """
                    tell application id "\(bundleIdentifier)"
                        \(commands)
                    end tell
                    """
            }

            _ = try runAppleScript(script)
        }

        private func runAppleScript(_ source: String) throws -> String? {
            var errorInfo: NSDictionary?
            guard let script = NSAppleScript(source: source) else {
                throw MacBrowserAutomationError(message: "Could not create browser automation script.")
            }

            let result = script.executeAndReturnError(&errorInfo)
            if let errorInfo {
                if let errorNumber = errorInfo[NSAppleScript.errorNumber] as? NSNumber,
                    errorNumber.int32Value == -600
                {
                    throw MacBrowserAutomationError(
                        message: "Browser automation target is not available.",
                        isTransient: true
                    )
                }

                let message =
                    errorInfo[NSAppleScript.errorMessage] as? String
                    ?? "Browser automation was not allowed."
                if message.localizedCaseInsensitiveContains("isn't running")
                    || message.localizedCaseInsensitiveContains("not running")
                {
                    throw MacBrowserAutomationError(message: message, isTransient: true)
                }
                throw MacBrowserAutomationError(message: message)
            }

            return result.stringValue
        }
    }

    struct MacBrowserTabReference: Equatable {
        var windowIndex: Int
        var tabIndex: Int
        var url: String
    }

    struct MacBrowserAutomationError: LocalizedError {
        var message: String
        var isTransient = false

        var errorDescription: String? {
            message
        }
    }
#endif
