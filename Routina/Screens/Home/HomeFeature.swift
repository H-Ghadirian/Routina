import ComposableArchitecture
import CoreData
import Foundation

@Reducer
struct HomeFeature {
    struct State: Equatable {
        var routineTasks: [RoutineTask] = []
        var isAddRoutineSheetPresented: Bool = false
        var addRoutineState: AddRoutineFeature.State? = nil
    }
    
    enum Action: Equatable {
        case markAsDone
        case loadTasks([RoutineTask])
        case onAppear
        case setAddRoutineSheet(Bool)
        case addRoutineSheet(AddRoutineFeature.Action)
    }

    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.managedObjectContext) var viewContext
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .markAsDone:
                return .none
                
            case .loadTasks(let tasks):
                state.routineTasks = tasks
                return .none
                
            case .onAppear:
                return handleOnAppear()
            case let .setAddRoutineSheet(isPresented):
                state.isAddRoutineSheetPresented = isPresented
                if isPresented {
                    state.addRoutineState = AddRoutineFeature.State()
                } else {
                    state.addRoutineState = nil
                }
                return .none
            case .addRoutineSheet(let childAction):
                switch childAction {
                case .delegate(.didCancel):
                    state.isAddRoutineSheetPresented = false
                    state.addRoutineState = nil
                    return .none

                case let .delegate(.didSave(name, freq)):
                    state.isAddRoutineSheetPresented = false
                    state.addRoutineState = nil

                    let context = PersistenceController.shared.container.viewContext
                    let newRoutine = RoutineTask(context: context)
                    newRoutine.name = name
                    newRoutine.interval = Int16(freq)
                    newRoutine.lastDone = Date()

                    do {
                        try context.save()
                        let tasks = try context.fetch(NSFetchRequest<RoutineTask>(entityName: "RoutineTask"))
                        state.routineTasks = tasks
                        print("✅ Saved routine: \(name), every \(freq) day(s)")
                        return .run { _ in
                            await notificationClient.schedule(newRoutine)
                        }
                    } catch {
                        print("❌ Failed to save routine: \(error.localizedDescription)")
                        return .none
                    }

                default:
                    return .none
                }
            }
        }
        .ifLet(\.addRoutineState, action: \.addRoutineSheet) {
            AddRoutineFeature(
                onSave: { name, freq in
                    .send(.delegate(.didSave(name, freq)))
                },
                onCancel: {
                    .send(.delegate(.didCancel))
                }
            )
        }
    }

    func handleOnAppear() -> Effect<Action> {
        let request = NSFetchRequest<RoutineTask>(entityName: "RoutineTask")
        request.sortDescriptors = []
        do {
            let tasks = try viewContext.fetch(request)
            return .send(.loadTasks(tasks))
        } catch {
            print("❌ Failed to fetch RoutineTasks: \(error.localizedDescription)")
            return .none
        }
    }
}
