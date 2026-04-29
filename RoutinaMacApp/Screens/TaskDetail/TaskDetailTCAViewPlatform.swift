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

    func routinaCloudSharingPresenter(request: Binding<CloudSharingRequest?>) -> some View {
        background(CloudSharingPresenter(request: request).frame(width: 0, height: 0))
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
            if !store.task.isCompletedOneOff && !store.task.isCanceledOneOff {
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
            }

            macStatusSection(pauseArchivePresentation: pauseArchivePresentation)
                .background(heightReader(id: "status"))
                .frame(width: (store.task.isCompletedOneOff || store.task.isCanceledOneOff) ? nil : 320)
                .frame(
                    maxWidth: (store.task.isCompletedOneOff || store.task.isCanceledOneOff) ? .infinity : nil,
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

struct CloudSharingRequest: Identifiable {
    let id = UUID()
    let task: RoutineTask
}

private struct CloudSharingPresenter: NSViewRepresentable {
    @Binding var request: CloudSharingRequest?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let request else { return }
        DispatchQueue.main.async {
            self.request = nil
        }
        context.coordinator.present(task: request.task, from: nsView)
    }

    final class Coordinator: NSObject, NSSharingServicePickerDelegate, NSCloudSharingServiceDelegate {
        private var activePicker: NSSharingServicePicker?
        private var activeProvider: NSItemProvider?

        @MainActor
        func present(task: RoutineTask, from view: NSView) {
            let provider = NSItemProvider()
            provider.suggestedName = CloudSharingService.SharedTaskPayload(task: task).displayTitle
            provider.registerCloudKitShare { completion in
                let completionBox = MacCloudSharingCompletion(completion)
                CloudSharingService.prepareShare(for: task) { share, container, error in
                    completionBox.call(share, container, error)
                }
            }

            activeProvider = provider
            let picker = NSSharingServicePicker(items: [provider])
            picker.delegate = self
            activePicker = picker

            picker.show(
                relativeTo: view.bounds,
                of: view,
                preferredEdge: .minY
            )
        }

        func sharingServicePicker(
            _ sharingServicePicker: NSSharingServicePicker,
            delegateFor sharingService: NSSharingService
        ) -> NSSharingServiceDelegate? {
            sharingService.title == NSSharingService.Name.cloudSharing.rawValue ? self : nil
        }

        func options(
            for cloudKitSharingService: NSSharingService,
            share provider: NSItemProvider
        ) -> NSSharingService.CloudKitOptions {
            NSSharingService.CloudKitOptions(rawValue: (1 << 1) | (1 << 4))
        }

        func sharingService(
            _ sharingService: NSSharingService,
            didCompleteForItems items: [Any],
            error: Error?
        ) {
            if let error {
                NSLog("Failed to complete CloudKit sharing: \(error.localizedDescription)")
            }
            activePicker = nil
            activeProvider = nil
        }
    }
}

private final class MacCloudSharingCompletion: @unchecked Sendable {
    private let completion: (CKShare?, CKContainer?, Error?) -> Void

    init(_ completion: @escaping (CKShare?, CKContainer?, Error?) -> Void) {
        self.completion = completion
    }

    func call(_ share: CKShare?, _ container: CKContainer?, _ error: Error?) {
        completion(share, container, error)
    }
}
