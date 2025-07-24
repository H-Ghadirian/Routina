import SwiftUI

/// Coordinates scroll-to-section between the sidebar nav and the add/edit form.
@Observable
final class AddEditFormCoordinator {
    var scrollTarget: String?
    var nameFocusRequestID: Int = 0

    /// User-customised ordering of movable sections (persisted via UserDefaults).
    /// Does NOT include "Identity" – that section is always first and not movable.
    var sectionOrder: [String] {
        didSet { Self.persistOrder(sectionOrder) }
    }

    // MARK: - Defaults

    /// The default order of movable sections (Identity excluded).
    static let defaultMovableSections: [String] = [
        "Color", "Behavior", "Estimation", "Places", "Importance & Urgency", "Tags",
        "Linked tasks", "Link URL", "Notes", "Steps", "Image", "Attachment"
    ]

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
    /// "Identity" is always prepended.
    func orderedSections(available: [String]) -> [String] {
        let availableSet = Set(available)
        // Start with sections in the user's custom order that are available
        var result = sectionOrder.filter { availableSet.contains($0) }
        // Append any available sections not yet in the custom order (e.g. Danger Zone)
        for section in available where section != "Identity" && !result.contains(section) {
            result.append(section)
        }
        return ["Identity"] + result
    }

    func moveUp(_ section: String) {
        guard let idx = sectionOrder.firstIndex(of: section), idx > 0 else { return }
        sectionOrder.swapAt(idx, idx - 1)
    }

    func moveDown(_ section: String) {
        guard let idx = sectionOrder.firstIndex(of: section), idx < sectionOrder.count - 1 else { return }
        sectionOrder.swapAt(idx, idx + 1)
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        sectionOrder.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Persistence

    private static let orderKey = UserDefaultStringValueKey.macFormSectionOrder.rawValue

    private static func persistOrder(_ order: [String]) {
        guard let data = try? JSONEncoder().encode(order) else { return }
        SharedDefaults.app.set(data, forKey: orderKey)
    }

    private static func loadOrder() -> [String] {
        guard let data = SharedDefaults.app.data(forKey: orderKey),
              let order = try? JSONDecoder().decode([String].self, from: data) else {
            return defaultMovableSections
        }
        // Merge: keep persisted order, append any new default sections not yet known
        let knownSet = Set(order)
        let newSections = defaultMovableSections.filter { !knownSet.contains($0) }
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
