import AppKit
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
