import ComposableArchitecture
import CloudKit
import SwiftUI
import UIKit

extension View {
    func routinaPlatformEditPresentation(
        isPresented: Binding<Bool>,
        store: StoreOf<TaskDetailFeature>,
        isEditEmojiPickerPresented: Binding<Bool>,
        emojiOptions: [String],
        canSaveCurrentEdit: Bool
    ) -> some View {
        sheet(isPresented: isPresented) {
            NavigationStack {
                TaskDetailEditRoutineContent(
                    store: store,
                    isEditEmojiPickerPresented: isEditEmojiPickerPresented,
                    emojiOptions: emojiOptions
                )
                .navigationTitle("Edit Task")
                .routinaInlineTitleDisplayMode()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            store.send(.setEditSheet(false))
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            store.send(.editSaveTapped)
                        }
                        .disabled(!canSaveCurrentEdit)
                    }
                }
            }
        }
    }

    func routinaPlatformCalendarCardStyle() -> some View {
        background(TaskDetailPlatformStyle.calendarCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(TaskDetailPlatformStyle.sectionCardStroke, lineWidth: 1)
            )
    }

    func routinaPlatformPrimaryActionControlSize(useLargePrimaryControl: Bool) -> some View {
        self
    }

    func routinaPlatformSecondaryActionControlSize() -> some View {
        self
    }

    func routinaPlatformPrimaryActionLabelLayout() -> some View {
        frame(maxWidth: .infinity)
    }

    func routinaPlatformPrimaryActionButtonLayout(alignment: Alignment = .center) -> some View {
        frame(maxWidth: .infinity, alignment: alignment)
    }

    func routinaPlatformSecondaryActionButtonLayout(alignment: Alignment = .center) -> some View {
        frame(maxWidth: .infinity, alignment: alignment)
    }
}

extension TaskDetailTCAView {
    var platformIsInlineEditPresented: Bool { false }

    func platformDetailOverviewSection(
        pauseArchivePresentation: RoutinePauseArchivePresentation
    ) -> some View {
        VStack(spacing: 16) {
            if !store.task.isCompletedOneOff && !store.task.isCanceledOneOff {
                calendarSection
            }
            compactStatusSection(pauseArchivePresentation: pauseArchivePresentation)
        }
    }

    func platformOpenAttachment(url: URL) {
        attachmentTempURL = url
    }
}

// MARK: - iOS share sheet modifier

extension View {
    func routinaAttachmentShareSheet(url: Binding<URL?>) -> some View {
        sheet(item: Binding(
            get: { url.wrappedValue.map { IdentifiableURL(url: $0) } },
            set: { url.wrappedValue = $0?.url }
        )) { identifiable in
            ActivityViewController(url: identifiable.url)
                .ignoresSafeArea()
        }
    }

    func routinaCloudSharingSheet(isPresented: Binding<Bool>, task: RoutineTask) -> some View {
        sheet(isPresented: isPresented) {
            CloudSharingController(task: task)
                .ignoresSafeArea()
        }
    }
}

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ActivityViewController: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct CloudSharingController: UIViewControllerRepresentable {
    let task: RoutineTask

    func makeCoordinator() -> Coordinator {
        Coordinator(task: task)
    }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController { _, completion in
            let completionBox = CloudSharingCompletion(completion)
            CloudSharingService.prepareShare(for: task) { share, container, error in
                completionBox.call(share, container, error)
            }
        }
        controller.delegate = context.coordinator
        controller.availablePermissions = UICloudSharingController.PermissionOptions(rawValue: (1 << 1) | (1 << 2))
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let title: String

        init(task: RoutineTask) {
            let payload = CloudSharingService.SharedTaskPayload(task: task)
            self.title = payload.displayTitle
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            title
        }

        func itemType(for csc: UICloudSharingController) -> String? {
            "Routina Task"
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            NSLog("Failed to save CloudKit share: \(error.localizedDescription)")
        }
    }
}

private final class CloudSharingCompletion: @unchecked Sendable {
    private let completion: (CKShare?, CKContainer?, Error?) -> Void

    init(_ completion: @escaping (CKShare?, CKContainer?, Error?) -> Void) {
        self.completion = completion
    }

    func call(_ share: CKShare?, _ container: CKContainer?, _ error: Error?) {
        completion(share, container, error)
    }
}
