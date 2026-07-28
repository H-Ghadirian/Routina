import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

struct HomeMacTaskListSectionDragPayload: Codable, Transferable {
    let sectionID: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .routinaHomeTaskListSection)
    }
}

private extension UTType {
    static let routinaHomeTaskListSection = UTType(
        exportedAs: "app.routina.home-task-list-section"
    )
}

struct HomeMacTaskListSectionReorderHandle: View {
    let sectionID: String
    let title: String
    let systemImage: String
    let tint: Color

    @State private var isHovered = false

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.caption.weight(.semibold))
            .foregroundStyle(isHovered ? tint : Color.secondary)
            .frame(width: 28, height: 28)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tint.opacity(isHovered ? 0.12 : 0.001))
            }
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .draggable(HomeMacTaskListSectionDragPayload(sectionID: sectionID)) {
                Label(title, systemImage: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            .onHover { isHovered = $0 }
            .help("Drag to move \(title) up or down")
            .accessibilityLabel("Reorder \(title)")
            .accessibilityHint("Drag to change this section's position in the task list")
    }
}
