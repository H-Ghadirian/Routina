import Darwin
import Foundation
import RoutinaAppSupport

@main
struct RoutinaBackupAuditCommand {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments == ["--help"] || arguments == ["-h"] {
            printUsage()
            return
        }

        guard arguments.count == 1 else {
            printUsage(to: .standardError)
            exit(EXIT_FAILURE)
        }

        let packageURL = URL(fileURLWithPath: arguments[0]).standardizedFileURL
        do {
            let report = try await MainActor.run {
                try RoutinaBackupAudit.audit(packageAt: packageURL)
            }
            printReport(report, packageURL: packageURL)
        } catch {
            write("Backup audit failed: \(error.localizedDescription)\n", to: .standardError)
            exit(EXIT_FAILURE)
        }
    }

    private static func printReport(
        _ report: RoutinaBackupAudit.Report,
        packageURL: URL
    ) {
        let byteFormatter = ByteCountFormatter()
        byteFormatter.countStyle = .file

        print("Backup audit passed")
        print("Package: \(packageURL.path)")
        print("Schema: \(report.sourceSchemaVersion) (current: \(report.currentSchemaVersion))")
        print("Records: \(report.totalRecordCount)")
        for key in report.recordCounts.keys.sorted() {
            guard let count = report.recordCounts[key], count > 0 else { continue }
            print("  \(key): \(count)")
        }
        print(
            "Attachments: \(report.attachmentCount) (\(byteFormatter.string(fromByteCount: Int64(report.attachmentBytes))))"
        )
        print("Semantic fingerprint: \(report.semanticFingerprint)")
        if report.comparedSourceDirectly {
            print("Verified: source package equals its isolated restore and a second round-trip")
        } else {
            print("Verified: legacy migration restores successfully and is stable across a second round-trip")
        }
        print("Isolation: no production, development, or CloudKit store was opened or changed")
    }

    private static func printUsage(to handle: FileHandle = .standardOutput) {
        write(
            """
            Usage: swift run -q RoutinaBackupAudit <backup.routinabackup>

            Validates a Routina backup package, restores it into isolated in-memory stores,
            and verifies semantic round-trip stability without touching app or CloudKit data.

            """,
            to: handle
        )
    }

    private static func write(_ message: String, to handle: FileHandle) {
        if let data = message.data(using: .utf8) {
            handle.write(data)
        }
    }
}
