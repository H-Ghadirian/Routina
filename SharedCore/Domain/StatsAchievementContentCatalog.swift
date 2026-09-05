import Foundation

private final class StatsAchievementContentBundleToken: NSObject {}

enum StatsAchievementSubtitleVariant: String {
    case standard
    case withoutPlaces
}

struct StatsAchievementContentCatalog {
    struct CountUnit: Decodable, Equatable {
        let singular: String
        let plural: String
    }

    struct AchievementContent: Decodable, Equatable {
        let id: String
        let title: String
        let subtitle: String
        let countUnit: CountUnit?
        let alternateSubtitles: [String: String]?

        func subtitle(for variant: StatsAchievementSubtitleVariant) -> String {
            guard variant != .standard else { return subtitle }
            guard let alternateSubtitle = alternateSubtitles?[variant.rawValue] else {
                preconditionFailure(
                    "Achievement \(id) is missing subtitle variant \(variant.rawValue)."
                )
            }
            return alternateSubtitle
        }
    }

    private struct Payload: Decodable {
        let achievements: [AchievementContent]
    }

    let achievements: [AchievementContent]
    private let contentByID: [String: AchievementContent]

    static let shared = load()

    static func decode(_ data: Data) throws -> StatsAchievementContentCatalog {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return try StatsAchievementContentCatalog(achievements: payload.achievements)
    }

    func content(for id: String) -> AchievementContent {
        guard let content = contentByID[id] else {
            preconditionFailure("Achievement content is missing id \(id).")
        }
        return content
    }

    private init(achievements: [AchievementContent]) throws {
        guard !achievements.isEmpty else {
            throw StatsAchievementContentCatalogError.emptyCatalog
        }

        var contentByID: [String: AchievementContent] = [:]
        for content in achievements {
            guard contentByID[content.id] == nil else {
                throw StatsAchievementContentCatalogError.duplicateAchievementID(content.id)
            }
            guard
                !content.id.isEmpty,
                !content.title.isEmpty,
                !content.subtitle.isEmpty,
                content.countUnit.map({ !$0.singular.isEmpty && !$0.plural.isEmpty }) ?? true,
                content.alternateSubtitles?.values.allSatisfy({ !$0.isEmpty }) ?? true
            else {
                throw StatsAchievementContentCatalogError.incompleteAchievement(content.id)
            }
            contentByID[content.id] = content
        }

        self.achievements = achievements
        self.contentByID = contentByID
    }

    private static func load() -> StatsAchievementContentCatalog {
        guard let resourceURL = bundledResourceURL else {
            preconditionFailure(
                "StatsAchievementContentCatalog.json is missing from the resource bundle."
            )
        }

        do {
            return try decode(Data(contentsOf: resourceURL))
        } catch {
            preconditionFailure("StatsAchievementContentCatalog.json is invalid: \(error)")
        }
    }

    static var bundledResourceURL: URL? {
        resourceBundles.lazy.compactMap(resourceURL(in:)).first
    }

    private static func resourceURL(in bundle: Bundle) -> URL? {
        bundle.url(
            forResource: "StatsAchievementContentCatalog",
            withExtension: "json"
        )
            ?? bundle.url(
                forResource: "StatsAchievementContentCatalog",
                withExtension: "json",
                subdirectory: nil,
                localization: "en"
            )
    }

    private static var resourceBundles: [Bundle] {
        #if SWIFT_PACKAGE
            [Bundle.module]
        #else
            uniqueBundles(
                [Bundle.main, Bundle(for: StatsAchievementContentBundleToken.self)]
                    + Bundle.allBundles
                    + Bundle.allFrameworks
            )
        #endif
    }

    private static func uniqueBundles(_ bundles: [Bundle]) -> [Bundle] {
        var seenURLs: Set<URL> = []
        return bundles.filter { seenURLs.insert($0.bundleURL).inserted }
    }
}

enum StatsAchievementContentCatalogError: Error, Equatable {
    case emptyCatalog
    case duplicateAchievementID(String)
    case incompleteAchievement(String)
}

extension StatsAchievementProgress {
    static func catalogued(
        id: String,
        subtitleVariant: StatsAchievementSubtitleVariant = .standard,
        systemImage: String,
        domain: StatsAchievementDomain,
        category: StatsAchievementCategory,
        currentValue: Double,
        targetValue: Double,
        unit: StatsAchievementUnit? = nil
    ) -> StatsAchievementProgress {
        let content = StatsAchievementContentCatalog.shared.content(for: id)
        let resolvedUnit: StatsAchievementUnit
        if let unit {
            resolvedUnit = unit
        } else if let countUnit = content.countUnit {
            resolvedUnit = .count(
                singular: countUnit.singular,
                plural: countUnit.plural
            )
        } else {
            preconditionFailure("Achievement content \(id) is missing a count unit.")
        }

        return StatsAchievementProgress(
            id: id,
            title: content.title,
            subtitle: content.subtitle(for: subtitleVariant),
            systemImage: systemImage,
            domain: domain,
            category: category,
            currentValue: currentValue,
            targetValue: targetValue,
            unit: resolvedUnit
        )
    }
}
