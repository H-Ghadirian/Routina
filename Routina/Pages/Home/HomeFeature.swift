import ComposableArchitecture
import CoreData
import Foundation

private enum ManagedObjectContextKey: DependencyKey {
    static let liveValue: NSManagedObjectContext = {
        fatalError("NSManagedObjectContext has not been set in DependencyValues.")
    }()
}

extension DependencyValues {
    var managedObjectContext: NSManagedObjectContext {
        get { self[ManagedObjectContextKey.self] }
        set { self[ManagedObjectContextKey.self] = newValue }
    }
}

@Reducer
struct HomeFeature {
    struct State: Equatable {
        var routineTasks: [RoutineTask] = []
    }

    enum Action: Equatable {
        case markAsDone
        case loadTasks([RoutineTask])
        case onAppear
    }

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
    }
}
