import SwiftUI
import UserNotifications

struct AddRoutineView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var routineName: String = ""
    @State private var interval: Int = 1
    @State private var notificationsDisabled = false
    @State private var showNotificationAlert = false

    var body: some View {
        NavigationStack {
            Form {

                TextField("Routine name", text: $routineName)

                HStack {
                    Text("Interval: ")
                    intervalPickerView
                }

#if os(iOS)
                if notificationsDisabled {
                    enableNotificationsButtonView
                }
#endif
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
            .alert("Enable Notifications", isPresented: $showNotificationAlert) {
                Button("Cancel", role: .cancel) {}
                Button("OK") {
                    requestNotificationPermission()
                }
            } message: {
                Text("To remind you about your routines, please enable notifications in Settings.")
            }
        }
        .onAppear(perform: checkNotificationStatus)
    }

#if os(iOS)
    private var enableNotificationsButtonView: some View {
        Button(action: openSettings) {
            Text("Enable Notifications")
                .foregroundColor(.red)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.clear)
                .cornerRadius(10)
        }
    }
#endif

    private var intervalPickerView: some View {
        Picker("Interval", selection: $interval) {
            ForEach(1...99, id: \.self) { num in
                Text("\(num) days").tag(num)
            }
        }
#if os(iOS)
        .pickerStyle(WheelPickerStyle())
#endif
        .frame(height: 100)
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsDisabled = settings.authorizationStatus != .authorized
            }
        }
    }

#if os(iOS)
    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
#endif

    private func addRoutine() {
        if notificationsDisabled, !UserDefaults.standard.bool(forKey: "requestNotificationPermission") {
            showNotificationAlert = true
            return
        }
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

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            UserDefaults.standard.set(true, forKey: "requestNotificationPermission")
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
                return
            }
        }
    }

    private func scheduleNotification(for task: RoutineTask) {

        let request = UNNotificationRequest(
            identifier: task.objectID.uriRepresentation().absoluteString,
            content: createContent(for: task.name ?? "your routine"),
            trigger: createTrigger(for: task)
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func createTrigger(for task: RoutineTask) -> UNCalendarNotificationTrigger {
        let dueDate = Calendar.current.date(
            byAdding: .day, value: Int(task.interval), to: task.lastDone ?? Date()
        ) ?? Date()
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        return trigger
    }

    private func createContent(for taskName: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Time to complete \(taskName)!"
        content.body = "Your routine is due today."
        content.sound = .default
        return content
    }

}
