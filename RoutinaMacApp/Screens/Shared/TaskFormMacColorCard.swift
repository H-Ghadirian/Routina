import SwiftUI

struct TaskFormMacColorCard: View {
    let model: TaskFormModel

    var body: some View {
        TaskFormMacSectionCard(title: "Color") {
            TaskFormMacControlBlock(
                title: "Background Color",
                caption: "Sets a tint on the task row and detail screen background."
            ) {
                HStack(spacing: 12) {
                    ForEach(RoutineTaskColor.allCases, id: \.self) { color in
                        Button {
                            model.color.wrappedValue = color
                        } label: {
                            ZStack {
                                if let c = color.swiftUIColor {
                                    Circle()
                                        .fill(c)
                                        .frame(width: 26, height: 26)
                                } else {
                                    Circle()
                                        .fill(Color.secondary.opacity(0.12))
                                        .frame(width: 26, height: 26)
                                    Image(systemName: "circle.slash")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.secondary)
                                }
                                if model.color.wrappedValue == color {
                                    Circle()
                                        .strokeBorder(Color.primary, lineWidth: 2)
                                        .frame(width: 32, height: 32)
                                }
                            }
                            .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .help(color.displayName)
                    }

                    ZStack {
                        ColorPicker(
                            "",
                            selection: customColorPickerBinding,
                            supportsOpacity: false
                        )
                        .labelsHidden()
                        .frame(width: 26, height: 26)
                        .clipShape(Circle())

                        if case .custom = model.color.wrappedValue {
                            Circle()
                                .strokeBorder(Color.primary, lineWidth: 2)
                                .frame(width: 32, height: 32)
                        }
                    }
                    .frame(width: 32, height: 32)
                    .help("Custom color")
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var customColorPickerBinding: Binding<Color> {
        Binding(
            get: {
                if case .custom(let hex) = model.color.wrappedValue {
                    return Color(hex: hex)
                }
                return .white
            },
            set: { color in
                if let hex = color.hexString {
                    model.color.wrappedValue = .custom(hex: hex)
                }
            }
        )
    }
}
