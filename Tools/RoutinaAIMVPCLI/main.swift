import Foundation
import RoutinaAppSupport

private struct CLIOptions {
    var query = RoutinaAITaskQuery()
    var prettyPrinted = true
    var storeFileName: String?
    var sandboxMode: Bool?
}

private enum CLIError: LocalizedError {
    case invalidArgument(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case let .invalidArgument(message), let .failed(message):
            return message
        }
    }
}

@main
enum RoutinaAIMVPCLI {
    static func main() async {
        do {
            let options = try parseArguments(Array(CommandLine.arguments.dropFirst()))
            if let sandboxMode = options.sandboxMode {
                setenv("ROUTINA_SANDBOX", sandboxMode ? "1" : "0", 1)
            }
            if let storeFileName = options.storeFileName {
                setenv("ROUTINA_STORE_FILENAME", storeFileName, 1)
            }

            let snapshot = try await MainActor.run {
                let container = try PersistenceController.makeLocalOnlyContainer()
                return try RoutinaAIQueryService.snapshot(
                    in: container.mainContext,
                    query: options.query
                )
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = options.prettyPrinted
                ? [.prettyPrinted, .sortedKeys]
                : [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(snapshot)
            if let output = String(data: data, encoding: .utf8) {
                print(output)
            } else {
                throw CLIError.failed("Failed to encode snapshot as UTF-8.")
            }
        } catch let error as CLIError {
            writeToStandardError("error: \(error.localizedDescription)\n\n\(usageText)")
            Foundation.exit(EXIT_FAILURE)
        } catch {
            writeToStandardError("error: \(error.localizedDescription)\n")
            Foundation.exit(EXIT_FAILURE)
        }
    }
}

private let usageText = """
Usage:
  swift run RoutinaAIMVPCLI [options]

Options:
  --search <text>          Filter tasks by title, notes, tags, place, or status text.
  --limit <count>          Limit the number of returned tasks.
  --exclude-archived       Hide paused and snoozed tasks from the result.
  --exclude-completed      Hide completed and canceled one-off tasks from the result.
  --compact                Emit compact JSON.
  --store-file <name>      Override the SQLite file name before opening the store.
  --sandbox                Force sandbox data mode.
  --production             Force production data mode.
  --help                   Show this help text.

Examples:
  swift run RoutinaAIMVPCLI --search workout --limit 5
  swift run RoutinaAIMVPCLI --exclude-completed --exclude-archived
"""

private func parseArguments(_ arguments: [String]) throws -> CLIOptions {
    var options = CLIOptions()
    var index = 0

    while index < arguments.count {
        switch arguments[index] {
        case "--search":
            index += 1
            guard index < arguments.count else {
                throw CLIError.invalidArgument("Missing value for --search.")
            }
            options.query.searchText = arguments[index]

        case "--limit":
            index += 1
            guard index < arguments.count else {
                throw CLIError.invalidArgument("Missing value for --limit.")
            }
            guard let limit = Int(arguments[index]), limit >= 0 else {
                throw CLIError.invalidArgument("Limit must be a non-negative integer.")
            }
            options.query.limit = limit

        case "--exclude-archived":
            options.query.includeArchived = false

        case "--exclude-completed":
            options.query.includeCompleted = false

        case "--compact":
            options.prettyPrinted = false

        case "--store-file":
            index += 1
            guard index < arguments.count else {
                throw CLIError.invalidArgument("Missing value for --store-file.")
            }
            options.storeFileName = arguments[index]

        case "--sandbox":
            options.sandboxMode = true

        case "--production":
            options.sandboxMode = false

        case "--help":
            print(usageText)
            Foundation.exit(EXIT_SUCCESS)

        default:
            throw CLIError.invalidArgument("Unknown argument: \(arguments[index])")
        }

        index += 1
    }

    return options
}

private func writeToStandardError(_ text: String) {
    guard let data = text.data(using: .utf8) else { return }
    FileHandle.standardError.write(data)
}
