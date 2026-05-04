import SwiftUI

extension AddRoutineTCAView {
    var routineNameBinding: Binding<String> {
        Binding(
            get: { store.basics.routineName },
            set: { store.send(.routineNameChanged($0)) }
        )
    }

    var routineEmojiBinding: Binding<String> {
        Binding(
            get: { store.basics.routineEmoji },
            set: { store.send(.routineEmojiChanged($0)) }
        )
    }

    var routineNotesBinding: Binding<String> {
        Binding(
            get: { store.basics.routineNotes },
            set: { store.send(.routineNotesChanged($0)) }
        )
    }

    var routineLinkBinding: Binding<String> {
        Binding(
            get: { store.basics.routineLink },
            set: { store.send(.routineLinkChanged($0)) }
        )
    }

    var taskTypeBinding: Binding<RoutineTaskType> {
        Binding(
            get: { store.taskType },
            set: { store.send(.taskTypeChanged($0)) }
        )
    }

    var tagDraftBinding: Binding<String> {
        Binding(
            get: { store.organization.tagDraft },
            set: { store.send(.tagDraftChanged($0)) }
        )
    }

    var goalDraftBinding: Binding<String> {
        Binding(
            get: { store.organization.goalDraft },
            set: { store.send(.goalDraftChanged($0)) }
        )
    }

    var stepDraftBinding: Binding<String> {
        Binding(
            get: { store.checklist.stepDraft },
            set: { store.send(.stepDraftChanged($0)) }
        )
    }

    var checklistItemDraftTitleBinding: Binding<String> {
        Binding(
            get: { store.checklist.checklistItemDraftTitle },
            set: { store.send(.checklistItemDraftTitleChanged($0)) }
        )
    }

    var checklistItemDraftIntervalBinding: Binding<Int> {
        Binding(
            get: { store.checklist.checklistItemDraftInterval },
            set: { store.send(.checklistItemDraftIntervalChanged($0)) }
        )
    }

    var scheduleModeBinding: Binding<RoutineScheduleMode> {
        Binding(
            get: { store.schedule.scheduleMode },
            set: { store.send(.scheduleModeChanged($0)) }
        )
    }

    var frequencyBinding: Binding<AddRoutineFeature.Frequency> {
        Binding(
            get: { store.schedule.frequency },
            set: { store.send(.frequencyChanged($0)) }
        )
    }

    var frequencyValueBinding: Binding<Int> {
        Binding(
            get: { store.schedule.frequencyValue },
            set: { store.send(.frequencyValueChanged($0)) }
        )
    }

    var recurrenceKindBinding: Binding<RoutineRecurrenceRule.Kind> {
        Binding(
            get: { store.schedule.recurrenceKind },
            set: { store.send(.recurrenceKindChanged($0)) }
        )
    }

    var recurrenceTimeBinding: Binding<Date> {
        Binding(
            get: { store.schedule.recurrenceTimeOfDay.date(on: Date()) },
            set: { store.send(.recurrenceTimeOfDayChanged(RoutineTimeOfDay.from($0))) }
        )
    }

    var recurrenceWeekdayBinding: Binding<Int> {
        Binding(
            get: { store.schedule.recurrenceWeekday },
            set: { store.send(.recurrenceWeekdayChanged($0)) }
        )
    }

    var recurrenceDayOfMonthBinding: Binding<Int> {
        Binding(
            get: { store.schedule.recurrenceDayOfMonth },
            set: { store.send(.recurrenceDayOfMonthChanged($0)) }
        )
    }

    var selectedPlaceBinding: Binding<UUID?> {
        Binding(
            get: { store.basics.selectedPlaceID },
            set: { store.send(.selectedPlaceChanged($0)) }
        )
    }

    var deadlineEnabledBinding: Binding<Bool> {
        Binding(
            get: { store.hasDeadline },
            set: { store.send(.deadlineEnabledChanged($0)) }
        )
    }

    var deadlineBinding: Binding<Date> {
        Binding(
            get: { store.basics.deadline ?? Date() },
            set: { store.send(.deadlineDateChanged($0)) }
        )
    }

    var importanceBinding: Binding<RoutineTaskImportance> {
        Binding(
            get: { store.basics.importance },
            set: { store.send(.importanceChanged($0)) }
        )
    }

    var urgencyBinding: Binding<RoutineTaskUrgency> {
        Binding(
            get: { store.basics.urgency },
            set: { store.send(.urgencyChanged($0)) }
        )
    }
}
