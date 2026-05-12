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
        routinaGlassCard(cornerRadius: 12, tint: .secondary, tintOpacity: 0.06)
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
            calendarSection
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

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let payload = CloudSharingService.SharedTaskPayload(task: task)
        let itemProvider = NSItemProvider(object: context.coordinator.title as NSString)

        if let containerIdentifier = AppEnvironment.cloudKitContainerIdentifier {
            let container = CKContainer(identifier: containerIdentifier)
            let allowedOptions = CKAllowedSharingOptions(
                allowedParticipantPermissionOptions: .readOnly,
                allowedParticipantAccessOptions: .specifiedRecipientsOnly
            )

            itemProvider.registerCKShare(
                container: container,
                allowedSharingOptions: allowedOptions
            ) {
                try await CloudSharingService.prepareShare(payload: payload, in: container)
            }
        }

        let configuration = UIActivityItemsConfiguration(itemProviders: [itemProvider])
        configuration.metadataProvider = { key in
            key == .title ? context.coordinator.title : nil
        }

        return UIActivityViewController(activityItemsConfiguration: configuration)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}

    final class Coordinator {
        let title: String

        init(task: RoutineTask) {
            let payload = CloudSharingService.SharedTaskPayload(task: task)
            self.title = payload.displayTitle
        }
    }
}
