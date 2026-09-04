import Foundation

struct HomeAdventureContentCatalog: Decodable, Equatable {
    let coinRules: [HomeAdventureCoinRule]
    let worlds: [WorldTemplate]
    let items: [ItemTemplate]

    static let shared = load()

    static func decode(_ data: Data) throws -> HomeAdventureContentCatalog {
        let catalog = try JSONDecoder().decode(HomeAdventureContentCatalog.self, from: data)
        try catalog.validate()
        return catalog
    }

    private static func load() -> HomeAdventureContentCatalog {
        guard
            let resourceURL = Bundle.main.url(
                forResource: "HomeAdventureCatalog",
                withExtension: "json"
            )
        else {
            preconditionFailure("HomeAdventureCatalog.json is missing from the app bundle.")
        }

        do {
            return try decode(Data(contentsOf: resourceURL))
        } catch {
            preconditionFailure("HomeAdventureCatalog.json is invalid: \(error)")
        }
    }

    private func validate() throws {
        guard !coinRules.isEmpty, !worlds.isEmpty, !items.isEmpty else {
            throw HomeAdventureContentCatalogError.emptyCatalog
        }
        guard Set(coinRules.map(\.id)).count == coinRules.count else {
            throw HomeAdventureContentCatalogError.duplicateCoinRuleID
        }
        guard Set(worlds.map(\.id)).count == worlds.count else {
            throw HomeAdventureContentCatalogError.duplicateWorldID
        }
        let stages = worlds.flatMap(\.stages)
        guard Set(stages.map(\.id)).count == stages.count else {
            throw HomeAdventureContentCatalogError.duplicateStageID
        }
        guard
            worlds.allSatisfy({ world in
                world.stages.allSatisfy { $0.worldID == world.id }
            })
        else {
            throw HomeAdventureContentCatalogError.mismatchedStageWorld
        }
        guard Set(items.map(\.id)).count == items.count else {
            throw HomeAdventureContentCatalogError.duplicateItemID
        }
    }
}

enum HomeAdventureContentCatalogError: Error {
    case emptyCatalog
    case duplicateCoinRuleID
    case duplicateWorldID
    case duplicateStageID
    case mismatchedStageWorld
    case duplicateItemID
}

extension HomeAdventureCoinRule {
    static let all = HomeAdventureContentCatalog.shared.coinRules
}

struct WorldTemplate: Decodable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let accentName: String
    let artAssetName: String
    let requiredCoins: Int
    let requiredActions: Int
    let stages: [StageTemplate]
}

struct StageTemplate: Decodable, Equatable {
    let id: String
    let worldID: String
    let number: Int
    let title: String
    let subtitle: String
    let requiredCoins: Int
    let requiredActions: Int
    let requiredActiveDays: Int
    let rewardCoins: Int
}

struct ItemTemplate: Decodable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let kind: HomeAdventureItem.Kind
    let requiredCoins: Int
    let requiredStageCount: Int
}
