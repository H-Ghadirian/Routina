import Foundation
import Testing

struct RoutinaLiquidGlassContrastTests {
    @Test
    func selectedSegmentsUseForegroundThatContrastsWithBrightGlass() throws {
        let source = try Self.sourceFile("SharedCore/Views/RoutinaLiquidGlass.swift")

        #expect(!source.contains("isSelected ? .primary : .secondary"))
        #expect(
            source.components(
                separatedBy: "isSelected ? .black.opacity(0.82) : .secondary"
            ).count - 1 == 2
        )
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        try SourceInspectionSupport.readProjectFile(relativePath)
    }
}
