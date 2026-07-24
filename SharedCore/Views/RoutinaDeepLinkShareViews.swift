import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct RoutinaDeepLinkShareMenu: View {
    enum Presentation {
        case automatic
        case plainToolbar
    }

    let title: String
    let deepLink: RoutinaDeepLink
    var presentation: Presentation = .automatic

    @ViewBuilder
    var body: some View {
        switch presentation {
        case .automatic:
            shareMenu {
                Label("Link", systemImage: "link")
            }
        case .plainToolbar:
            shareMenu {
                HStack(spacing: 5) {
                    Image(systemName: "link")
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func shareMenu<LabelContent: View>(
        @ViewBuilder label: () -> LabelContent
    ) -> some View {
        Menu {
            RoutinaDeepLinkShareActions(title: title, deepLink: deepLink)
        } label: {
            label()
        }
        .accessibilityLabel("Share link to \(title)")
        .help("Link")
    }
}

struct RoutinaDeepLinkShareActions: View {
    let title: String
    let deepLink: RoutinaDeepLink
    @State private var didCopy = false

    var body: some View {
        #if os(macOS)
        Button {
            RoutinaDeepLinkSharingPresenter.present(deepLink.url)
        } label: {
            Label("Share Link", systemImage: "square.and.arrow.up")
        }
        .accessibilityLabel("Share link to \(title)")
        #else
        ShareLink(item: deepLink.url) {
            Label("Share Link", systemImage: "square.and.arrow.up")
        }
        .accessibilityLabel("Share link to \(title)")
        #endif

        Button {
            RoutinaDeepLinkClipboard.copy(deepLink.url.absoluteString)
            didCopy = true
        } label: {
            Label(didCopy ? "Copied Link" : "Copy Link", systemImage: didCopy ? "checkmark" : "doc.on.doc")
        }
    }
}

#if os(macOS)
@MainActor
private enum RoutinaDeepLinkSharingPresenter {
    private static var activePicker: NSSharingServicePicker?

    static func present(_ url: URL) {
        // Let the lightweight Routina menu close before asking AppKit to discover
        // and present the system's sharing services.
        DispatchQueue.main.async {
            guard let window = NSApp.keyWindow ?? NSApp.mainWindow,
                  let contentView = window.contentView
            else {
                return
            }

            let picker = NSSharingServicePicker(items: [url])
            activePicker = picker

            let mousePoint = contentView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
            picker.show(
                relativeTo: NSRect(origin: mousePoint, size: .zero),
                of: contentView,
                preferredEdge: .minY
            )
        }
    }
}
#endif

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
