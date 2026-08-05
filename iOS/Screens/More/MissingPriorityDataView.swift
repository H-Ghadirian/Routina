import ComposableArchitecture
import SwiftUI

struct MissingPriorityDataView: View {
    let store: StoreOf<MissingPriorityDataFeature>

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
        .navigationTitle("Review Importance & Urgency")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            store.send(.onAppear)
        }
    }

    private func taskCard(_ task: MissingPriorityDataFeature.State.Task) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("\(store.currentTaskNumber) of \(store.totalTaskCount)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                ProgressView(value: store.progressValue)
            }

            Spacer()

            VStack(spacing: 18) {
                Text(task.title)
                    .font(.largeTitle.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)

                taskContext(task)

                Text("How should this task be prioritized?")
                    .font(.headline)

                HStack(spacing: 12) {
                    importanceMenu
                    urgencyMenu
                }

                Text("Choose both values to make this task's priority explicit.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    store.send(.saveSelected(taskID: task.id))
                } label: {
                    Label("Save & next", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isSaving)

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

    private var importanceMenu: some View {
        Menu {
            ForEach(RoutineTaskImportance.allCases, id: \.self) { importance in
                Button(importance.title) {
                    store.send(.importanceSelected(importance))
                }
            }
        } label: {
            VStack(spacing: 2) {
                Label("Importance", systemImage: "arrow.up")
                    .font(.caption.weight(.semibold))
                Text(store.selectedImportance.title)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .disabled(store.isSaving)
        .accessibilityLabel("Importance: \(store.selectedImportance.title)")
    }

    private var urgencyMenu: some View {
        Menu {
            ForEach(RoutineTaskUrgency.allCases, id: \.self) { urgency in
                Button(urgency.title) {
                    store.send(.urgencySelected(urgency))
                }
            }
        } label: {
            VStack(spacing: 2) {
                Label("Urgency", systemImage: "arrow.right")
                    .font(.caption.weight(.semibold))
                Text(store.selectedUrgency.title)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .disabled(store.isSaving)
        .accessibilityLabel("Urgency: \(store.selectedUrgency.title)")
    }

    @ViewBuilder
    private func taskContext(_ task: MissingPriorityDataFeature.State.Task) -> some View {
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

            Text("Every eligible task has explicit importance and urgency.")
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
}
