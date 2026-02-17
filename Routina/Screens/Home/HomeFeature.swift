import ComposableArchitecture
import CoreData
import Foundation

@Reducer
struct HomeFeature {
    struct State: Equatable {
        var routineTasks: [RoutineTask] = []
        var isAddRoutineSheetPresented: Bool = false
        var addRoutineState: AddRoutineFeature.State?
    }
    
    // Actions are now explicit for success and failure, making them Equatable.
    enum Action: Equatable {
        case onAppear
        case tasksLoadedSuccessfully([RoutineTask])
        case tasksLoadFailed
        
        case setAddRoutineSheet(Bool)
        case deleteTask(IndexSet)
        
        case addRoutineSheet(AddRoutineFeature.Action)
        case routineSavedSuccessfully(RoutineTask)
        case routineSaveFailed
    }

    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.managedObjectContext) var viewContext
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            
            // MARK: - Core Logic & Effects
            case .onAppear:
                return .run { send in
                    do {
                        let tasks = try await MainActor.run {
                            let request = NSFetchRequest<RoutineTask>(entityName: "RoutineTask")
                            request.sortDescriptors = []
                            return try self.viewContext.fetch(request)
                        }
                        await send(.tasksLoadedSuccessfully(tasks))
                    } catch {
                        await send(.tasksLoadFailed)
                    }
                }
                
            case let .tasksLoadedSuccessfully(tasks):
                state.routineTasks = tasks
                return .none
            
            case .tasksLoadFailed:
                print("❌ Failed to load tasks.")
                // You could set an error state here to show an alert.
                return .none
                
            case let .setAddRoutineSheet(isPresented):
                state.isAddRoutineSheetPresented = isPresented
                state.addRoutineState = isPresented ? AddRoutineFeature.State() : nil
                return .none
                
            case let .deleteTask(offsets):
                let tasksToDelete = offsets.map { state.routineTasks[$0] }
                state.routineTasks.remove(atOffsets: offsets)
                
                return .run { [tasksToDelete] _ in
                    await MainActor.run {
                        for task in tasksToDelete {
                            self.viewContext.delete(task)
                        }
                        try? self.viewContext.save()
                    }
                }
                
            // MARK: - Child Feature Logic
            case .addRoutineSheet(.delegate(.didCancel)):
                state.isAddRoutineSheetPresented = false
                state.addRoutineState = nil
                return .none
                
            case let .addRoutineSheet(.delegate(.didSave(name, freq))):
                state.isAddRoutineSheetPresented = false
                state.addRoutineState = nil
                
                return .run { send in
                    do {
                        let newRoutine = try await MainActor.run { () -> RoutineTask in
                            let newRoutine = RoutineTask(context: self.viewContext)
                            newRoutine.name = name
                            newRoutine.interval = Int16(freq)
                            newRoutine.lastDone = Date()

                            try self.viewContext.save()
                            return newRoutine
                        }
                        await send(.routineSavedSuccessfully(newRoutine))
                    } catch {
                        await send(.routineSaveFailed)
                    }
                }
                
            case let .routineSavedSuccessfully(task):
                state.routineTasks.append(task)
                return .run { [task] _ in
                    await self.notificationClient.schedule(task)
                }
                
            case .routineSaveFailed:
                print("❌ Failed to save routine.")
                return .none

            case .addRoutineSheet:
                return .none
            }
        }
        .ifLet(\.addRoutineState, action: \.addRoutineSheet) {
            AddRoutineFeature(
                onSave: { name, freq in .send(.delegate(.didSave(name, freq))) },
                onCancel: { .send(.delegate(.didCancel)) }
            )
        }
    }
}

// This extension is still needed to make the Action enum Equatable.
extension RoutineTask {
    public static func == (lhs: RoutineTask, rhs: RoutineTask) -> Bool {
        lhs.objectID == rhs.objectID
    }
}
