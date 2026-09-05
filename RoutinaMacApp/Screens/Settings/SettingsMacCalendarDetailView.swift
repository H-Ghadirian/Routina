import ComposableArchitecture
import SwiftData
import SwiftUI

struct SettingsMacCalendarDetailView: View {
    let store: StoreOf<SettingsFeature>
    @Query private var existingTasks: [RoutineTask]
    @State private var isCalendarTaskImportPresented = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingDayPlanCalendarListAssumedDoneCollapsedByDefault.rawValue,
        store: SharedDefaults.app
    ) private var areCalendarListTaskSectionsCollapsedByDefault = true

    var body: some View {
        SettingsMacDetailShell(
            title: "Calendar",
            subtitle: "Review calendar events before adding tasks and choose how dates are displayed."
        ) {
            SettingsMacDetailCard(title: "Calendar Tasks") {
                Button {
                    isCalendarTaskImportPresented = true
                } label: {
                    Label("Review Calendar Tasks", systemImage: "calendar.badge.plus")
                }
                .buttonStyle(.borderedProminent)

                Text("Review calendar events one by one before adding them as tasks.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            SettingsMacDetailCard(title: "Planner Calendar") {
                Toggle("Show timeline tasks automatically in planner", isOn: showTimelineTasksInDayPlannerBinding)
                    .toggleStyle(.switch)

                Text("When off, planner dates show a timeline badge that opens the activity list instead.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            SettingsMacDetailCard(title: "Calendar List") {
                Picker("Task sections default", selection: $areCalendarListTaskSectionsCollapsedByDefault) {
                    Text("Collapsed").tag(true)
                    Text("Expanded").tag(false)
                }
                .pickerStyle(.segmented)

                Text(
                    """
                    Newly shown Planned tasks, Assumed done, Confirmed assumed done, and Done sections use this state. \
                    You can still open or collapse each section for a day directly in Calendar List.
                    """
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            SettingsMacDetailCard(title: "Date Display") {
                Toggle("Show Persian date beside dates", isOn: showPersianDatesBinding)
                    .toggleStyle(.switch)

                if store.appearance.showPersianDates {
                    Text(persianDatePreviewText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Text(
                    """
                    Keeps the app schedule unchanged and adds a Persian calendar date next to visible Gregorian dates.
                    """
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $isCalendarTaskImportPresented) {
            CalendarTaskImportSheet(existingTasks: existingTasks) {}
        }
    }

    private var showPersianDatesBinding: Binding<Bool> {
        Binding(
            get: { store.appearance.showPersianDates },
            set: { store.send(.showPersianDatesToggled($0)) }
        )
    }

    private var showTimelineTasksInDayPlannerBinding: Binding<Bool> {
        Binding(
            get: { store.appearance.showsTimelineTasksInDayPlanner },
            set: { store.send(.showTimelineTasksInDayPlannerToggled($0)) }
        )
    }

    private var persianDatePreviewText: String {
        let today = Date()
        let dateText = today.formatted(date: .abbreviated, time: .omitted)
        return "Today: "
            + PersianDateDisplay.appendingSupplementaryDate(
                to: dateText,
                for: today,
                enabled: true
            )
    }
}
