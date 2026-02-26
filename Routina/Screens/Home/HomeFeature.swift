import ComposableArchitecture
import CoreData
import Foundation

@Reducer
struct HomeFeature {
    struct RoutineDisplay: Equatable, Identifiable {
        let id: NSManagedObjectID
        var name: String
        var emoji: String
        var interval: Int
        var lastDone: Date?
        var isDoneToday: Bool
    }

    @ObservableState
    struct State: Equatable {
        var routineTasks: [RoutineTask] = []
        var routineDisplays: [RoutineDisplay] = []
        var isAddRoutineSheetPresented: Bool = false
        var addRoutineState: AddRoutineFeature.State?
        var refreshVersion: Int = 0
    }
    
    // Actions are now explicit for success and failure, making them Equatable.
    enum Action: Equatable {
        case onAppear
        case tasksLoadedSuccessfully([RoutineTask])
        case tasksLoadFailed
        
        case setAddRoutineSheet(Bool)
        case deleteTasks([NSManagedObjectID])
        
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
                return .run { @MainActor send in
                    do {
                        let request = NSFetchRequest<RoutineTask>(entityName: "RoutineTask")
                        request.sortDescriptors = []
                        let tasks = try self.viewContext.fetch(request)
                        send(.tasksLoadedSuccessfully(tasks))
                    } catch {
                        send(.tasksLoadFailed)
                    }
                }
                
            case let .tasksLoadedSuccessfully(tasks):
                state.routineTasks = tasks
                state.routineDisplays = tasks.map(makeRoutineDisplay)
                state.refreshVersion &+= 1
                return .none
            
            case .tasksLoadFailed:
                print("❌ Failed to load tasks.")
                // You could set an error state here to show an alert.
                return .none
                
            case let .setAddRoutineSheet(isPresented):
                state.isAddRoutineSheetPresented = isPresented
                state.addRoutineState = isPresented ? AddRoutineFeature.State() : nil
                return .none
                
            case let .deleteTasks(ids):
                let idSet = Set(ids)
                state.routineTasks.removeAll { idSet.contains($0.objectID) }
                state.routineDisplays.removeAll { idSet.contains($0.id) }
                
                return .run { @MainActor [ids] _ in
                    for id in ids {
                        if let task = try? self.viewContext.existingObject(with: id) {
                            self.viewContext.delete(task)
                        }
                    }
                    try? self.viewContext.save()
                }
                
            // MARK: - Child Feature Logic
            case .addRoutineSheet(.delegate(.didCancel)):
                state.isAddRoutineSheetPresented = false
                state.addRoutineState = nil
                return .none
                
            case let .addRoutineSheet(.delegate(.didSave(name, freq, emoji))):
                state.isAddRoutineSheetPresented = false
                state.addRoutineState = nil
                
                return .run { @MainActor send in
                    do {
                        let newRoutine = RoutineTask(context: self.viewContext)
                        newRoutine.name = name
                        newRoutine.interval = Int16(freq)
                        newRoutine.lastDone = nil
                        newRoutine.setValue(emoji, forKey: "emoji")

                        try self.viewContext.save()
                        send(.routineSavedSuccessfully(newRoutine))
                    } catch {
                        send(.routineSaveFailed)
                    }
                }
                
            case let .routineSavedSuccessfully(task):
                state.routineTasks.append(task)
                state.routineDisplays.append(makeRoutineDisplay(task))
                let payload = makeNotificationPayload(for: task)
                return .run { _ in
                    await self.notificationClient.schedule(payload)
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
                onSave: { name, freq, emoji in .send(.delegate(.didSave(name, freq, emoji))) },
                onCancel: { .send(.delegate(.didCancel)) }
            )
        }
    }

    private func makeRoutineDisplay(_ task: RoutineTask) -> RoutineDisplay {
        let logs = ((task.value(forKey: "logs") as? NSSet)?.allObjects as? [RoutineLog]) ?? []
        let doneTodayFromLastDone = task.lastDone.map { Calendar.current.isDateInToday($0) } ?? false
        let doneTodayFromLogs = logs.contains {
            guard let timestamp = $0.timestamp else { return false }
            return Calendar.current.isDateInToday(timestamp)
        }
        let isDoneToday = doneTodayFromLastDone || doneTodayFromLogs

        return RoutineDisplay(
            id: task.objectID,
            name: task.name ?? "Unnamed task",
            emoji: (task.value(forKey: "emoji") as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "✨",
            interval: max(Int(task.interval), 1),
            lastDone: task.lastDone,
            isDoneToday: isDoneToday
        )
    }

    private func makeNotificationPayload(for task: RoutineTask) -> NotificationPayload {
        NotificationPayload(
            identifier: task.objectID.uriRepresentation().absoluteString,
            name: task.name,
            interval: max(Int(task.interval), 1),
            lastDone: task.lastDone
        )
    }
}

// This extension is still needed to make the Action enum Equatable.
extension RoutineTask {
    public static func == (lhs: RoutineTask, rhs: RoutineTask) -> Bool {
        lhs.objectID == rhs.objectID
    }
}
