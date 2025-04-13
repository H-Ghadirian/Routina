import SwiftUI
import CoreData
import SwiftUI
import CoreData

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RoutineTask.name, ascending: true)],
        animation: .default)
    private var routineTasks: FetchedResults<RoutineTask>

    @State private var showingAddRoutine = false

    var body: some View {
        NavigationView {
            List {
                ForEach(routineTasks) { task in
                    NavigationLink(destination: RoutineDetailView(task: task)) {
                        HStack {
                            Text(task.name ?? "Unnamed task")
                            Spacer()
                            urgencySquare(for: task)
                        }
                    }
                }
                .onDelete(perform: deleteRoutines)
            }
            .navigationTitle("Routina")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddRoutine = true }) {
                        Label("Add Routine", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddRoutine) {
                AddRoutineView().environment(\.managedObjectContext, viewContext)
            }
        }
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

    private func deleteRoutines(offsets: IndexSet) {
        withAnimation {
            offsets.map { routineTasks[$0] }.forEach(viewContext.delete)
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView().environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
