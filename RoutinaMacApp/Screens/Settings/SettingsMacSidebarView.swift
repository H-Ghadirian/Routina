import AppKit
import ComposableArchitecture
import SwiftUI

struct SettingsMacSidebarRow: View {
    let section: SettingsMacSection
    let store: StoreOf<SettingsFeature>

    var body: some View {
        WithPerceptionTracking {
            HStack(spacing: 12) {
                SettingsSectionGlyphView(icon: section.icon, tint: section.tint)

                VStack(alignment: .leading, spacing: 3) {
                    Text(section.title)
                        .foregroundStyle(.primary)

                    Text(presentation.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                if let value = presentation.value, !value.isEmpty {
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var presentation: SettingsSectionRowPresentation {
        section.rowPresentation(in: store.state)
    }
}

struct SettingsMacSidebarSplitViewConfigurator: NSViewRepresentable {
    let minimumWidth: CGFloat

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard
                let splitView = nsView.enclosingSplitView,
                let splitViewController = splitView.delegate as? NSSplitViewController,
                let sidebarItem = splitViewController.splitViewItems.first
            else {
                return
            }

            sidebarItem.canCollapse = false
            sidebarItem.canCollapseFromWindowResize = false
            sidebarItem.minimumThickness = minimumWidth
            sidebarItem.holdingPriority = .defaultHigh
            splitViewController.minimumThicknessForInlineSidebars = minimumWidth

            guard
                splitView.subviews.count > 1,
                let sidebarView = splitView.subviews.first,
                sidebarView.frame.width < minimumWidth
            else {
                return
            }

            splitView.setPosition(minimumWidth, ofDividerAt: 0)
        }
    }
}

private extension NSView {
    var enclosingSplitView: NSSplitView? {
        sequence(first: superview, next: { $0?.superview })
            .compactMap { $0 as? NSSplitView }
            .first
    }
}
