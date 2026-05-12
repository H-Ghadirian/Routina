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
                    let isSelected = selectedMode == mode

                    Text(mode.rawValue)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .routinaGlassPill(
                            tint: isSelected ? .accentColor : .secondary,
                            tintOpacity: isSelected ? 0.42 : 0.10,
                            interactive: true
                        )
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(mode.accessibilityLabel)
                .help(mode.rawValue)
            }
        }
    }
}
