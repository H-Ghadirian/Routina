import SwiftUI

struct AddRoutineView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var routineName: String = ""
    @State private var interval: Int = 1

    var body: some View {
        NavigationStack {
            Form {
                TextField("Routine name", text: $routineName)

                HStack {
                    Text("Interval: ")
                    Picker("Interval", selection: $interval) {
                        ForEach(1...99, id: \ .self) { num in
                            Text("\(num) days").tag(num)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 100)
                }
            }
            .navigationTitle("Add Routine")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        addRoutine()
                    }.disabled(routineName.isEmpty)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func addRoutine() {
        let newRoutine = RoutineTask(context: viewContext)
        newRoutine.name = routineName
        newRoutine.interval = Int16(interval)
        newRoutine.lastDone = Date()

        do {
            try viewContext.save()
            scheduleNotification(for: newRoutine)
            dismiss()
        } catch {
            print("Error saving routine: \(error.localizedDescription)")
        }
    }

    private func scheduleNotification(for task: RoutineTask) {
        let content = UNMutableNotificationContent()
        content.title = "Time to complete \(task.name ?? "your routine")!"
        content.body = "Your routine is due today."
        content.sound = .default

        let dueDate = Calendar.current.date(byAdding: .day, value: Int(task.interval), to: task.lastDone ?? Date()) ?? Date()
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(identifier: task.objectID.uriRepresentation().absoluteString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
}
