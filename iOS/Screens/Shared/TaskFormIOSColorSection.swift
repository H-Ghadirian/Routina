import SwiftUI

struct TaskFormIOSColorSection: View {
    let model: TaskFormModel

    var body: some View {
        Section(header: Text("Color")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(RoutineTaskColor.allCases, id: \.self) { color in
                        Button {
                            model.color.wrappedValue = color
                        } label: {
                            ZStack {
                                if let c = color.swiftUIColor {
                                    Circle()
                                        .fill(c)
                                        .frame(width: 30, height: 30)
                                } else {
                                    Circle()
                                        .fill(Color.secondary.opacity(0.12))
                                        .frame(width: 30, height: 30)
                                    Image(systemName: "circle.slash")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.secondary)
                                }
                                if model.color.wrappedValue == color {
                                    Circle()
                                        .strokeBorder(Color.primary, lineWidth: 2.5)
                                        .frame(width: 36, height: 36)
                                }
                            }
                            .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(color.displayName)
                    }

                    ZStack {
                        ColorPicker(
                            "",
                            selection: customColorPickerBinding,
                            supportsOpacity: false
                        )
                        .labelsHidden()
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())

                        if case .custom = model.color.wrappedValue {
                            Circle()
                                .strokeBorder(Color.primary, lineWidth: 2.5)
                                .frame(width: 36, height: 36)
                        }
                    }
                    .frame(width: 36, height: 36)
                    .accessibilityLabel("Custom color")
                }
                .padding(.vertical, 6)
            }
            Text("Sets a tint on the task row and detail screen background.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
