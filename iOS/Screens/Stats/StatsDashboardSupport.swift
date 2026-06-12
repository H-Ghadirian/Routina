import SwiftUI

enum StatsDashboardBlock: Identifiable {
    case section(StatsDashboardItem)
    case summaryCards([StatsDashboardItem])

    var id: String {
        switch self {
        case let .section(item):
            return item.rawValue
        case let .summaryCards(items):
            return "summaryCards:" + items.map(\.rawValue).joined(separator: ",")
        }
    }
}

enum StatsDashboardItem: String, CaseIterable, Identifiable {
    case hero
    case dailyAverage
    case healthSteps
    case healthActiveCalories
    case healthDistance
    case healthExercise
    case focusTime
    case sleepTime
    case sleepSessions
    case awayTime
    case emotions
    case notes
    case events
    case goals
    case focusAverage
    case bestDay
    case totalDones
    case totalCancels
    case totalMissed
    case routineCount
    case todoCount
    case activeItems
    case archivedItems
    case unassignedFocus
    case completionChart
    case hourlyActivity
    case tagUsage
    case focusChart
    case focus2048
    case recentWins
    case focusAchievements
    case focusWorkChart
    case estimateActual
    case goalProgress
    case emotionTrend
    case gitHub

    var id: String { rawValue }

    init(summaryAccessibilityIdentifier: String) {
        switch summaryAccessibilityIdentifier {
        case "stats.summary.dailyAverage":
            self = .dailyAverage
        case "stats.summary.health.steps":
            self = .healthSteps
        case "stats.summary.health.activeCalories":
            self = .healthActiveCalories
        case "stats.summary.health.distance":
            self = .healthDistance
        case "stats.summary.health.exercise":
            self = .healthExercise
        case "stats.summary.focusTime":
            self = .focusTime
        case "stats.summary.sleepTime":
            self = .sleepTime
        case "stats.summary.sleepSessions":
            self = .sleepSessions
        case "stats.summary.awayTime":
            self = .awayTime
        case "stats.summary.emotions":
            self = .emotions
        case "stats.summary.notes":
            self = .notes
        case "stats.summary.events":
            self = .events
        case "stats.summary.goals":
            self = .goals
        case "stats.summary.focusAverage":
            self = .focusAverage
        case "stats.summary.bestDay":
            self = .bestDay
        case "stats.summary.totalDones":
            self = .totalDones
        case "stats.summary.totalCancels":
            self = .totalCancels
        case "stats.summary.totalMissed":
            self = .totalMissed
        case "stats.summary.routineCount":
            self = .routineCount
        case "stats.summary.todoCount":
            self = .todoCount
        case "stats.summary.activeRoutines":
            self = .activeItems
        case "stats.summary.archivedRoutines":
            self = .archivedItems
        default:
            self = .hero
        }
    }

    var title: String {
        switch self {
        case .hero:
            return "Activity overview"
        case .dailyAverage:
            return "Daily average"
        case .healthSteps:
            return "Steps"
        case .healthActiveCalories:
            return "Active calories"
        case .healthDistance:
            return "Distance"
        case .healthExercise:
            return "Exercise"
        case .focusTime:
            return "Focus time"
        case .sleepTime:
            return "Sleep time"
        case .sleepSessions:
            return "Sleep sessions"
        case .awayTime:
            return "Away time"
        case .emotions:
            return "Emotions"
        case .notes:
            return "Notes"
        case .events:
            return "Events"
        case .goals:
            return "Goals"
        case .focusAverage:
            return "Focus average"
        case .bestDay:
            return "Best day"
        case .totalDones:
            return "Done"
        case .totalCancels:
            return "Canceled"
        case .totalMissed:
            return "Missed"
        case .routineCount:
            return "Routines"
        case .todoCount:
            return "Todos"
        case .activeItems:
            return "Active items"
        case .archivedItems:
            return "Archived items"
        case .unassignedFocus:
            return "Unassigned focus"
        case .completionChart:
            return "Activity chart"
        case .hourlyActivity:
            return "24-hour rhythm"
        case .tagUsage:
            return "Tag usage"
        case .focusChart:
            return "Focus chart"
        case .focus2048:
            return "Focus 2048"
        case .recentWins:
            return "Recent Wins"
        case .focusAchievements:
            return "Achievements"
        case .focusWorkChart:
            return "Focus vs done"
        case .estimateActual:
            return "Estimated vs actual"
        case .goalProgress:
            return "Goal momentum"
        case .emotionTrend:
            return "Emotion trends"
        case .gitHub:
            return "GitHub stats"
        }
    }

