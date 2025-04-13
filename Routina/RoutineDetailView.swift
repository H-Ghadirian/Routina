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
            Text(task.name ?? "Unnamed Routine")
                .font(.largeTitle)
                .bold()

            Text("\(daysSinceLastRoutine) day(s) passed")
                .foregroundColor(.secondary)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(0..<Int(task.interval), id: \.self) { index in
                    Rectangle()
                        .fill(index < daysSinceLastRoutine ? progressColor : Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .cornerRadius(5)
                }
            }
            .padding()

            Text("Last done: \(task.lastDone?.formatted(date: .abbreviated, time: .omitted) ?? "Never")")
                .foregroundColor(.gray)

            Button("Mark as Done") {
                markAsDone()
            }
            .buttonStyle(.borderedProminent)

            List {
                Section(header: Text("Routine Logs")) {
                    ForEach(logs) { log in
                        Text(log.timestamp?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown date")
                    }
                }
            }

            Spacer()
        }
        .padding()
    }

    private func markAsDone() {
        task.lastDone = Date()
        let newLog = RoutineLog(context: viewContext)
        newLog.timestamp = Date()
        newLog.task = task

        saveContext()
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving log: \(error.localizedDescription)")
        }
    }
}
