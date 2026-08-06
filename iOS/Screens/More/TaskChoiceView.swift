import ComposableArchitecture
import SwiftUI

struct TaskChoiceView: View {
    let store: StoreOf<TaskChoiceFeature>

    var body: some View {
        Group {
            switch store.phase {
            case .setup:
                setup
            case .loading:
                ProgressView("Finding relevant tasks…")
            case .comparing:
                comparison
            case .recommendation:
                recommendation
            case .empty:
                emptyState
            case .failure:
                failureState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Help me choose")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var setup: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 8) {
                Text("Choose the right next task")
                    .font(.title2.weight(.semibold))

                Text("Set your current condition, then compare a few similar tasks head to head.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 18) {
                conditionPicker(
                    title: "How much time do you have?",
                    accessibilityLabel: "Available time",
                    options: TaskChoiceAvailableTime.allCases,
                    selection: store.condition.availableTime,
                    maximumSegmentsPerRow: 2,
                    onSelect: { store.send(.availableTimeChanged($0)) }
                ) { Text($0.title) }

                conditionPicker(
                    title: "What is your energy level?",
                    accessibilityLabel: "Energy level",
                    options: TaskChoiceEnergy.allCases,
                    selection: store.condition.energy,
                    maximumSegmentsPerRow: 3,
                    onSelect: { store.send(.energyChanged($0)) }
                ) { Text($0.title) }

                conditionPicker(
                    title: "What matters most right now?",
                    accessibilityLabel: "Task-choice intent",
                    options: TaskChoiceIntent.allCases,
                    selection: store.condition.intent,
                    maximumSegmentsPerRow: 2,
                    onSelect: { store.send(.intentChanged($0)) }
                ) { Text($0.title) }
            }
            .padding(20)
            .routinaGlassCard(
                cornerRadius: 24,
                tint: .accentColor,
                tintOpacity: 0.08,
                interactive: false
            )

            Button {
                store.send(.findTasksTapped)
            } label: {
                Label("Compare tasks", systemImage: "arrow.left.arrow.right")
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderedProminent)

            Text("Your comparisons are temporary and never change task metadata.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .padding(24)
    }

    @ViewBuilder
    private func conditionPicker<Option: Hashable, Label: View>(
        title: String,
        accessibilityLabel: String,
        options: [Option],
        selection: Option,
        maximumSegmentsPerRow: Int,
        onSelect: @escaping (Option) -> Void,
        @ViewBuilder label: @escaping (Option) -> Label
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            RoutinaGlassSegmentedControl(
                accessibilityLabel: accessibilityLabel,
                options: options,
                selection: selection,
                onSelect: onSelect,
                minimumSegmentWidth: 94,
                horizontalPadding: 10,
                verticalPadding: 10,
                fillsAvailableWidth: true,
                maximumSegmentsPerRow: maximumSegmentsPerRow
            ) { option in
                label(option)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }

    private var comparison: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text("Comparison \(store.comparisonNumber) of \(store.comparisonCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ProgressView(
                    value: Double(store.comparisonNumber),
                    total: Double(max(store.comparisonCount, 1))
                )
                .tint(.accentColor)
            }

            Text("Which task is higher priority right now?")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            if let currentWinner = store.currentWinner,
               let challenger = store.currentChallenger {
                HStack(alignment: .top, spacing: 12) {
                    candidateChoice(currentWinner)
                    candidateChoice(challenger)
                }
            }

            Text("Tap the task you would rather do next. Comparable metadata is shown to make the tie-break clear.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Start over") {
                store.send(.startAgainTapped)
            }
            .buttonStyle(.bordered)

            Spacer(minLength: 0)
        }
        .padding(24)
    }

    private func candidateChoice(_ candidate: TaskChoiceCandidate) -> some View {
        Button {
            store.send(.preferredTaskSelected(candidate.id))
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Text(candidate.title)
                    .font(.headline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                candidateMetadata(candidate)

                Spacer(minLength: 4)

                Label("Choose this", systemImage: "checkmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .routinaGlassCard(
            cornerRadius: 22,
            tint: .accentColor,
            tintOpacity: 0.08,
            interactive: true
        )
        .accessibilityLabel("Choose \(candidate.title)")
    }

    private func candidateMetadata(_ candidate: TaskChoiceCandidate) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("Importance: \(candidate.importance.title)", systemImage: "arrow.up.circle")
            Label("Urgency: \(candidate.urgency.title)", systemImage: "arrow.right.circle")
            Label(pressureTitle(for: candidate), systemImage: "exclamationmark.circle")
            Label("Thinking: \(candidate.thinkingNeeded.title)", systemImage: "lightbulb")

            if let estimatedDurationMinutes = candidate.estimatedDurationMinutes {
                Label("Estimate: \(estimatedDurationMinutes) min", systemImage: "clock")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    private var recommendation: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            if let recommendedTask = store.currentWinner {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.green)

                    Text("Start with this")
                        .font(.title2.weight(.semibold))

                    Text(recommendedTask.title)
                        .font(.title.weight(.bold))
                        .multilineTextAlignment(.center)

                    Text("It won your \(store.condition.summary.lowercased()) comparison.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    candidateMetadata(recommendedTask)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .routinaGlassPill(tint: .accentColor, tintOpacity: 0.08)

                    Button {
                        store.send(.taskDetailsTapped(recommendedTask.id))
                    } label: {
                        Label("Check task details", systemImage: "info.circle")
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Choose with different conditions") {
                        store.send(.startAgainTapped)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(24)
                .routinaGlassCard(
                    cornerRadius: 24,
                    tint: .accentColor,
                    tintOpacity: 0.08,
                    interactive: false
                )
            }

            Spacer(minLength: 0)
        }
        .padding(24)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No tasks to compare", systemImage: "checkmark.circle")
        } description: {
            Text("There are no active tasks that can be recommended right now.")
        } actions: {
            Button("Change conditions") {
                store.send(.startAgainTapped)
            }
        }
    }

    private var failureState: some View {
        ContentUnavailableView {
            Label("Couldn’t find tasks", systemImage: "exclamationmark.triangle")
        } description: {
            Text(store.errorMessage ?? "Try again.")
        } actions: {
            Button("Try again") {
                store.send(.findTasksTapped)
            }
        }
    }

    private func pressureTitle(for candidate: TaskChoiceCandidate) -> String {
        candidate.pressure == .none
            ? "Pressure: not set"
            : "Pressure: \(candidate.pressure.title)"
    }
}
