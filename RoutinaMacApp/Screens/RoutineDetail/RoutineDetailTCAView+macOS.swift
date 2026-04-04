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
}

extension RoutineDetailTCAView {
    var platformIsInlineEditPresented: Bool { store.isEditSheetPresented }

    func platformDetailOverviewSection(
        pauseArchivePresentation: RoutinePauseArchivePresentation
    ) -> some View {
        HStack(alignment: .top, spacing: 20) {
            if !store.task.isCompletedOneOff {
                calendarSection
                    .background(heightReader(id: "calendar"))
                    .frame(
                        maxWidth: .infinity,
                        minHeight: syncedMacOverviewHeight > 0 ? syncedMacOverviewHeight : nil,
                        alignment: .topLeading
                    )
                    .background(RoutineDetailPlatformStyle.calendarCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(RoutineDetailPlatformStyle.sectionCardStroke, lineWidth: 1)
                    )
                    .layoutPriority(1)
            }

            macStatusSection(pauseArchivePresentation: pauseArchivePresentation)
                .background(heightReader(id: "status"))
                .frame(width: store.task.isCompletedOneOff ? nil : 320)
                .frame(
                    maxWidth: store.task.isCompletedOneOff ? .infinity : nil,
                    minHeight: syncedMacOverviewHeight > 0 ? syncedMacOverviewHeight : nil,
                    alignment: .topLeading
                )
                .background(RoutineDetailPlatformStyle.summaryCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(RoutineDetailPlatformStyle.sectionCardStroke, lineWidth: 1)
                )
        }
        .onPreferenceChange(RoutineDetailOverviewHeightsPreferenceKey.self) { heights in
            let maxHeight = heights.values.max() ?? 0
            guard abs(maxHeight - syncedMacOverviewHeight) > 0.5 else { return }
            syncedMacOverviewHeight = maxHeight
        }
    }
}
