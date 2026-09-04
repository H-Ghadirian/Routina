import SwiftUI

extension TaskRankingMacView {
    @ViewBuilder
    func taskRankingControlsPresentation<Workspace: View>(
        @ViewBuilder workspace: @escaping () -> Workspace
    ) -> some View {
        if isControlsPresented && isControlsFullscreen {
            fullscreenControlsContent
        } else {
            GeometryReader { proxy in
                let controlsWidth =
                    isControlsPresented
                    ? MacDetailContainerSizing.filterDetailPaneWidth
                    : 0
                let workspaceWidth = max(proxy.size.width - controlsWidth, 0)

                HStack(spacing: 0) {
                    workspace()
                        .frame(width: workspaceWidth)
                        .frame(maxHeight: .infinity)
                        .clipped()

                    if isControlsPresented {
                        controlsPane
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
                .clipped()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(MacHomeDetailAnimation.secondaryPane, value: isControlsPresented)
        }
    }

    private var controlsPane: some View {
        VStack(spacing: 0) {
            controlsHeader(showsFullscreenAction: true)
            Divider()
            controlsDetail
        }
        .frame(width: MacDetailContainerSizing.filterDetailPaneWidth)
        .frame(maxHeight: .infinity)
        .background(Color.secondary.opacity(0.045), ignoresSafeAreaEdges: [])
        .overlay(alignment: .leading) {
            Divider()
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
        .zIndex(1)
    }

    private var fullscreenControlsContent: some View {
        VStack(spacing: 0) {
            controlsHeader(showsFullscreenAction: false)
            Divider()
            controlsDetail
                .frame(
                    maxWidth: MacDetailContainerSizing.fullscreenFilterContentMaxWidth,
                    maxHeight: .infinity,
                    alignment: .top
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var controlsDetail: some View {
        TaskRankingMacControlsDetailView(
            store: store,
            initialTab: initialControlsTab,
            onNewContainerGroup: {
                groupEditorPresentation = TaskLadderGroupEditorPresentation(group: nil)
            },
            onUseRepeatingTaskAsGroup: {
                repeatingTaskGroupParentID = nil
                isRepeatingTaskGroupEditorPresented = true
            }
        )
    }

    private func controlsHeader(showsFullscreenAction: Bool) -> some View {
        HStack(spacing: 10) {
            Label(
                "View, Sort, and Appearance",
                systemImage: "slider.horizontal.3"
            )
            .font(.headline)
            .lineLimit(1)

            Spacer(minLength: 8)

            controlsHeaderButton(
                systemName: showsFullscreenAction
                    ? "arrow.up.left.and.arrow.down.right"
                    : "arrow.down.right.and.arrow.up.left",
                title: showsFullscreenAction ? "Open Fullscreen" : "Minimize",
                action: showsFullscreenAction ? onExpandControls : onMinimizeControls
            )

            controlsHeaderButton(
                systemName: "xmark",
                title: "Close",
                action: onCloseControls
            )
        }
        .padding(.horizontal, showsFullscreenAction ? 14 : 20)
        .padding(.vertical, showsFullscreenAction ? 10 : 12)
    }

    private func controlsHeaderButton(
        systemName: String,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.secondary)
                .frame(width: 30, height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                }
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .help(title)
    }
}
