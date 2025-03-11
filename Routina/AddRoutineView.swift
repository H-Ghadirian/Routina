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
            dismiss()  // Close the sheet
        } catch {
            print("Error saving routine: \(error.localizedDescription)")
        }
    }
}
