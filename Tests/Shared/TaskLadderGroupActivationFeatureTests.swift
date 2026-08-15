import ComposableArchitecture
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@MainActor
struct TaskLadderGroupActivationFeatureTests {
    @Test
    func taskDetailsActivationPersistsImmediatelyWhileEditActivationRemainsDrafted() async {
        let task = RoutineTask(name: "Exercise", scheduleMode: .fixedInterval)
        let storedOrganization = LockIsolated(TaskLadderOrganization())
        var appSettingsClient = AppSettingsClient.noop
        appSettingsClient.taskLadderOrganization = { storedOrganization.value }
        appSettingsClient.setTaskLadderOrganization = { organization in
            storedOrganization.setValue(organization)
        }
        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
        } withDependencies: {
            $0.appSettingsClient = appSettingsClient
        }

        await store.send(.taskLadderGroupEnabledChanged(true)) {
            $0.taskLadderGroupEnabled = true
            $0.editTaskLadderGroupEnabled = true
        }
        #expect(storedOrganization.value.isExplicitTaskGroup(taskID: task.id))

        await store.send(.editTaskLadderGroupEnabledChanged(false)) {
            $0.editTaskLadderGroupEnabled = false
        }
        #expect(storedOrganization.value.isExplicitTaskGroup(taskID: task.id))
    }
}
