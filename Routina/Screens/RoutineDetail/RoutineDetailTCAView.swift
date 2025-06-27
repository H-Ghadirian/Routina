import SwiftUI
import ComposableArchitecture

struct RoutineDetailTCAView: View {
    let store: StoreOf<RoutineDetailFeature>

    private let columns = [
        GridItem(.adaptive(minimum: 40), spacing: 5)
    ]

    var body: some View {
        WithViewStore(store, observe: \.self) { viewStore in
            VStack(spacing: 20) {
                Text(viewStore.task.name ?? "Unnamed Routine")
                    .font(.largeTitle)
                    .bold()

                if viewStore.overdueDays > 0 {
                    Text("Overdue by \(viewStore.overdueDays) day(s)")
                        .foregroundColor(.red)
                        .fontWeight(.bold)
                } else {
                    Text(viewStore.daysSinceLastRoutine == 0 ? "Done Today!" : "\(viewStore.daysSinceLastRoutine) day(s) since last done")
                }

                if let dueDate = Calendar.current.date(byAdding: .day, value: Int(viewStore.task.interval), to: viewStore.task.lastDone ?? Date()) {
                    Text("Due Date: \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                        .foregroundColor(.red)
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(0..<Int(viewStore.task.interval), id: \.self) { index in
                        Rectangle()
                            .fill(index < viewStore.daysSinceLastRoutine ? progressColor(for: viewStore) : Color.gray.opacity(0.3))
                            .frame(width: 40, height: 40)
                            .cornerRadius(5)
                    }
                }
                .padding()

                Button("Mark as Done") {
                    viewStore.send(.markAsDone)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewStore.daysSinceLastRoutine == 0)

                if viewStore.logs.isEmpty {
                    Text("Never done yet")
                } else {
                    List {
                        Section(header: Text("Routine Logs")) {
                            ForEach(viewStore.logs, id: \.self) { log in
                                Text(log.timestamp?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown date")
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .onAppear {
                viewStore.send(.onAppear)
            }
        }
    }

    private func progressColor(for viewStore: ViewStoreOf<RoutineDetailFeature>) -> Color {
        let progress = Double(viewStore.daysSinceLastRoutine) / Double(viewStore.task.interval)
        switch progress {
        case ..<0.75: return .green
        case ..<0.90: return .yellow
        default: return .red
        }
    }
}
