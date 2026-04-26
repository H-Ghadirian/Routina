import SwiftUI

struct RoutineTagPill: View {
    enum Size {
        case small
        case regular

        var font: Font {
            switch self {
            case .small: return .caption.weight(.semibold)
            case .regular: return .footnote.weight(.semibold)
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 8
            case .regular: return 10
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: return 3
            case .regular: return 5
            }
        }

        var iconFont: Font {
            switch self {
            case .small: return .caption2.weight(.semibold)
            case .regular: return .caption.weight(.semibold)
            }
        }
    }

    let name: String
    let color: Color?
    var size: Size = .regular
    var showsIcon: Bool = true

    private var tint: Color {
        color ?? .secondary
    }

    var body: some View {
        HStack(spacing: 4) {
            if showsIcon {
                Image(systemName: "tag.fill")
                    .font(size.iconFont)
            }
            Text(name)
                .font(size.font)
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.16))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(tint.opacity(0.35), lineWidth: 0.5)
        )
        .contentShape(Capsule(style: .continuous))
    }
}

extension RoutineTagPill {
    init(tag: RoutineTagSummary, size: Size = .regular, showsIcon: Bool = true) {
        self.init(
            name: tag.name,
            color: tag.displayColor,
            size: size,
            showsIcon: showsIcon
        )
    }
}

#Preview("Tag pills") {
    VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 6) {
            RoutineTagPill(name: "Bug", color: nil)
            RoutineTagPill(name: "Buy", color: .blue)
            RoutineTagPill(name: "Cleaning", color: .green)
            RoutineTagPill(name: "Crypto", color: .orange)
        }
        HStack(spacing: 6) {
            RoutineTagPill(name: "Family", color: .pink, size: .small)
            RoutineTagPill(name: "Feature", color: .purple, size: .small)
            RoutineTagPill(name: "No icon", color: .red, size: .small, showsIcon: false)
        }
    }
    .padding()
}
