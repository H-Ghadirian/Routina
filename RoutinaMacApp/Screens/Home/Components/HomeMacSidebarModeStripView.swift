import SwiftUI

struct HomeMacSidebarModeStripView: View {
    @Binding var selectedMode: HomeFeature.MacSidebarMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(HomeFeature.MacSidebarMode.sidebarStripModes) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    let isSelected = selectedMode == mode
                    let isAddTab = mode == .addTask

                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.clear)
                            .routinaIf(isSelected) { view in
                                view.routinaGlassCard(
                                    cornerRadius: 10,
                                    tint: .accentColor,
                                    tintOpacity: 0.42,
                                    interactive: true
                                )
                            }

                        Image(systemName: sidebarModeIcon(for: mode))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(
                                isSelected ? Color.white : (isAddTab ? Color.accentColor : Color.secondary)
                            )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(mode.rawValue)
                .help(mode.rawValue)

                if mode == .settings {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1)
                        .padding(.vertical, 8)
                }
            }
        }
        .frame(height: 42)
        .padding(4)
        .routinaGlassPanel(cornerRadius: 13, tint: .secondary, tintOpacity: 0.10)
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func sidebarModeIcon(for mode: HomeFeature.MacSidebarMode) -> String {
        switch mode {
        case .routines: return "checklist"
        case .board: return "square.grid.3x3.topleft.filled"
        case .goals: return "target"
        case .timeline: return "clock.arrow.circlepath"
        case .stats: return "chart.bar.xaxis"
        case .settings: return "gearshape"
        case .addTask: return "plus"
        }
    }
}
