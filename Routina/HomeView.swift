//
//  HomeView.swift
//  Routina
//
//  Created by ghadirianh on 10.04.25.
//

import SwiftUI
import CoreData

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RoutineTask.name, ascending: true)],
        animation: .default)
    private var tasks: FetchedResults<RoutineTask>

    @State private var showingAddTask = false

    var body: some View {
        NavigationView {
            List {
                ForEach(tasks) { task in
                    NavigationLink(destination: TaskDetailView()) { //task: task)) {
                        Text(task.name ?? "Unnamed Task")
                    }
                }
                .onDelete(perform: deleteTasks)
            }
            .navigationTitle("Routina")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTask = true }) {
                        Label("Add Task", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView().environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            }
        }
    }

    private func deleteTasks(offsets: IndexSet) {
        withAnimation {
            offsets.map { tasks[$0] }.forEach(viewContext.delete)
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