    var subtitle: String {
        switch self {
        case .hero:
            return "The large stats summary at the top of the screen."
        case .dailyAverage, .healthSteps, .healthActiveCalories, .healthDistance, .healthExercise, .focusTime, .sleepTime, .sleepSessions, .awayTime, .emotions, .notes, .events, .goals, .focusAverage, .bestDay, .totalDones, .totalCancels, .totalMissed, .routineCount, .todoCount, .activeItems, .archivedItems:
            return "A compact stats card in the summary grid."
        case .unassignedFocus:
            return "Focus sessions waiting to be assigned."
        case .completionChart:
            return "A bar chart of done, missed, and canceled activity over time."
        case .hourlyActivity:
            return "A 24-hour chart of focus, done work, created tasks, and activity."
        case .tagUsage:
            return "A bubble chart of tag activity."
        case .focusChart:
            return "A bar chart of focus time over time."
        case .focus2048:
            return "A 2048-style board generated from focused hours."
        case .recentWins:
            return "Today, week, month, and year accomplishments."
        case .focusAchievements:
            return "All-time badges and achievement progress."
        case .focusWorkChart:
            return "A scatter chart comparing focus time with completed work."
        case .estimateActual:
            return "A grouped bar chart comparing planned and logged time."
        case .goalProgress:
            return "Progress bars for active goals with linked work."
        case .emotionTrend:
            return "A line chart of pleasantness and energy over time."
        case .gitHub:
            return "Contribution and repository activity."
        }
    }

    var systemImage: String {
        switch self {
        case .hero:
            return "chart.line.uptrend.xyaxis"
        case .dailyAverage:
            return "gauge.with.dots.needle.50percent"
        case .healthSteps:
            return "figure.walk"
        case .healthActiveCalories:
            return "flame.fill"
        case .healthDistance:
            return "map.fill"
        case .healthExercise:
            return "figure.run"
        case .focusTime:
            return "timer"
        case .sleepTime:
            return "bed.double.fill"
        case .sleepSessions:
            return "moon.fill"
        case .awayTime:
            return "lock.shield.fill"
        case .emotions:
            return "heart.fill"
        case .notes:
            return "note.text"
        case .events:
            return "calendar"
        case .goals:
            return "target"
        case .focusAverage:
            return "stopwatch.fill"
        case .bestDay:
            return "bolt.fill"
        case .totalDones:
            return "checkmark.seal.fill"
        case .totalCancels:
            return "xmark.seal.fill"
        case .totalMissed:
            return "exclamationmark.triangle.fill"
        case .routineCount:
            return "arrow.clockwise"
        case .todoCount:
            return "checkmark.circle"
        case .activeItems:
            return "checklist.checked"
        case .archivedItems:
            return "archivebox.fill"
        case .unassignedFocus:
            return "tray.full"
        case .completionChart:
            return "chart.bar.xaxis"
        case .hourlyActivity:
            return "clock"
        case .tagUsage:
            return "tag.fill"
        case .focusChart:
            return "chart.xyaxis.line"
        case .focus2048:
            return "square.grid.3x3.fill"
        case .recentWins:
            return "party.popper.fill"
        case .focusAchievements:
            return "medal.fill"
        case .focusWorkChart:
            return "chart.dots.scatter"
        case .estimateActual:
            return "timer"
        case .goalProgress:
            return "target"
        case .emotionTrend:
            return "heart.text.square.fill"
        case .gitHub:
            return "chevron.left.forwardslash.chevron.right"
        }
    }

