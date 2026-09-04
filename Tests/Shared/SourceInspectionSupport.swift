import Foundation

/// Centralizes the few tests that intentionally guard source-level architecture
/// invariants which cannot be expressed as runtime behavior.
enum SourceInspectionSupport {
    static func readProjectFile(
        _ relativePath: String,
        callerFile: StaticString = #filePath
    ) throws -> String {
        return try String(
            contentsOf: projectRoot(for: callerFile).appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    static func readProjectSwiftFiles(
        in relativeDirectory: String,
        callerFile: StaticString = #filePath
    ) throws -> String {
        try FileManager.default
            .contentsOfDirectory(
                at: projectRoot(for: callerFile).appendingPathComponent(relativeDirectory, isDirectory: true),
                includingPropertiesForKeys: nil
            )
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.path < $1.path }
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")
    }

    static func readMacTaskDetailSources(
        callerFile: StaticString = #filePath
    ) throws -> String {
        try [
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailTCAView.swift",
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailTCAView+Overview.swift",
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailTCAView+OptionalDetails.swift",
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailTCAView+HeaderSections.swift",
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailTCAView+ContentSections.swift",
        ]
        .map { try readProjectFile($0, callerFile: callerFile) }
        .joined(separator: "\n")
    }

    static func readMacHomePlatformSources(
        callerFile: StaticString = #filePath
    ) throws -> String {
        try [
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAViewPlatform.swift",
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+MacToolbar.swift",
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+MacSearchRefresh.swift",
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+MacQuickAddPresentation.swift",
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+MacQuickAddCreation.swift",
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+MacFilters.swift",
        ]
        .map { try readProjectFile($0, callerFile: callerFile) }
        .joined(separator: "\n")
    }

    private static func projectRoot(for callerFile: StaticString) -> URL {
        URL(fileURLWithPath: "\(callerFile)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
