import Foundation

public struct RoutinaHelpTopic: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let summary: String
    public let details: [String]
    public let aliases: [String]
    public let keywords: [String]
    public let platforms: [String]
    public let availability: String
    public let relatedTopicIDs: [String]
    public let exampleQuestions: [String]

    public init(
        id: String,
        title: String,
        summary: String,
        details: [String],
        aliases: [String],
        keywords: [String],
        platforms: [String],
        availability: String,
        relatedTopicIDs: [String] = [],
        exampleQuestions: [String] = []
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.details = details
        self.aliases = aliases
        self.keywords = keywords
        self.platforms = platforms
        self.availability = availability
        self.relatedTopicIDs = relatedTopicIDs
        self.exampleQuestions = exampleQuestions
    }
}

private struct RoutinaHelpCatalogPayload: Decodable {
    let starterQuestions: [String]
    let topics: [RoutinaHelpTopic]
}

public enum RoutinaHelpCatalog {
    private static let payload = loadPayload()

    public static let starterQuestions = payload.starterQuestions
    public static let topics = payload.topics

    private static func loadPayload() -> RoutinaHelpCatalogPayload {
        guard
            let resourceURL = resourceBundle.url(
                forResource: "RoutinaHelpCatalog",
                withExtension: "json"
            )
        else {
            preconditionFailure("RoutinaHelpCatalog.json is missing from the resource bundle.")
        }

        do {
            let data = try Data(contentsOf: resourceURL)
            return try JSONDecoder().decode(RoutinaHelpCatalogPayload.self, from: data)
        } catch {
            preconditionFailure("RoutinaHelpCatalog.json is invalid: \(error)")
        }
    }

    private static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
            Bundle.module
        #else
            Bundle.main
        #endif
    }

    public static func topic(id: String) -> RoutinaHelpTopic? {
        let normalizedID = normalizedPhrase(id)
        return topics.first { normalizedPhrase($0.id) == normalizedID }
    }

    public static func search(_ query: String, limit: Int = 5) -> [RoutinaHelpTopic] {
        let boundedLimit = max(0, min(limit, 10))
        guard boundedLimit > 0 else { return [] }

        let queryPhrase = normalizedPhrase(query)
        let queryTerms = searchableTerms(query)
        guard !queryTerms.isEmpty else {
            return Array(topics.prefix(boundedLimit))
        }

        return
            topics
            .compactMap { topic -> (topic: RoutinaHelpTopic, score: Int)? in
                let score = score(topic, queryPhrase: queryPhrase, queryTerms: queryTerms)
                return score > 0 ? (topic, score) : nil
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.topic.title.localizedCaseInsensitiveCompare(rhs.topic.title) == .orderedAscending
            }
            .prefix(boundedLimit)
            .map(\.topic)
    }

    private static func score(
        _ topic: RoutinaHelpTopic,
        queryPhrase: String,
        queryTerms: Set<String>
    ) -> Int {
        let title = normalizedPhrase(topic.title)
        let id = normalizedPhrase(topic.id)
        let aliases = topic.aliases.map(normalizedPhrase)

        var result = 0
        if queryPhrase == title || queryPhrase == id || aliases.contains(queryPhrase) {
            result += 200
        } else if title.contains(queryPhrase) || aliases.contains(where: { $0.contains(queryPhrase) }) {
            result += 80
        }

        let titleTerms = searchableTerms(topic.title)
        let aliasTerms = searchableTerms(topic.aliases.joined(separator: " "))
        let keywordTerms = searchableTerms(topic.keywords.joined(separator: " "))
        let summaryTerms = searchableTerms(topic.summary)
        let detailTerms = searchableTerms(topic.details.joined(separator: " "))

        for term in queryTerms {
            if titleTerms.contains(term) { result += 20 }
            if aliasTerms.contains(term) { result += 14 }
            if keywordTerms.contains(term) { result += 10 }
            if summaryTerms.contains(term) { result += 5 }
            if detailTerms.contains(term) { result += 2 }
        }
        return result
    }

    private static func normalizedPhrase(_ value: String) -> String {
        searchableTerms(value).sorted().joined(separator: " ")
    }

    private static func searchableTerms(_ value: String) -> Set<String> {
        let stopWords: Set<String> = [
            "a", "an", "and", "are", "at", "be", "do", "does", "each", "for", "how", "i",
            "in", "is", "it", "mean", "means", "of", "on", "the", "to", "what", "why",
        ]
        let folded = value.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        return Set(
            folded
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .map(canonicalTerm)
                .filter { !$0.isEmpty && !stopWords.contains($0) }
        )
    }

    private static func canonicalTerm(_ value: String) -> String {
        guard value.count > 3, value.hasSuffix("s"), !value.hasSuffix("ss") else {
            return value
        }
        return String(value.dropLast())
    }
}
