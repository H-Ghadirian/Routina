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

    private enum PlainToolbarMetrics {
        static let controlWidth: CGFloat = 42
        static let controlHeight: CGFloat = 34
        static let cornerRadius: CGFloat = 8
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
                .frame(width: PlainToolbarMetrics.controlWidth, height: PlainToolbarMetrics.controlHeight)
                .background(
                    RoundedRectangle(cornerRadius: PlainToolbarMetrics.cornerRadius, style: .continuous)
                        .fill(Color.secondary.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PlainToolbarMetrics.cornerRadius, style: .continuous)
                        .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: PlainToolbarMetrics.cornerRadius, style: .continuous))
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
