import ComposableArchitecture
import SwiftUI

struct MissingPressureDataView: View {
    let store: StoreOf<MissingPressureDataFeature>

    private let pressureOptions = RoutineTaskPressure.allCases.filter { $0 != .none }

    var body: some View {
        Group {
            if store.isLoading {
                ProgressView("Loading tasks…")
            } else if let errorMessage = store.errorMessage, !store.hasLoadedTasks {
                loadFailureCard(errorMessage)
            } else if let task = store.currentTask {
                taskCard(task)
            } else {
                completionCard
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Add missing Pressure")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            store.send(.onAppear)
        }
    }

    private func taskCard(_ task: MissingPressureDataFeature.State.Task) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("\(store.currentTaskNumber) of \(store.totalTaskCount)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                ProgressView(value: store.progressValue)
            }

            Spacer()

            VStack(spacing: 20) {
                Text(task.title)
                    .font(.largeTitle.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)

                taskContext(task)

                Text("How much pressure does this task create?")
                    .font(.headline)

                RoutinaGlassSegmentedControl(
                    accessibilityLabel: "Pressure",
                    options: pressureOptions,
                    selection: pressureBinding(for: task),
                    fillsAvailableWidth: true
                ) { pressure in
                    Text(pressure.title)
                }
                .disabled(store.isSaving)

                Text("Pressure is how much a task stays on your mind, even when it is not the most urgent.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button {
                        store.send(.skipTask(taskID: task.id))
                    } label: {
                        Label("Skip", systemImage: "arrow.right")
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.isSaving || store.tasks.count < 2)

                    Button {
                        store.send(.taskDetailsTapped(taskID: task.id))
                    } label: {
                        Label("Check task details", systemImage: "info.circle")
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.isSaving)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .routinaGlassCard(
                cornerRadius: 24,
                tint: .accentColor,
                tintOpacity: 0.08,
                interactive: false
            )

            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(24)
        .animation(.snappy, value: task.id)
    }

    @ViewBuilder
    private func taskContext(_ task: MissingPressureDataFeature.State.Task) -> some View {
        if !task.path.isEmpty || !task.labels.isEmpty || !task.tags.isEmpty {
            VStack(spacing: 8) {
                if !task.path.isEmpty {
                    Label(task.path.joined(separator: " / "), systemImage: "folder")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .accessibilityLabel("Task path: \(task.path.joined(separator: ", "))")
                }

                if !task.labels.isEmpty {
                    HomeFilterFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                        ForEach(task.labels) { label in
                            Label(label.title, systemImage: label.systemImage)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .routinaGlassPill(tint: .secondary, tintOpacity: 0.10)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                if !task.tags.isEmpty {
                    HomeFilterFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                        ForEach(task.tags, id: \.self) { tag in
                            RoutineTagPill(name: tag, color: nil, size: .small)
                        }

                        if task.additionalTagCount > 0 {
                            Text("+\(task.additionalTagCount)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .routinaGlassPill(tint: .secondary, tintOpacity: 0.10)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityLabel(
                        "Tags: \((task.tags + Array(repeating: "additional tag", count: task.additionalTagCount)).joined(separator: ", "))"
                    )
                }
            }
        }
    }

    private var completionCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("All set")
                .font(.title2.weight(.semibold))

            Text("Every task has pressure data.")
                .foregroundStyle(.secondary)

            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(32)
        .multilineTextAlignment(.center)
    }

    private func loadFailureCard(_ errorMessage: String) -> some View {
        ContentUnavailableView {
            Label("Couldn’t load tasks", systemImage: "exclamationmark.triangle")
        } description: {
            Text(errorMessage)
        } actions: {
            Button("Try Again") {
                store.send(.onAppear)
            }
        }
    }

    private func pressureBinding(
        for task: MissingPressureDataFeature.State.Task
    ) -> Binding<RoutineTaskPressure> {
        Binding(
            get: { .none },
            set: { store.send(.pressureSelected(taskID: task.id, pressure: $0)) }
        )
    }
}
