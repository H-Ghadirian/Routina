//  Created by ghadirianh on 10.04.25.
//

import SwiftUI

struct AddRoutineView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var routineName: String = ""
    @State private var interval: Int = 7

    var body: some View {
        NavigationStack {
            Form {
                TextField("Routine name", text: $routineName)

                Picker("Interval", selection: $interval) {
                    ForEach([1, 3, 7, 14, 30], id: \.self) { days in
                        Text("\(days) days").tag(days)
                    }
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
