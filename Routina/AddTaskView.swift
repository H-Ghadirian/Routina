//
//  AddTaskView.swift
//  Routina
//
//  Created by ghadirianh on 10.04.25.
//

import SwiftUI

struct AddTaskView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var taskName: String = ""
    @State private var interval: Int = 7

    var body: some View {
        NavigationStack {
            Form {
                TextField("Task name", text: $taskName)

                Picker("Interval", selection: $interval) {
                    ForEach([1, 3, 7, 14, 30], id: \.self) { days in
                        Text("\(days) days").tag(days)
                    }
                }
            }
            .navigationTitle("Add Task")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save me") {
                        saveContext()
                    }.disabled(taskName.isEmpty)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving task: \(error.localizedDescription)")
        }
    }
}

extension AddTaskView {
    private func addTask() {
        let newTask = RoutineTask(context: viewContext)
        newTask.name = taskName
        newTask.interval = Int16(interval)
        newTask.lastDone = Date()

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving task: \(error.localizedDescription)")
        }
    }
}
