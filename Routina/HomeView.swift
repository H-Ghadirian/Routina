//  Created by ghadirianh on 10.04.25.
//

import SwiftUI
import CoreData

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RoutineTask.name, ascending: true)],
        animation: .default)
    private var routines: FetchedResults<RoutineTask>

    @State private var showingAddRoutine = false

    var body: some View {
        NavigationView {
            List {
                ForEach(routines) { routine in
                    NavigationLink(destination: RoutineDetailView(task: routine)) {
                        Text(routine.name ?? "Unnamed Routine")
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

    private func deleteRoutines(offsets: IndexSet) {
        withAnimation {
            offsets.map { routines[$0] }.forEach(viewContext.delete)
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
