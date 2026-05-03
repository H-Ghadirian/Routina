import SwiftUI

struct MacPlaceFilterRow: View {
    let option: MacPlaceFilterOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.10))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(option.place.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        MacPlaceStatusBadge(status: option.status)
                    }

                    Text(option.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.07))
            )
        }
        .buttonStyle(.plain)
    }
}

struct MacPlaceStatusBadge: View {
    let status: MacPlaceFilterOption.Status

    var body: some View {
        Text(labelText)
            .font(.caption2.weight(.bold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
    }

    private var labelText: String {
        switch status {
        case .here:
            return "Here"
        case let .away(distanceMeters):
            if distanceMeters < 1_000 {
                return "\(Int(distanceMeters.rounded())) m away"
            }
            return String(format: "%.1f km", distanceMeters / 1_000)
        case .unknown:
            return "Unknown"
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .here:
            return .green
        case .away:
            return .orange
        case .unknown:
            return .secondary
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .here:
            return Color.green.opacity(0.15)
        case .away:
            return Color.orange.opacity(0.16)
        case .unknown:
            return Color.secondary.opacity(0.12)
        }
    }
}
