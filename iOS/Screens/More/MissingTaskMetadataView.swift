import ComposableArchitecture
import SwiftUI

struct MissingTaskMetadataView: View {
    let store: StoreOf<MissingTaskMetadataFeature>

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
        .navigationTitle(store.field.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            store.send(.onAppear)
        }
    }

    private func taskCard(_ task: MissingTaskMetadataFeature.State.Task) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("\(store.currentTaskNumber) of \(store.totalTaskCount)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                ProgressView(value: store.progressValue)
            }

            Spacer(minLength: 8)

            VStack(spacing: 22) {
                Text(task.title)
                    .font(.largeTitle.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)

                taskContext(task)

                Text(store.field.question)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                RoutinaGlassSegmentedControl(
                    accessibilityLabel: store.field.navigationTitle,
                    options: store.field.values,
                    selection: store.field.defaultValue,
                    onSelect: { value in
                        store.send(.valueSelected(taskID: task.id, value: value))
                    },
                    minimumSegmentWidth: 118,
                    horizontalPadding: 12,
                    verticalPadding: 13,
                    fillsAvailableWidth: true,
                    maximumSegmentsPerRow: 2,
                    tint: tint(for:),
                    foregroundColor: { _, isSelected in
                        isSelected ? .primary : .secondary
                    }
                ) { value in
                    Text(value.title)
                }
                .disabled(store.isSaving)

                Text(store.field.instruction)
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
            .frame(maxWidth: .infinity, minHeight: 620)
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

            Spacer(minLength: 8)
        }
        .padding(24)
        .animation(.snappy, value: task.id)
    }

    @ViewBuilder
    private func taskContext(_ task: MissingTaskMetadataFeature.State.Task) -> some View {
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

    private func tint(for value: GuidedTaskMetadataValue) -> Color {
        switch value {
        case let .importance(importance):
            return TaskDetailPriorityPresentation.importanceTint(for: importance)
        case let .urgency(urgency):
            return TaskDetailPriorityPresentation.urgencyTint(for: urgency)
        }
    }

    private var completionCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("All set")
                .font(.title2.weight(.semibold))

            Text(store.field.completionMessage)
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
