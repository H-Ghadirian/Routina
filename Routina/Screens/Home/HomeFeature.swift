import ComposableArchitecture
import CoreData
import Foundation

@Reducer
struct HomeFeature {
    struct State: Equatable {
        var routineTasks: [RoutineTask] = []
        var isAddRoutineSheetPresented: Bool = false
    }
    
    enum Action: Equatable {
        case markAsDone
        case loadTasks([RoutineTask])
        case onAppear
        case setAddRoutineSheet(Bool)
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
                return handleOnAppear()
            case .setAddRoutineSheet(let isPresented):
                state.isAddRoutineSheetPresented = isPresented
                return .none
            }
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
