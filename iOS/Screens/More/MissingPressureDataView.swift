import ComposableArchitecture
import SwiftUI

struct MissingTaskDataView: View {
    let store: StoreOf<MissingTaskDataFeature>

    /// The inline navigation bar overlays a non-scrolling full-height view.
    /// Keep its title area distinct from the procedure's progress information.
    private let navigationTitleClearance: CGFloat = 56

    var body: some View {
        Group {
            if store.isLoading || (store.isSaving && store.currentTask == nil) {
                ProgressView("Loading tasks…")
            } else if let errorMessage = store.errorMessage,
                      !store.hasLoadedTasks || (store.currentTask == nil && !store.taskIDs.isEmpty) {
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

    private func taskCard(_ task: MissingTaskDataFeature.State.Task) -> some View {
        VStack(spacing: 16) {
            GuidedReviewProgressHeader(
                currentTaskNumber: store.currentTaskNumber,
                totalTaskCount: store.totalTaskCount,
                progressValue: store.progressValue
            )

            VStack(spacing: 20) {
                Text(task.title)
                    .font(.largeTitle.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)

                taskContext(task)

                Text(store.field.question)
                    .font(.headline)

                if store.field == .estimatedDuration {
                    timeEstimateChoices(for: task)
                } else {
                    RoutinaGlassSegmentedControl(
                        accessibilityLabel: store.field.navigationTitle,
                        options: store.field.values,
                        selection: valueBinding(for: task),
                        fillsAvailableWidth: true
                    ) { value in
                        Text(value.title)
                    }
                    .disabled(store.isSaving)
                }

                Text(store.field.instruction)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer(minLength: 0)

                if store.field == .estimatedDuration {
                    if let validationMessage = store.timeEstimateValidationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        store.send(.saveSelectedTimeEstimate(taskID: task.id))
                    } label: {
                        Label(
                            store.selectedTimeEstimateTitle.map { "Save \($0) & next" } ?? "Save & next",
                            systemImage: "checkmark"
                        )
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isSaving || store.selectedTimeEstimateMinutes == nil)
                }

                HStack(spacing: 12) {
                    Button {
                        store.send(.skipTask(taskID: task.id))
                    } label: {
                        Label("Skip", systemImage: "arrow.right")
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.isSaving || store.taskIDs.count < 2)

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
            .frame(maxWidth: .infinity, minHeight: 580, alignment: .top)
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

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, navigationTitleClearance)
        .padding(.bottom, 24)
        .animation(.snappy, value: task.id)
    }

    @ViewBuilder
    private func taskContext(_ task: MissingTaskDataFeature.State.Task) -> some View {
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

    private func valueBinding(
        for task: MissingTaskDataFeature.State.Task
    ) -> Binding<GuidedMissingTaskDataValue> {
        Binding(
            get: { store.field.missingValue },
            set: { store.send(.valueSelected(taskID: task.id, value: $0)) }
        )
    }

    private func timeEstimateChoices(
        for task: MissingTaskDataFeature.State.Task
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick picks")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Time estimate presets",
                options: store.field.values,
                selection: timeEstimateValueBinding(for: task),
                minimumSegmentWidth: 58,
                horizontalPadding: 6,
                verticalPadding: 9,
                fillsAvailableWidth: true,
                maximumSegmentsPerRow: store.field.maximumSegmentsPerRow
            ) { value in
                Text(value.title)
            }
            .disabled(store.isSaving)

            Text("Or enter a custom time")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                customTimeField(
                    title: "Hours",
                    placeholder: "0",
                    text: customHoursBinding
                )
                customTimeField(
                    title: "Minutes",
                    placeholder: "0",
                    text: customMinutesBinding
                )
            }
            .disabled(store.isSaving)
        }
    }

    private func customTimeField(
        title: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(placeholder, text: text)
                .keyboardType(.numberPad)
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.secondary.opacity(0.10))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }
                .accessibilityLabel(title)
        }
    }

    private func timeEstimateValueBinding(
        for task: MissingTaskDataFeature.State.Task
    ) -> Binding<GuidedMissingTaskDataValue> {
        Binding(
            get: { store.selectedTimeEstimateValue },
            set: { store.send(.valueSelected(taskID: task.id, value: $0)) }
        )
    }

    private var customHoursBinding: Binding<String> {
        Binding(
            get: { store.customTimeEstimateHours },
            set: {
                store.send(
                    .customTimeEstimateChanged(
                        hours: $0,
                        minutes: store.customTimeEstimateMinutes
                    )
                )
            }
        )
    }

    private var customMinutesBinding: Binding<String> {
        Binding(
            get: { store.customTimeEstimateMinutes },
            set: {
                store.send(
                    .customTimeEstimateChanged(
                        hours: store.customTimeEstimateHours,
                        minutes: $0
                    )
                )
            }
        )
    }
}
