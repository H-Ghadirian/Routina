import Foundation
import Testing

struct HomeIOSRowNumberVisibilityTests {
    @Test
    func singleTaskSectionPassesNoRowNumberToItsRow() throws {
        let taskList = try sourceFile("iOS/Screens/Home/HomeIOSTaskListView.swift")
        let row = try sourceFile("iOS/Screens/Home/HomeIOSRoutineRowView.swift")

        #expect(taskList.contains("section.tasks.count == 1\n                                            ? nil"))
        #expect(row.contains("let rowNumber: Int?"))
        #expect(row.contains("if let rowNumber, rowVisibility.shows(.rowNumber)"))
    }

    private func sourceFile(_ relativePath: String) throws -> String {
        try SourceInspectionSupport.readProjectFile(relativePath)
    }
}
