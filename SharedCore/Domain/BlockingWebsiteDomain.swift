import Foundation

struct BlockingWebsiteDomain: Codable, Equatable, Hashable, Identifiable, Sendable {
    var domain: String
    var enabledModes: Set<ProtectionBlockingMode>

    var id: String { domain }

    init(
        domain: String,
        enabledModes: Set<ProtectionBlockingMode> = ProtectionBlockingMode.defaultEnabledModes
    ) {
        self.domain = domain
        self.enabledModes = enabledModes
    }

    private enum CodingKeys: String, CodingKey {
        case domain
        case enabledModes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        domain = try container.decode(String.self, forKey: .domain)
        let decodedModes = try container.decodeIfPresent([ProtectionBlockingMode].self, forKey: .enabledModes)
        enabledModes = decodedModes.map(Set.init) ?? ProtectionBlockingMode.defaultEnabledModes
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(domain, forKey: .domain)
        try container.encode(
            ProtectionBlockingMode.allCases.filter { enabledModes.contains($0) },
            forKey: .enabledModes
        )
    }

    static func normalizedDomain(from input: String) -> String? {
        normalizedHost(from: input)
    }

    static func normalizedHost(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        let host = URLComponents(string: candidate)?.host
            ?? URLComponents(string: "https://\(trimmed)")?.host
            ?? trimmed
                .split(whereSeparator: { "/?#".contains($0) })
                .first
                .map(String.init)

        guard var domain = host?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased(),
            !domain.isEmpty
        else {
            return nil
        }

        if domain.hasPrefix("*.") {
            domain.removeFirst(2)
        }

        let invalidCharacters = CharacterSet.whitespacesAndNewlines.union(
            CharacterSet(charactersIn: "/?#")
        )
        guard domain.rangeOfCharacter(from: invalidCharacters) == nil else {
            return nil
        }

        return domain
    }
}
