import SwiftUI

struct MacQuickAddCreatedToast: Equatable, Identifiable {
    let id = UUID()
    let taskID: UUID
    let taskName: String
}

struct MacHomeNoticeToast: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let systemImage: String
    let tint: Color
}

struct MacQuickAddCreatedToastView: View {
    let toast: MacQuickAddCreatedToast
    let onOpen: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.green)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text("Task created")
                    .font(.subheadline.weight(.semibold))

                Text(toast.taskName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Button("Open details") {
                onOpen()
            }
            .buttonStyle(.link)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close")
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 360, alignment: .leading)
        .routinaGlassPanel(cornerRadius: 14, tint: .green, tintOpacity: 0.08, interactive: true)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 20, y: 10)
    }
}

struct MacHomeNoticeToastView: View {
    let toast: MacHomeNoticeToast
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: toast.systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(toast.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(toast.title)
                    .font(.subheadline.weight(.semibold))

                Text(toast.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close")
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 360, alignment: .leading)
        .routinaGlassPanel(cornerRadius: 14, tint: toast.tint, tintOpacity: 0.08, interactive: true)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 20, y: 10)
    }
}
