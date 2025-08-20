import Foundation

struct SprintBoardClient: Sendable {
    var load: @Sendable () async throws -> SprintBoardData
    var save: @Sendable (SprintBoardData) async throws -> Void
}

extension SprintBoardClient {
    static let live = SprintBoardClient(
        load: {
            try loadLiveSnapshot()
        },
        save: { sprintBoardData in
            let url = try sprintBoardStoreURL()
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(sprintBoardData)
            try data.write(to: url, options: [.atomic])
        }
    )

    static let noop = SprintBoardClient(
        load: { SprintBoardData() },
        save: { _ in }
    )

    static func loadLiveSnapshot() throws -> SprintBoardData {
        let url = try sprintBoardStoreURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return SprintBoardData()
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SprintBoardData.self, from: data)
    }
}

private func sprintBoardStoreURL() throws -> URL {
    let applicationSupportDirectory = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    let storesDirectory = applicationSupportDirectory.appendingPathComponent("RoutinaData", isDirectory: true)
    return storesDirectory.appendingPathComponent("SprintBoard.json")
}