    var isSummaryCard: Bool {
        switch self {
        case .dailyAverage, .healthSteps, .healthActiveCalories, .healthDistance, .healthExercise, .focusTime, .sleepTime, .sleepSessions, .awayTime, .emotions, .notes, .events, .goals, .focusAverage, .bestDay, .totalDones, .totalCancels, .totalMissed, .routineCount, .todoCount, .activeItems, .archivedItems:
            return true
        default:
            return false
        }
    }

    func isIncluded(in scope: StatsDashboardScope) -> Bool {
        switch scope {
        case .all:
            return true
        case .focus:
            return isFocusRelated
        case .sleep:
            return isSleepRelated
        case .wins:
            return self == .recentWins
        case .achievements:
            return self == .focusAchievements
        }
    }

    private var isFocusRelated: Bool {
        switch self {
        case .focusTime,
             .awayTime,
             .focusAverage,
             .unassignedFocus,
             .focusChart,
             .focus2048,
             .focusWorkChart:
            return true
        default:
            return false
        }
    }

    private var isSleepRelated: Bool {
        switch self {
        case .sleepTime,
             .sleepSessions:
            return true
        default:
            return false
        }
    }

    func isAvailable(
        selectedRange: DoneChartRange,
        isGitFeaturesEnabled: Bool,
        isStatsWinsEnabled: Bool
    ) -> Bool {
        switch self {
        case .dailyAverage, .focusAverage, .bestDay, .completionChart, .focusChart, .focusWorkChart:
            return selectedRange != .today
        case .gitHub:
            return isGitFeaturesEnabled
        case .recentWins:
            return isStatsWinsEnabled
        default:
            return true
        }
    }
}

struct StatsHealthAccessCard: View {
    let accessState: HealthStatsAccessState
    let isLoading: Bool
    let errorMessage: String?
    let colorScheme: ColorScheme
    let onRequestAccess: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "heart.text.square.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.pink)
                    .frame(width: 44, height: 44)
                    .routinaGlassCard(cornerRadius: 15, tint: .pink, tintOpacity: colorScheme == .dark ? 0.2 : 0.12)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
            }

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Reading Health data")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            } else if showsAction {
                Button(action: action) {
                    Label(actionTitle, systemImage: actionIcon)
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinaGlassPanel(cornerRadius: 24, tint: .pink, tintOpacity: colorScheme == .dark ? 0.12 : 0.08)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.4), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("stats.health.access")
    }

    private var title: String {
        switch accessState {
        case .unavailable:
            return "Health unavailable"
        case .notRequested, .ready, .failed:
            return "Apple Health"
        }
    }

    private var message: String {
        switch accessState {
        case .unavailable:
            return "Health data is unavailable on this device."
        case .notRequested:
            return "Connect Apple Health to show movement stats in this range."
        case .ready:
            return "Health stats are connected."
        case .failed:
            return "Routina could not read Health data."
        }
    }

    private var showsAction: Bool {
        accessState != .unavailable
    }

    private var actionTitle: String {
        switch accessState {
        case .notRequested:
            return "Connect Health"
        case .ready:
            return "Refresh"
        case .failed:
            return "Try Again"
        case .unavailable:
            return ""
        }
    }

    private var actionIcon: String {
        switch accessState {
        case .notRequested:
            return "heart.text.square"
        case .ready, .failed:
            return "arrow.clockwise"
        case .unavailable:
            return "heart.slash"
        }
    }

    private func action() {
        switch accessState {
        case .notRequested:
            onRequestAccess()
        case .ready, .failed:
            onRefresh()
        case .unavailable:
            break
        }
    }
}
