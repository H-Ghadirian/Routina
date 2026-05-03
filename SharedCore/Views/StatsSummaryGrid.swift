import SwiftUI

struct StatsSummaryCardItem: Identifiable {
    let icon: String
    let accent: Color
    let title: String
    let value: String
    let caption: String
    let accessibilityIdentifier: String
    let showsAccessory: Bool

    var id: String { accessibilityIdentifier }

    init(
        icon: String,
        accent: Color,
        title: String,
        value: String,
        caption: String,
        accessibilityIdentifier: String,
        showsAccessory: Bool = false
    ) {
        self.icon = icon
        self.accent = accent
        self.title = title
        self.value = value
        self.caption = caption
        self.accessibilityIdentifier = accessibilityIdentifier
        self.showsAccessory = showsAccessory
    }
}

struct StatsSummaryGrid<Accessory: View>: View {
    let items: [StatsSummaryCardItem]
    let minimumCardWidth: CGFloat
    let colorScheme: ColorScheme
    let surfaceGradient: LinearGradient
    let accessory: (StatsSummaryCardItem) -> Accessory

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(
                        minimum: minimumCardWidth,
                        maximum: 280
                    ),
                    spacing: 14
                )
            ],
            spacing: 14
        ) {
            ForEach(items) { item in
                StatsSummaryCard(
                    icon: item.icon,
                    accent: item.accent,
                    title: item.title,
                    value: item.value,
                    caption: item.caption,
                    accessibilityIdentifier: item.accessibilityIdentifier,
                    colorScheme: colorScheme,
                    surfaceGradient: surfaceGradient,
                    accessibilityChildren: item.showsAccessory ? .contain : .combine
                ) {
                    accessory(item)
                }
            }
        }
    }
}

extension StatsSummaryGrid where Accessory == EmptyView {
    init(
        items: [StatsSummaryCardItem],
        minimumCardWidth: CGFloat,
        colorScheme: ColorScheme,
        surfaceGradient: LinearGradient
    ) {
        self.init(
            items: items,
            minimumCardWidth: minimumCardWidth,
            colorScheme: colorScheme,
            surfaceGradient: surfaceGradient,
            accessory: { _ in EmptyView() }
        )
    }
}
