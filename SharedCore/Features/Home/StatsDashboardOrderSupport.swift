import Foundation

enum StatsDashboardOrderSupport {
    static func orderedItems<Item>(
        _ items: [Item],
        storedRawValue: String?
    ) -> [Item] where Item: Equatable & RawRepresentable, Item.RawValue == String {
        let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.rawValue, $0) })
        return normalizedItemIDs(
            defaultItemIDs: items.map(\.rawValue),
            storedRawValue: storedRawValue
        )
        .compactMap { itemsByID[$0] }
    }

    static func normalizedItemIDs(
        defaultItemIDs: [String],
        storedRawValue: String?
    ) -> [String] {
        let defaultIDSet = Set(defaultItemIDs)
        var seenIDs = Set<String>()
        var normalizedIDs: [String] = []

        for itemID in itemIDs(from: storedRawValue) where defaultIDSet.contains(itemID) && !seenIDs.contains(itemID) {
            normalizedIDs.append(itemID)
            seenIDs.insert(itemID)
        }

        for itemID in defaultItemIDs where !seenIDs.contains(itemID) {
            normalizedIDs.append(itemID)
        }

        return normalizedIDs
    }

    static func movedItemIDs(
        draggedItemID: String,
        before targetItemID: String,
        in orderedItemIDs: [String]
    ) -> [String] {
        guard draggedItemID != targetItemID,
              let sourceIndex = orderedItemIDs.firstIndex(of: draggedItemID),
              orderedItemIDs.contains(targetItemID) else {
            return orderedItemIDs
        }

        var updatedIDs = orderedItemIDs
        let movedID = updatedIDs.remove(at: sourceIndex)
        let targetIndex = updatedIDs.firstIndex(of: targetItemID) ?? updatedIDs.endIndex
        updatedIDs.insert(movedID, at: targetIndex)
        return updatedIDs
    }

    static func storedRawValue(
        for orderedItemIDs: [String],
        defaultItemIDs: [String]
    ) -> String? {
        let normalizedIDs = normalizedItemIDs(
            defaultItemIDs: defaultItemIDs,
            storedRawValue: orderedItemIDs.joined(separator: ",")
        )
        guard normalizedIDs != defaultItemIDs else { return nil }
        return normalizedIDs.joined(separator: ",")
    }

    private static func itemIDs(from rawValue: String?) -> [String] {
        rawValue?
            .split(separator: ",")
            .map(String.init) ?? []
    }
}
