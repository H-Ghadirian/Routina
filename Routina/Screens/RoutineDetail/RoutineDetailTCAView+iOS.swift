import ComposableArchitecture
import SwiftUI

extension View {
    func routinaPlatformEditPresentation(
        isPresented: Binding<Bool>,
        store: StoreOf<RoutineDetailFeature>,
        isEditEmojiPickerPresented: Binding<Bool>,
        emojiOptions: [String],
        canSaveCurrentEdit: Bool
    ) -> some View {
        sheet(isPresented: isPresented) {
            NavigationStack {
                RoutineDetailEditRoutineContent(
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
        background(RoutineDetailPlatformStyle.calendarCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(RoutineDetailPlatformStyle.sectionCardStroke, lineWidth: 1)
            )
    }

    func routinaPlatformPrimaryActionControlSize(useLargePrimaryControl: Bool) -> some View {
        self
    }

    func routinaPlatformSecondaryActionControlSize() -> some View {
        self
    }
}

extension RoutineDetailTCAView {
    var platformIsInlineEditPresented: Bool { false }

    func platformDetailOverviewSection(
        pauseArchivePresentation: RoutinePauseArchivePresentation
    ) -> some View {
        VStack(spacing: 16) {
            calendarSection
            compactStatusSection(pauseArchivePresentation: pauseArchivePresentation)
        }
    }
}
