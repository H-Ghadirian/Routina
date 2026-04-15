import SwiftUI

struct HomeMacTaskListModeStripView: View {
    let selectedMode: HomeFeature.TaskListMode
    let onSelectMode: (HomeFeature.TaskListMode) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(HomeFeature.TaskListMode.allCases) { mode in
                Button {
                    onSelectMode(mode)
                } label: {
                    Text(mode.rawValue)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .foregroundStyle(selectedMode == mode ? Color.white : Color.primary)
                        .background(
                            Capsule()
                                .fill(selectedMode == mode ? Color.accentColor : Color.secondary.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
