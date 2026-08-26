import ComposableArchitecture
import SwiftUI

struct HomeIOSWorkspaceNavigationSection: View {
    let backlogStore: StoreOf<BacklogFeature>
    let timelineStore: StoreOf<TimelineFeature>
    let taskRankingStore: StoreOf<TaskRankingFeature>

    var body: some View {
        Section {
            NavigationLink {
                BacklogIOSView(store: backlogStore)
            } label: {
                SettingsNavigationRow(
                    icon: "tray.full",
                    tint: .orange,
                    title: "Backlog",
                    subtitle: "Deferred and hidden tasks"
                )
            }

            NavigationLink {
                HomeIOSTimelineDestination(store: timelineStore)
            } label: {
                SettingsNavigationRow(
                    icon: "clock.arrow.circlepath",
                    tint: .blue,
                    title: "Timeline",
                    subtitle: "Activity and completion history"
                )
            }

            NavigationLink {
                TaskRankingIOSView(store: taskRankingStore)
            } label: {
                SettingsNavigationRow(
                    icon: "arrow.up.arrow.down.circle",
                    tint: .indigo,
                    title: "Task Ladder",
                    subtitle: "Compare active work by task values"
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("More workspaces")
    }
}

private struct HomeIOSTimelineDestination: View {
    let store: StoreOf<TimelineFeature>
    @State private var presentationID = UUID()
    @State private var isActive = false

    var body: some View {
        TimelineView(
            store: store,
            presentationID: presentationID,
            isActive: isActive,
            ownsNavigationContainer: false
        )
        .onAppear {
            isActive = true
        }
        .onDisappear {
            isActive = false
        }
    }
}
