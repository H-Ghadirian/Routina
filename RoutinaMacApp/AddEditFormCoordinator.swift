import SwiftUI

/// Coordinates scroll-to-section between the sidebar nav and the add/edit form.
@Observable
final class AddEditFormCoordinator {
    var scrollTarget: FormSection?
    var nameFocusRequestID: Int = 0

    /// User-customised ordering of movable sections (persisted via UserDefaults).
    /// Does NOT include `.identity` – that section is always first and not movable.
    var sectionOrder: [FormSection] {
        didSet { Self.persistOrder(sectionOrder) }
    }

    // MARK: - Init

    init() {
        self.sectionOrder = Self.loadOrder()
    }

    func requestNameFocus() {
        nameFocusRequestID += 1
    }

    // MARK: - Reordering helpers

    /// Returns the ordered sections for the sidebar/form, filtering to only those present in
    /// `available` (keeps conditional sections like Steps / Danger Zone correct).
    /// `.identity` is always prepended.
    func orderedSections(available: [FormSection]) -> [FormSection] {
        let availableSet = Set(available)
        // Start with sections in the user's custom order that are available
        var result = sectionOrder.filter { availableSet.contains($0) }
        // Append any available sections not yet in the custom order (e.g. Danger Zone)
        for section in available where section != .identity && !result.contains(section) {
            result.append(section)
        }
        return [.identity] + result
    }

    func moveUp(_ section: FormSection) {
        guard let idx = sectionOrder.firstIndex(of: section), idx > 0 else { return }
        sectionOrder.swapAt(idx, idx - 1)
    }

    func moveDown(_ section: FormSection) {
        guard let idx = sectionOrder.firstIndex(of: section), idx < sectionOrder.count - 1 else { return }
        sectionOrder.swapAt(idx, idx + 1)
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        sectionOrder.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Persistence

    private static let orderKey = UserDefaultStringValueKey.macFormSectionOrder.rawValue

    private static func persistOrder(_ order: [FormSection]) {
        let raws = order.map(\.rawValue)
        guard let data = try? JSONEncoder().encode(raws) else { return }
        SharedDefaults.app.set(data, forKey: orderKey)
    }

    private static func loadOrder() -> [FormSection] {
        guard let data = SharedDefaults.app.data(forKey: orderKey),
              let raws = try? JSONDecoder().decode([String].self, from: data) else {
            return FormSection.defaultMovableOrder
        }
        // Decode known sections, drop unknown ones (older or removed cases).
        let order = raws.compactMap(FormSection.init(rawValue:))
        // Merge: keep persisted order, append any new default sections not yet known
        let known = Set(order)
        let newSections = FormSection.defaultMovableOrder.filter { !known.contains($0) }
        return order + newSections
    }
}

private struct AddEditFormCoordinatorKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue = AddEditFormCoordinator()
}

extension EnvironmentValues {
    var addEditFormCoordinator: AddEditFormCoordinator {
        get { self[AddEditFormCoordinatorKey.self] }
        set { self[AddEditFormCoordinatorKey.self] = newValue }
    }
}
