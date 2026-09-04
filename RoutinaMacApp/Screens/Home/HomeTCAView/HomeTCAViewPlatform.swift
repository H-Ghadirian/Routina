import AppKit
import Combine
import ComposableArchitecture
import Foundation
import MapKit
import SwiftUI

enum HomeMacSearchPresentationPolicy {
    static let inputDebounce: Duration = .milliseconds(120)
}

enum HomeSidebarSizing {
    static let minWidth: CGFloat = 220
    static let idealWidth: CGFloat = 300
    static let maxWidth: CGFloat = 360
}

extension View {
    func routinaHomeSidebarColumnWidth() -> some View {
        navigationSplitViewColumnWidth(
            min: HomeSidebarSizing.minWidth,
            ideal: HomeSidebarSizing.idealWidth,
            max: HomeSidebarSizing.maxWidth
        )
        .routinaHomeSidebarSplitViewConstraints()
    }

    func routinaHomeSidebarSplitViewConstraints() -> some View {
        self.background(
            HomeMacSidebarSplitViewConfigurator(
                minimumWidth: HomeSidebarSizing.minWidth,
                maximumWidth: HomeSidebarSizing.maxWidth
            )
        )
    }
}

struct HomeMacSidebarSplitViewConfigurator: NSViewRepresentable {
    let minimumWidth: CGFloat
    let maximumWidth: CGFloat

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard
                let splitView = nsView.routinaHomeEnclosingSplitView,
                let splitViewController = splitView.delegate as? NSSplitViewController,
                let sidebarItem = splitViewController.splitViewItems.first
            else {
                return
            }

            sidebarItem.canCollapse = true
            sidebarItem.canCollapseFromWindowResize = false
            sidebarItem.minimumThickness = minimumWidth
            sidebarItem.maximumThickness = maximumWidth
            sidebarItem.holdingPriority = .defaultHigh
            splitViewController.minimumThicknessForInlineSidebars = minimumWidth

            guard
                !sidebarItem.isCollapsed,
                splitView.subviews.count > 1,
                let sidebarView = splitView.subviews.first,
                sidebarView.frame.width > 1
            else {
                return
            }

            let clampedWidth = min(max(sidebarView.frame.width, minimumWidth), maximumWidth)
            guard sidebarView.frame.width != clampedWidth else { return }

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0
                context.allowsImplicitAnimation = false
                splitView.setPosition(clampedWidth, ofDividerAt: 0)
                splitView.layoutSubtreeIfNeeded()
            }
        }
    }
}

extension NSView {
    var routinaHomeEnclosingSplitView: NSSplitView? {
        sequence(first: superview, next: { $0?.superview })
            .compactMap { $0 as? NSSplitView }
            .first
    }
}

struct HomeBacklogCreationDestination: Identifiable {
    let id: UUID
    let title: String
}
