import SwiftUI
import SwiftData

struct MissingPressureDataView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(
        filter: #Predicate<RoutineTask> { task in
            task.pressureRawValue == "none"
        },
        sort: \RoutineTask.name
    ) private var tasksWithoutPressure: [RoutineTask]
    @State private var currentIndex = 0
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            if tasksWithoutPressure.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    headerBar
                    cardStack
                }
            }
        }
        .navigationTitle("Add missing Pressure data")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(currentIndex + 1) of \(tasksWithoutPressure.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            ProgressView(value: Double(currentIndex + 1), total: Double(tasksWithoutPressure.count))
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .background(.gray.opacity(0.05))
    }

    private var cardStack: some View {
        ZStack {
            ForEach(0..<tasksWithoutPressure.count, id: \.self) { index in
                if abs(index - currentIndex) <= 1 {
                    cardView(for: tasksWithoutPressure[index], index: index)
                        .offset(x: index == currentIndex ? dragOffset : (index > currentIndex ? 400 : -400))
                        .opacity(index == currentIndex ? 1 : 0)
                        .transition(.opacity)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let threshold: CGFloat = 50
                    if value.translation.width > threshold && currentIndex > 0 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            currentIndex -= 1
                            dragOffset = 0
                        }
                    } else if value.translation.width < -threshold && currentIndex < tasksWithoutPressure.count - 1 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            currentIndex += 1
                            dragOffset = 0
                        }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }

    @ViewBuilder
    private func cardView(for task: RoutineTask, index: Int) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text(task.name ?? "Unnamed Task")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)

                if let emoji = task.emoji {
                    Text(emoji)
                        .font(.system(size: 48))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(.gray.opacity(0.05))
            .cornerRadius(12)

            VStack(spacing: 16) {
                Text("What's the pressure level?")
                    .font(.headline)

                RoutinaGlassSegmentedControl(
                    accessibilityLabel: "Pressure",
                    options: RoutineTaskPressure.allCases,
                    selection: Binding(
                        get: { task.pressure },
                        set: { newPressure in
                            task.pressure = newPressure
                            do {
                                try modelContext.save()
                            } catch {
                                print("Error saving pressure: \(error)")
                            }
                        }
                    ),
                    fillsAvailableWidth: true
                ) { pressure in
                    Text(pressure.title)
                }

                Text("Use this for tasks that keep occupying your mind, even when they are not the most urgent.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            HStack(spacing: 12) {
                if currentIndex > 0 {
                    Button(action: { swipeToPrevious() }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if currentIndex < tasksWithoutPressure.count - 1 {
                    Button(action: { swipeToNext() }) {
                        HStack {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("All set!")
                .font(.title2)
                .fontWeight(.semibold)

            Text("All your tasks have pressure data.")
                .foregroundStyle(.secondary)

            Button(action: { dismiss() }) {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 12)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.gray.opacity(0.05))
    }

    private func swipeToNext() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentIndex += 1
            dragOffset = 0
        }
    }

    private func swipeToPrevious() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentIndex -= 1
            dragOffset = 0
        }
    }
}

#Preview {
    MissingPressureDataView()
}
