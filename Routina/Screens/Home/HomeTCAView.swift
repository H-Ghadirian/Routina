// In HomeTCAView.swift

import ComposableArchitecture
import CoreData
import SwiftUI

struct HomeTCAView: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationView {
                Group {
                    if viewStore.routineTasks.isEmpty {
                        Text("No routine defined yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        // ✅ FIX: Pass the ViewStore directly
                        listOfSortedTasksView(viewStore)
                    }
                }
                .navigationTitle("Routina")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            // ✅ FIX: Send the correct action
                            viewStore.send(.addButtonTapped)
                        } label: {
                            Label("Add Routine", systemImage: "plus")
                        }
                    }
                }
                // ✅ FIX: Use the modern .sheet(store:) modifier
                .sheet(
                    store: self.store.scope(
                        state: \.$addRoutine,
                        action: \.addRoutine
                    )
                ) { store in
                    AddRoutineTCAView(store: store)
                }
                .task {
                    viewStore.send(.onAppear)
                }
            }
        }
    }

    // ✅ FIX: This function is no longer needed, logic was moved to the State
    // private func sortedTasks(_ viewStore: ViewStoreOf<HomeFeature>) -> [RoutineTask] { ... }
    
    // ✅ FIX: This function is no longer needed, logic was moved to the State
    // private func urgencyLevel(for task: RoutineTask) -> Int { ... }

    private func listOfSortedTasksView(_ viewStore: ViewStoreOf<HomeFeature>) -> some View {
        List {
            // ✅ FIX: Use the computed property from the State
            ForEach(viewStore.state.sortedTasks) { task in
                NavigationLink(
                    state: RoutineDetailFeature.State(task: task)
                ) {
                    HStack {
                        Text(task.name ?? "Unnamed task")
                        Spacer()
                        urgencySquare(for: task)
                    }
                }
            }
            .onDelete { viewStore.send(.deleteTask($0)) }
        }
        // ✅ This was already correct, but ensure it's attached to the List
        .navigationDestination(
            store: self.store.scope(state: \.$routineDetail, action: \.routineDetail)
        ) { childStore in
            RoutineDetailTCAView(store: childStore)
        }
    }
    
    // This function is fine as it's purely for presentation
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
}
