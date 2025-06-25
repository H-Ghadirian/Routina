import SwiftUI

struct AddRoutineView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: AddRoutineViewModel

    var body: some View {
        NavigationStack {
            addRoutineForm
            .navigationTitle("Add Routine")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.addRoutine(context: viewContext, dismiss: dismiss)
                    }.disabled(viewModel.routineName.isEmpty)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Enable Notifications", isPresented: $viewModel.showNotificationAlert) {
                Button("Cancel", role: .cancel) {}
                Button("OK") {
                    viewModel.requestNotificationPermission()
                }
            } message: {
                Text("To remind you about your routines, please enable notifications in Settings.")
            }
        }
        .onAppear(perform: viewModel.checkNotificationStatus)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            viewModel.checkNotificationStatus()
        }

    }

    private var addRoutineForm: some View {
        Form {
            TextField("Routine name", text: $viewModel.routineName)

            HStack {
                Text("Interval: ")
                intervalPickerView
            }

            if viewModel.notificationsDisabled {
                enableNotificationsButtonView
            }
        }
    }

    private var enableNotificationsButtonView: some View {
        Button(action: { viewModel.openSettings(dismiss: dismiss) }) {
            Text("Enable Notifications")
                .foregroundColor(.red)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.clear)
                .cornerRadius(10)
        }
    }

    private var intervalPickerView: some View {
        Picker("Interval", selection: $viewModel.interval) {
            ForEach(1...99, id: \.self) { num in
                Text("\(num) days").tag(num)
            }
        }
        .pickerStyle(WheelPickerStyle())
        .frame(height: 100)
    }
}
