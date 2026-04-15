import SwiftUI

struct HomeMacFormSectionNavView<Header: View>: View {
    let availableSections: [String]
    let coordinator: AddEditFormCoordinator
    @Binding var draggedSection: String?
    @ViewBuilder let header: () -> Header

    var body: some View {
        let sections = coordinator.orderedSections(available: availableSections)

        VStack(alignment: .leading, spacing: 0) {
            header()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(sections, id: \.self) { section in
                        let isMovable = section != "Identity"

                        Button {
                            coordinator.scrollTarget = section
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.accentColor.opacity(0.12))
                                    Image(systemName: formSectionIcon(for: section))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.accentColor)
                                }
                                .frame(width: 32, height: 32)

                                Text(section)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)

                                Spacer(minLength: 0)

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.secondary.opacity(0.6))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.secondary.opacity(0.07))
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .opacity(draggedSection == section ? 0.4 : 1)
                        .if(isMovable) { view in
                            view
                                .draggable(section) {
                                    formSectionDragPreview(for: section)
                                }
                                .contextMenu {
                                    formSectionContextMenu(for: section)
                                }
                        }
                        .if(isMovable) { view in
                            view.onDrop(of: [.text], delegate: HomeMacSectionDropDelegate(
                                item: section,
                                coordinator: coordinator,
                                draggedSection: $draggedSection
                            ))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func formSectionDragPreview(for section: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: formSectionIcon(for: section))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text(section)
                .font(.body.weight(.medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThickMaterial)
        )
        .onAppear { draggedSection = section }
    }

    @ViewBuilder
    private func formSectionContextMenu(for section: String) -> some View {
        let ordered = coordinator.orderedSections(available: availableSections)
        let movableOrdered = ordered.filter { $0 != "Identity" }
        let isFirst = movableOrdered.first == section
        let isLast = movableOrdered.last == section

        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                coordinator.moveUp(section)
            }
        } label: {
            Label("Move Up", systemImage: "arrow.up")
        }
        .disabled(isFirst)

        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                coordinator.moveDown(section)
            }
        } label: {
            Label("Move Down", systemImage: "arrow.down")
        }
        .disabled(isLast)
    }

    private func formSectionIcon(for section: String) -> String {
        switch section {
        case "Identity": return "person.fill"
        case "Behavior": return "repeat"
        case "Places": return "mappin.and.ellipse"
        case "Importance & Urgency": return "flag.fill"
        case "Tags": return "tag.fill"
        case "Linked tasks": return "link"
        case "Link URL": return "globe"
        case "Notes": return "note.text"
        case "Steps": return "list.number"
        case "Image": return "photo.fill"
        case "Attachment": return "paperclip"
        case "Danger Zone": return "exclamationmark.triangle.fill"
        default: return "circle.fill"
        }
    }
}

private struct HomeMacSectionDropDelegate: DropDelegate {
    let item: String
    let coordinator: AddEditFormCoordinator
    @Binding var draggedSection: String?

    func performDrop(info: DropInfo) -> Bool {
        draggedSection = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedSection, dragged != item else { return }
        let order = coordinator.sectionOrder
        guard let fromIndex = order.firstIndex(of: dragged),
              let toIndex = order.firstIndex(of: item) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            coordinator.sectionOrder.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggedSection != nil
    }
}
