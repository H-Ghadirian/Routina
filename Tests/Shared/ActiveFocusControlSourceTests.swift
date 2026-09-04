import Foundation
import Testing

struct ActiveFocusControlSourceTests {
    @Test
    func iosHomeFocusBannerAlwaysOpensAFullSurfaceControlSheet() throws {
        let source = try Self.sourceFile("iOS/Screens/Home/HomeTCAViewPlatform.swift")
        let banner = try Self.sourceSection(
            startingAt: "private struct HomePinnedFocusTimerBanner: View",
            endingAt: "private struct HomePinnedFocusTimerStatus: Equatable",
            in: source
        )

        #expect(banner.contains("onOpen(status.presentation)"))
        #expect(banner.contains(".contentShape(RoundedRectangle"))
        #expect(banner.contains(".accessibilityHint(\"Shows Focus controls\")"))
        #expect(!banner.contains("if let deepLink"))
    }

    @Test
    func iosActiveFocusSheetOffersEveryTerminalAndInterruptionAction() throws {
        let source = try Self.sourceFile("iOS/Screens/Home/HomeTCAViewPlatform.swift")
        let sheet = try Self.sourceSection(
            startingAt: "struct ActiveFocusControlSheet: View",
            endingAt: "private struct ActiveFocusControlStatus",
            in: source
        )

        #expect(sheet.contains("FocusSessionSupport.pauseFocus("))
        #expect(sheet.contains("FocusSessionSupport.resumeFocus("))
        #expect(sheet.contains("FocusSessionSupport.finishFocus("))
        #expect(sheet.contains("FocusSessionSupport.abandonFocus("))
        #expect(sheet.contains("Label(\"Finish\""))
        #expect(sheet.contains("Label(\"Abandon\""))
        #expect(sheet.contains("Label(\"Open Task\""))
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        try SourceInspectionSupport.readProjectFile(relativePath)
    }

    private static func sourceSection(
        startingAt startMarker: String,
        endingAt endMarker: String,
        in source: String
    ) throws -> String {
        let start = try #require(source.range(of: startMarker))
        let end = try #require(
            source.range(
                of: endMarker,
                range: start.upperBound..<source.endIndex
            )
        )
        return String(source[start.lowerBound..<end.lowerBound])
    }
}
