import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct RoutinaDeepLinkShareMenu: View {
    let title: String
    let deepLink: RoutinaDeepLink

    var body: some View {
        Menu {
            RoutinaDeepLinkShareActions(title: title, deepLink: deepLink)
        } label: {
            Label("Link", systemImage: "link")
        }
        .accessibilityLabel("Share link to \(title)")
    }
}

struct RoutinaDeepLinkShareActions: View {
    let title: String
    let deepLink: RoutinaDeepLink
    @State private var didCopy = false

    var body: some View {
        ShareLink(item: deepLink.url) {
            Label("Share Link", systemImage: "square.and.arrow.up")
        }
        .accessibilityLabel("Share link to \(title)")

        Button {
            RoutinaDeepLinkClipboard.copy(deepLink.url.absoluteString)
            didCopy = true
        } label: {
            Label(didCopy ? "Copied Link" : "Copy Link", systemImage: didCopy ? "checkmark" : "doc.on.doc")
        }
    }
}

enum RoutinaDeepLinkClipboard {
    static func copy(_ value: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = value
        #endif
    }
}
