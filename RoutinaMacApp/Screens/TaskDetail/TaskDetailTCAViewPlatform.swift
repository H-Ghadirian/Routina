import AppKit
import CloudKit
import ComposableArchitecture
import SwiftUI

extension View {
    func routinaPlatformEditPresentation(
        isPresented: Binding<Bool>,
        store: StoreOf<TaskDetailFeature>,
        isEditEmojiPickerPresented: Binding<Bool>,
        emojiOptions: [String],
        canSaveCurrentEdit: Bool
    ) -> some View {
        self
    }

    func routinaPlatformCalendarCardStyle() -> some View {
        self
    }

    func routinaPlatformPrimaryActionControlSize(useLargePrimaryControl: Bool) -> some View {
        controlSize(useLargePrimaryControl ? .large : .regular)
    }

    func routinaPlatformSecondaryActionControlSize() -> some View {
        controlSize(.regular)
    }

    func routinaPlatformPrimaryActionLabelLayout() -> some View {
        self
    }

    func routinaPlatformPrimaryActionButtonLayout(alignment: Alignment = .center) -> some View {
        fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    func routinaPlatformSecondaryActionButtonLayout(alignment: Alignment = .center) -> some View {
        fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    /// No-op on macOS — attachment opening is handled directly via NSWorkspace.
    func routinaAttachmentShareSheet(url: Binding<URL?>) -> some View {
        self
    }
}

extension TaskDetailTCAView {
    var platformIsInlineEditPresented: Bool { store.isEditSheetPresented }

    func platformOpenAttachment(url: URL) {
        NSWorkspace.shared.open(url)
    }

    func platformDetailOverviewSection(
        pauseArchivePresentation: RoutinePauseArchivePresentation
    ) -> some View {
        HStack(alignment: .top, spacing: 20) {
            calendarSection
                .background(heightReader(id: "calendar"))
                .frame(
                    maxWidth: .infinity,
                    minHeight: syncedMacOverviewHeight > 0 ? syncedMacOverviewHeight : nil,
                    alignment: .topLeading
                )
                .background(TaskDetailPlatformStyle.calendarCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(TaskDetailPlatformStyle.sectionCardStroke, lineWidth: 1)
                )
                .layoutPriority(1)

            macStatusSection(pauseArchivePresentation: pauseArchivePresentation)
                .background(heightReader(id: "status"))
                .frame(width: 320)
                .frame(
                    minHeight: syncedMacOverviewHeight > 0 ? syncedMacOverviewHeight : nil,
                    alignment: .topLeading
                )
                .background(TaskDetailPlatformStyle.summaryCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(TaskDetailPlatformStyle.sectionCardStroke, lineWidth: 1)
                )
        }
        .onPreferenceChange(TaskDetailOverviewHeightsPreferenceKey.self) { heights in
            let maxHeight = heights.values.max() ?? 0
            guard abs(maxHeight - syncedMacOverviewHeight) > 0.5 else { return }
            syncedMacOverviewHeight = maxHeight
        }
    }
}

struct CloudSharingToolbarButton: NSViewRepresentable {
    let task: RoutineTask

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> CloudSharingButton {
        let button = CloudSharingButton()
        button.image = NSImage(
            systemSymbolName: "person.crop.circle.badge.plus",
            accessibilityDescription: "Share"
        )
        button.imagePosition = .imageOnly
        button.bezelStyle = .toolbar
        button.isBordered = true
        button.toolTip = "Share"
        button.setButtonType(.momentaryPushIn)
        button.coordinator = context.coordinator
        return button
    }

    func updateNSView(_ button: CloudSharingButton, context: Context) {
        context.coordinator.task = task
        button.coordinator = context.coordinator
    }

    final class CloudSharingButton: NSButton {
        weak var coordinator: Coordinator?

        override func mouseDown(with event: NSEvent) {
            highlight(true)
            defer { highlight(false) }
            if let task = coordinator?.task {
                coordinator?.present(task: task, from: self)
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSSharingServicePickerDelegate, @preconcurrency NSCloudSharingServiceDelegate {
        var task: RoutineTask?
        private var activeProvider: NSItemProvider?
        private weak var activeAnchorView: NSView?
        private var activeCloudSharingService: NSSharingService?

        @MainActor
        func present(task: RoutineTask, from view: NSView) {
            activeAnchorView = view
            let coordinatorBox = MacCloudSharingCoordinator(self)
            CloudSharingService.prepareShare(for: task) { share, container, error in
                Task { @MainActor in
                    guard let coordinator = coordinatorBox.coordinator else { return }

                    if let error {
                        coordinator.presentCloudSharingErrorAlert(error, from: view)
                        coordinator.clearActiveSharingState()
                        return
                    }

                    guard let share, let container else {
                        coordinator.presentCloudSharingUnavailableAlert(from: view)
                        coordinator.clearActiveSharingState()
                        return
                    }

                    coordinator.presentPreparedShare(share, container: container, from: view)
                }
            }
        }

        @MainActor
        private func presentPreparedShare(_ share: CKShare, container: CKContainer, from view: NSView) {
            let provider = NSItemProvider()
            provider.suggestedName = share[CKShare.SystemFieldKey.title] as? String
            provider.registerCloudKitShare(share, container: container)

            activeProvider = provider
            activeAnchorView = view

            guard let cloudSharingService = NSSharingService(named: .cloudSharing) else {
                presentCloudSharingUnavailableAlert(from: view)
                clearActiveSharingState()
                return
            }

            cloudSharingService.delegate = self
            activeCloudSharingService = cloudSharingService
            cloudSharingService.perform(withItems: [provider])
        }

        func options(
            for cloudKitSharingService: NSSharingService,
            share provider: NSItemProvider
        ) -> NSSharingService.CloudKitOptions {
            NSSharingService.CloudKitOptions(rawValue: (1 << 1) | (1 << 4))
        }

        func anchoringView(
            for sharingService: NSSharingService,
            showRelativeTo positioningRect: UnsafeMutablePointer<NSRect>,
            preferredEdge: UnsafeMutablePointer<NSRectEdge>
        ) -> NSView? {
            positioningRect.pointee = activeAnchorView?.bounds ?? CGRect(x: 0, y: 0, width: 1, height: 1)
            preferredEdge.pointee = .minY
            return activeAnchorView
        }

        @MainActor
        func sharingService(
            _ sharingService: NSSharingService,
            didCompleteForItems items: [Any],
            error: Error?
        ) {
            if let error {
                NSLog("Failed to complete CloudKit sharing: \(error.localizedDescription)")
                if let activeAnchorView {
                    presentCloudSharingErrorAlert(error, from: activeAnchorView)
                }
            }
            clearActiveSharingState()
        }

        private func clearActiveSharingState() {
            activeProvider = nil
            activeAnchorView = nil
            activeCloudSharingService = nil
        }

        @MainActor
        private func presentCloudSharingUnavailableAlert(from view: NSView) {
            let alert = NSAlert()
            alert.messageText = "Cloud Sharing Unavailable"
            alert.informativeText = "macOS did not provide the Cloud Sharing service for this routine."
            alert.alertStyle = .warning
            if let window = view.window {
                alert.beginSheetModal(for: window)
            } else {
                alert.runModal()
            }
        }

        @MainActor
        private func presentCloudSharingErrorAlert(_ error: Error, from view: NSView) {
            let alert = NSAlert(error: error)
            if let window = view.window {
                alert.beginSheetModal(for: window)
            } else {
                alert.runModal()
            }
        }
    }
}

private final class MacCloudSharingCoordinator: @unchecked Sendable {
    weak var coordinator: CloudSharingToolbarButton.Coordinator?

    init(_ coordinator: CloudSharingToolbarButton.Coordinator) {
        self.coordinator = coordinator
    }
}
