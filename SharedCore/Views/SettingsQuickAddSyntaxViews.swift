import SwiftUI

struct SettingsQuickAddExampleBlock: View {
    let example: SettingsQuickAddExample

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(example.phrase)
                .font(.subheadline.weight(.semibold).monospaced())
                .textSelection(.enabled)

            Text(example.result)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 5)
    }
}

struct SettingsQuickAddSyntaxBlock: View {
    enum Style {
        case plain
        case badge
    }

    let row: SettingsQuickAddSyntaxItem
    var style: Style = .plain

    var body: some View {
        switch style {
        case .plain:
            plainContent
        case .badge:
            badgeContent
        }
    }

    private var plainContent: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(row.syntax)
                .font(.subheadline.weight(.semibold).monospaced())
                .textSelection(.enabled)

            Text(row.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 5)
    }

    private var badgeContent: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(row.syntax)
                .font(.caption.weight(.semibold).monospaced())
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.mint.opacity(0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.mint.opacity(0.28), lineWidth: 1)
                )

            Text(row.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

struct SettingsQuickAddNoteBlock: View {
    enum Style {
        case plain
        case labeled
    }

    let note: String
    var style: Style = .plain

    var body: some View {
        switch style {
        case .plain:
            Text(note)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        case .labeled:
            Label(note, systemImage: "checkmark.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}
