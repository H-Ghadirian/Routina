import ComposableArchitecture
import CoreData
import SwiftUI

struct HomeTCAView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let store: StoreOf<HomeFeature>
    @State private var needsRefresh = false  // Added State to trigger UI refresh
    @State private var showingAddRoutine = false

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationView {
                listOfSortedTasksView(viewStore)
                    .navigationTitle("Routina")
                    .toolbar {
    #if os(iOS)
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                viewStore.send(.setAddRoutineSheet(true))
                            } label: {
                                Label("Add Routine", systemImage: "plus")
                            }
                        }
    #endif
                    }
                    .sheet(
                        isPresented: viewStore.binding(
                            get: \.isAddRoutineSheetPresented,
                            send: HomeFeature.Action.setAddRoutineSheet
                        )
                    ) {
                        IfLetStore(
                            self.store.scope(
                                state: \.addRoutineState,
                                action: \.addRoutineSheet
                            ),
                            then: AddRoutineTCAView.init(store:)
                        )
                    }
                    .task {
                        viewStore.send(.onAppear)
                    }
            }
            .id(needsRefresh)  // Force UI refresh when returning from detail view
        }
    }

    private func sortedTasks(_ viewStore: ViewStoreOf<HomeFeature>) -> [RoutineTask] {
        viewStore.routineTasks.sorted { task1, task2 in
            urgencyLevel(for: task1) > urgencyLevel(for: task2)
        }
    }

    private func urgencyLevel(for task: RoutineTask) -> Int {
        let daysSinceLastRoutine = Calendar.current.dateComponents([.day], from: task.lastDone ?? Date(), to: Date()).day ?? 0
        let dueIn = Int(task.interval) - daysSinceLastRoutine

        if dueIn <= 0 { return 3 } // Overdue, highest priority
        if dueIn == 1 { return 2 } // Due today
        if dueIn == 2 { return 1 } // Due tomorrow
        return 0 // Least urgent
    }

    private func listOfSortedTasksView(_ viewStore: ViewStoreOf<HomeFeature>) -> some View {
        List {
            ForEach(sortedTasks(viewStore)) { task in
                NavigationLink(
                    destination:
                        routineDetailTCAView(task: task)
                ) {
                    HStack {
                        Text(task.name ?? "Unnamed task")
                        Spacer()
                        urgencySquare(for: task)
                    }
                }
            }
            .onDelete { deleteRoutines(viewStore, offsets: $0) }
        }
    }
    
    private func routineDetailTCAView(task: RoutineTask) -> some View {
        RoutineDetailTCAView(
            store: Store(
                initialState: RoutineDetailFeature.State(
                    task: task,
                    logs: [], //task.logs,
                    daysSinceLastRoutine: Calendar.current.dateComponents([.day], from: task.lastDone ?? Date(), to: Date()).day ?? 0,
                    overdueDays: max((Calendar.current.dateComponents([.day], from: (Calendar.current.date(byAdding: .day, value: Int(task.interval), to: task.lastDone ?? Date()) ?? Date()), to: Date()).day ?? 0), 0)
                ),
                reducer: { RoutineDetailFeature() }
            )
        )
    }
    private func urgencySquare(for task: RoutineTask) -> some View {
        let daysSinceLastRoutine = Calendar.current.dateComponents([.day], from: task.lastDone ?? Date(), to: Date()).day ?? 0
        let progress = Double(daysSinceLastRoutine) / Double(task.interval)
        
        let color: Color = {
            switch progress {
            case ..<0.75: return .green
            case ..<0.90: return .yellow
            default: return .red
            }
        }()

        return Rectangle()
            .fill(color)
            .frame(width: 20, height: 20)
            .cornerRadius(4)
    }

    private func deleteRoutines(_ viewStore: ViewStoreOf<HomeFeature>, offsets: IndexSet) {
        withAnimation {
            offsets.map { viewStore.routineTasks[$0] }.forEach(viewContext.delete)
            saveContext()
        }
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Unresolved error: \(error.localizedDescription)")
        }
    }
}
