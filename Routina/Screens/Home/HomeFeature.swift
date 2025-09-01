import ComposableArchitecture
import CoreData
import Foundation

@Reducer
struct HomeFeature {
    // In HomeFeature.swift

    struct State: Equatable {
        var routineTasks: [RoutineTask] = []
        @Presents var addRoutine: AddRoutineFeature.State?
        @Presents var routineDetail: RoutineDetailFeature.State?

        // ✅ ADD THIS COMPUTED PROPERTY AND HELPER FUNCTION
        var sortedTasks: [RoutineTask] {
            routineTasks.sorted { task1, task2 in
                urgencyLevel(for: task1) > urgencyLevel(for: task2)
            }
        }
        
        private func urgencyLevel(for task: RoutineTask) -> Int {
            let daysSinceLastRoutine = Calendar.current.dateComponents([.day], from: task.lastDone ?? Date(), to: Date()).day ?? 0
            let dueIn = Int(task.interval) - daysSinceLastRoutine

            if dueIn <= 0 { return 3 } // Overdue
            if dueIn == 1 { return 2 } // Due today
            if dueIn == 2 { return 1 } // Due tomorrow
            return 0 // Least urgent
        }
    }
    
    enum Action: Equatable {
        case onAppear
        case tasksLoadedSuccessfully([RoutineTask])
        case tasksLoadFailed
        
        case deleteTask(IndexSet)
        
        case addButtonTapped
        case addRoutine(PresentationAction<AddRoutineFeature.Action>)

        case routineSavedSuccessfully(RoutineTask)
        case routineSaveFailed

        case routineDetail(PresentationAction<RoutineDetailFeature.Action>)
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
                        let request = NSFetchRequest<RoutineTask>(entityName: "RoutineTask")
                        request.sortDescriptors = []
                        let tasks = try self.viewContext.fetch(request)
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
                
            case .addButtonTapped:
                state.addRoutine = AddRoutineFeature.State()
                return .none

            case let .deleteTask(offsets):
                let tasksToDelete = offsets.map { state.routineTasks[$0] }
                state.routineTasks.remove(atOffsets: offsets)
                
                return .run { [tasksToDelete] _ in
                    for task in tasksToDelete {
                        self.viewContext.delete(task)
                    }
                    try? self.viewContext.save()
                }
                
            // MARK: - Child Feature Logic
            case .addRoutine(.presented(.delegate(.didCancel))):
                state.addRoutine = nil
                return .none

//            case .addRoutine(.delegate(.didCancel)):
//                state.addRoutine = nil
//                return .none
            case let .addRoutine(.presented(.delegate(.didSave(name, freq)))):
                state.addRoutine = nil
                
                return .run { send in
                    do {
                        let newRoutine = RoutineTask(context: self.viewContext)
                        newRoutine.name = name
                        newRoutine.interval = Int16(freq)
                        newRoutine.lastDone = Date()
                        
                        try self.viewContext.save()
                        await send(.routineSavedSuccessfully(newRoutine))
                    } catch {
                        await send(.routineSaveFailed)
                    }
                }

//            case let .addRoutine(.delegate(.didSave(name, freq))):
//                state.addRoutine = nil
//                return .run { send in
//                    do {
//                        let newRoutine = RoutineTask(context: self.viewContext)
//                        newRoutine.name = name
//                        newRoutine.interval = Int16(freq)
//                        newRoutine.lastDone = Date()
//                        
//                        try self.viewContext.save()
//                        await send(.routineSavedSuccessfully(newRoutine))
//                    } catch {
//                        await send(.routineSaveFailed)
//                    }
//                }
                
            case let .routineSavedSuccessfully(task):
                state.routineTasks.append(task)
                return .run { [task] _ in
                    await self.notificationClient.schedule(task)
                }
                
            case .routineSaveFailed:
                print("❌ Failed to save routine.")
                return .none

            case .routineDetail(.presented(.delegate(.routineUpdated))):
                return .run { send in
                    await send(.onAppear)
                }
            case .routineDetail:
                return .none
            case .addRoutine:
                return .none
            }
        }
        .ifLet(\.$addRoutine, action: \.addRoutine) {
            AddRoutineFeature()
        }
        .ifLet(\.$routineDetail, action: \.routineDetail) {
            RoutineDetailFeature()
        }
    }
}
