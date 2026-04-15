import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct EmojiCatalogTests {
    @Test
    func filter_matchesCommonRoutineAliases() {
        let waterResults = EmojiCatalog.filter(EmojiCatalog.searchableAll, matching: "water")
        #expect(waterResults.contains(where: { $0.emoji == "💧" }))

        let readResults = EmojiCatalog.filter(EmojiCatalog.searchableAll, matching: "read")
        #expect(readResults.contains(where: { $0.emoji == "📚" }))
        #expect(readResults.contains(where: { $0.emoji == "🍞" }) == false)

        let sleepResults = EmojiCatalog.filter(EmojiCatalog.searchableAll, matching: "sleep")
        #expect(sleepResults.contains(where: { $0.emoji == "😴" }))

        let runResults = EmojiCatalog.filter(EmojiCatalog.searchableAll, matching: "run")
        #expect(runResults.contains(where: { $0.emoji == "🏃" || $0.emoji == "🏃‍♂️" }))
    }

    @Test
    func filter_supportsDirectEmojiInputAndEmptyQueries() {
        let directResults = EmojiCatalog.filter(EmojiCatalog.searchableAll, matching: "📚")
        #expect(directResults.map(\.emoji) == ["📚"])

        let allResults = EmojiCatalog.filter(EmojiCatalog.searchableAll, matching: "   ")
        #expect(allResults.count == EmojiCatalog.searchableAll.count)
    }

    @Test
    func filter_matchesUnicodeScalarNames() {
        let dropletResults = EmojiCatalog.filter(EmojiCatalog.searchableAll, matching: "droplet")
        #expect(dropletResults.map(\.emoji).contains("💧"))

        let lotusResults = EmojiCatalog.filter(EmojiCatalog.searchableAll, matching: "lotus")
        #expect(lotusResults.map(\.emoji).contains("🧘"))

        let checkMarkResults = EmojiCatalog.filter(EmojiCatalog.searchableAll, matching: "white heavy check mark")
        #expect(checkMarkResults.map(\.emoji).contains("✅"))
    }

    @Test
    func filter_isCaseAndDiacriticInsensitive() {
        let uppercaseResults = EmojiCatalog.filter(EmojiCatalog.searchableAll, matching: "WATER")
        #expect(uppercaseResults.map(\.emoji).contains("💧"))

        let accentResults = EmojiCatalog.filter(EmojiCatalog.searchableAll, matching: "cafe")
        #expect(accentResults.map(\.emoji).contains("☕️"))
    }

    @Test
    func filter_matchesPartialMultiWordQueries() {
        let partialPhraseResults = EmojiCatalog.filter(EmojiCatalog.searchableAll, matching: "check mar")
        #expect(partialPhraseResults.map(\.emoji).contains("✅"))

        let secondaryAliasResults = EmojiCatalog.filter(EmojiCatalog.searchableAll, matching: "mindful")
        #expect(secondaryAliasResults.map(\.emoji).contains("🧘"))
    }

    @Test
    func filter_returnsNoResultsWhenNothingMatches() {
        let results = EmojiCatalog.filter(EmojiCatalog.searchableAll, matching: "not-a-real-emoji-query")
        #expect(results.isEmpty)
    }

    @Test
    func searchableOptions_haveReadableAccessibilityLabels() {
        let droplet = EmojiCatalog.searchableAll.first(where: { $0.emoji == "💧" })
        #expect(droplet?.accessibilityLabel == "droplet")

        let runner = EmojiCatalog.searchableAll.first(where: { $0.emoji == "🏃‍♂️" })
        #expect(runner?.accessibilityLabel.contains("runner") == true)
        #expect(runner?.accessibilityLabel.contains("zero width joiner") == false)
    }
}
