import SwiftUI
import CoreData

struct RoutineDetailView: View {
    @ObservedObject var task: RoutineTask
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest private var logs: FetchedResults<RoutineLog>

    init(task: RoutineTask) {
        self.task = task
        _logs = FetchRequest(
            entity: RoutineLog.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \RoutineLog.timestamp, ascending: false)],
            predicate: NSPredicate(format: "task == %@", task)
        )
    }

    private var daysSinceLastRoutine: Int {
        Calendar.current.dateComponents([.day], from: task.lastDone ?? Date(), to: Date()).day ?? 0
    }

    private var overdueDays: Int {
        max(0, daysSinceLastRoutine - Int(task.interval))
    }

    private var progressColor: Color {
        let progress = Double(daysSinceLastRoutine) / Double(task.interval)
        switch progress {
        case ..<0.75: return .green
        case ..<0.90: return .yellow
        default: return .red
        }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 40), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 20) {
            taskNameView

            if overdueDays > 0 {
                Text("Overdue by \(overdueDays) day(s)")
                    .foregroundColor(.red)
                    .fontWeight(.bold)
            }

            rectanglesSinceLastDoneView

            doneButtonView

            if logs.count > 0, let lastDone = task.lastDone?.formatted(date: .abbreviated, time: .omitted) {
                Text("\(daysSinceLastRoutine) \(daysSinceLastRoutine > 1 ? "days" : "day") passed since last done: \(lastDone)")
                    .foregroundColor(.secondary)

                listOfRoutineLogsView
            } else {
                Text("Never done yet")
            }
            Spacer()
        }
        .padding()
    }

    private var taskNameView: some View {
        Text(task.name ?? "Unnamed Routine")
            .font(.largeTitle)
            .bold()
    }

    private var rectanglesSinceLastDoneView: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<Int(task.interval), id: \.self) { index in
                Rectangle()
                    .fill(index < daysSinceLastRoutine ? progressColor : Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .cornerRadius(5)
            }
        }
        .padding()
    }

    private var doneButtonView: some View {
        Button("Mark as Done") {
            markAsDone()
        }
        .buttonStyle(.borderedProminent)
    }

    private var listOfRoutineLogsView: some View {
        List {
            Section(header: Text("Routine Logs")) {
                ForEach(logs) { log in
                    Text(log.timestamp?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown date")
                }
            }
        }
    }

    private func markAsDone() {
        task.lastDone = Date()
        let newLog = RoutineLog(context: viewContext)
        newLog.timestamp = task.lastDone
        newLog.task = task

        saveContext()
#if os(iOS)
        scheduleNotification(for: task)
        #endif
    }

#if os(iOS)
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
    #endif

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving log: \(error.localizedDescription)")
        }
    }
}
