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

        for (defaultIndex, itemID) in defaultItemIDs.enumerated() where !seenIDs.contains(itemID) {
            let insertionIndex = insertionIndex(
                forMissingDefaultAt: defaultIndex,
                defaultItemIDs: defaultItemIDs,
                normalizedIDs: normalizedIDs
            )
            normalizedIDs.insert(itemID, at: insertionIndex)
            seenIDs.insert(itemID)
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

    private static func insertionIndex(
        forMissingDefaultAt defaultIndex: Int,
        defaultItemIDs: [String],
        normalizedIDs: [String]
    ) -> Int {
        if defaultIndex > defaultItemIDs.startIndex {
            for predecessorIndex in stride(from: defaultIndex - 1, through: defaultItemIDs.startIndex, by: -1) {
                let predecessorID = defaultItemIDs[predecessorIndex]
                if let index = normalizedIDs.firstIndex(of: predecessorID) {
                    return normalizedIDs.index(after: index)
                }
            }
        }

        for successorIndex in defaultItemIDs.index(after: defaultIndex)..<defaultItemIDs.endIndex {
            let successorID = defaultItemIDs[successorIndex]
            if let index = normalizedIDs.firstIndex(of: successorID) {
                return index
            }
        }

        return normalizedIDs.endIndex
    }
}
