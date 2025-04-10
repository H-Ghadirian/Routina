//
//  ContentView.swift
//  Routina
//
//  Created by ghadirianh on 07.03.25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @AppStorage("lastRoutineDate") private var lastRoutineDate: Date = Date()
    @AppStorage("routineInterval") private var routineInterval: Int = 7

    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RoutineLog.timestamp, ascending: false)],
        animation: .default)
    private var logs: FetchedResults<RoutineLog>

    private var daysSinceLastRoutine: Int {
        Calendar.current.dateComponents([.day], from: lastRoutineDate, to: Date()).day ?? 0
    }

    private var progressColor: Color {
        let progress = Double(daysSinceLastRoutine) / Double(routineInterval)
        switch progress {
        case ..<0.33:
            return .green
        case ..<0.66:
            return .yellow
        default:
            return .red
        }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 40), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("Routina")
                .font(.largeTitle)
                .bold()

            Text("\(daysSinceLastRoutine) day(s) passed")
                .foregroundColor(.secondary)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(0..<routineInterval, id: \ .self) { index in
                    Rectangle()
                        .fill(index < daysSinceLastRoutine ? progressColor : Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .cornerRadius(5)
                }
            }
            .padding()

            Text("Last done: \(lastRoutineDate.formatted(date: .abbreviated, time: .omitted))")
                .foregroundColor(.gray)

            Button("Mark as Done") {
                addLog()
                lastRoutineDate = Date()
            }
            .buttonStyle(.borderedProminent)

            List {
                Section(header: Text("Routine Logs")) {
                    ForEach(logs) { log in
                        Text(log.timestamp?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown date")
                    }
                }
            }

            HStack {
                Text("Do every:")
                Picker("Interval", selection: $routineInterval) {
                    ForEach([1, 3, 7, 14, 30], id: \ .self) { days in
                        Text("\(days) days").tag(days)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding()
    }

    private func addLog() {
        let newLog = RoutineLog(context: viewContext)
        newLog.timestamp = Date()

        do {
            try viewContext.save()
        } catch {
            print("Error saving log: \(error.localizedDescription)")
        }
    }
}
