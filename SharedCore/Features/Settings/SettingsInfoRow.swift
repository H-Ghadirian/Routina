import SwiftUI

struct SettingsInfoRow: View {
    let title: String
    let value: String
    let alignment: VerticalAlignment
    let titleStyle: AnyShapeStyle
    let valueStyle: AnyShapeStyle

    init(
        title: String,
        value: String,
        alignment: VerticalAlignment = .top,
        titleStyle: AnyShapeStyle = AnyShapeStyle(.primary),
        valueStyle: AnyShapeStyle = AnyShapeStyle(.secondary)
    ) {
        self.title = title
        self.value = value
        self.alignment = alignment
        self.titleStyle = titleStyle
        self.valueStyle = valueStyle
    }

    var body: some View {
        HStack(alignment: alignment) {
            Text(title)
                .foregroundStyle(titleStyle)

            Spacer()

            Text(value)
                .foregroundStyle(valueStyle)
                .multilineTextAlignment(.trailing)
        }
    }
}
