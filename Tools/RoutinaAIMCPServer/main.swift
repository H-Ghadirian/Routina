import Foundation
import RoutinaHelpSupport
#if canImport(AppKit)
import AppKit
#endif

private let serverName = "routina-ai-mcp"
private let serverVersion = "0.3.0"
private let fallbackProtocolVersion = "2025-06-18"

private enum MCPErrorCode: Int {
    case parseError = -32700
    case invalidRequest = -32600
    case methodNotFound = -32601
    case invalidParams = -32602
    case internalError = -32603
}

private struct ServerOptions {
    var snapshotFileURL: URL?
    var applicationBundleIdentifier = "ir.hamedgh.Routinam"
    var sandboxMode = false
    var inMemory: Bool = false
}

private enum ServerError: LocalizedError {
    case invalidArgument(String)
    case invalidParams(String)
    case unknownTool(String)
    case taskNotFound(String)
    case helpTopicNotFound(String)
    case snapshotUnavailable(String)

    var errorDescription: String? {
        switch self {
        case let .invalidArgument(message),
             let .invalidParams(message),
             let .unknownTool(message),
             let .taskNotFound(message),
             let .helpTopicNotFound(message),
             let .snapshotUnavailable(message):
            return message
        }
    }
}

private final class MCPStdioServer {
    private let options: ServerOptions

    init(options: ServerOptions) {
        self.options = options
    }

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    func run() async throws {
        while let line = readLine(strippingNewline: true) {
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            await handleLine(line)
        }
    }

    private func handleLine(_ line: String) async {
        guard let data = line.data(using: .utf8) else {
            sendError(id: nil, code: .parseError, message: "Message is not valid UTF-8.")
            return
        }

        do {
            guard let message = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                sendError(id: nil, code: .invalidRequest, message: "JSON-RPC message must be an object.")
                return
            }
            try await handleMessage(message)
        } catch {
            sendError(id: nil, code: .parseError, message: "Failed to parse JSON-RPC message.")
        }
    }

    private func handleMessage(_ message: [String: Any]) async throws {
        guard message["jsonrpc"] as? String == "2.0",
              let method = message["method"] as? String else {
            sendError(id: message["id"], code: .invalidRequest, message: "Invalid JSON-RPC request.")
            return
        }

        guard let id = message["id"] else {
            if method == "notifications/initialized" || method == "notifications/cancelled" {
                return
            }
            return
        }

        switch method {
        case "initialize":
            sendResult(id: id, result: initializeResult(from: message))

        case "ping":
            sendResult(id: id, result: [:])

        case "tools/list":
            sendResult(id: id, result: ["tools": toolDefinitions()])

        case "tools/call":
            do {
                let result = try await callTool(from: message)
                sendResult(id: id, result: result)
            } catch let error as ServerError {
                sendError(id: id, code: .invalidParams, message: error.localizedDescription)
            } catch {
                sendError(id: id, code: .internalError, message: error.localizedDescription)
            }

        default:
            sendError(id: id, code: .methodNotFound, message: "Unknown method: \(method)")
        }
    }

    private func initializeResult(from message: [String: Any]) -> [String: Any] {
        let params = message["params"] as? [String: Any]
        let requestedVersion = params?["protocolVersion"] as? String

        return [
            "protocolVersion": requestedVersion ?? fallbackProtocolVersion,
            "capabilities": [
                "tools": [
                    "listChanged": false
                ]
            ],
            "serverInfo": [
                "name": serverName,
                "version": serverVersion
            ],
            "instructions": "Read-only Routina support. Use search_routina_help or get_routina_help_topic to explain "
                + "Routina features and interface concepts. Use search_tasks for questions about the user\u{2019}s tasks, "
                + "list_overdue_tasks for overdue routines and todos, and get_task when you already have a task UUID. "
                + "Help lookup does not require access to personal task data."
        ]
    }

    private func toolDefinitions() -> [[String: Any]] {
        [
            [
                "name": "search_tasks",
                "title": "Search Routina Tasks",
                "description": "Search Routina routines and todos. Results include status, schedule, due dates, tags, place, notes, and progress metadata.",
                "annotations": readOnlyToolAnnotations(),
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "searchText": [
                            "type": "string",
                            "description": "Optional words to match against task name, notes, tags, place, schedule, status, or next step."
                        ],
                        "includeArchived": [
                            "type": "boolean",
                            "description": "Include paused and snoozed tasks. Defaults to true."
                        ],
                        "includeCompleted": [
                            "type": "boolean",
                            "description": "Include completed and canceled one-off tasks. Defaults to true."
                        ],
                        "limit": [
                            "type": "integer",
                            "minimum": 0,
                            "description": "Maximum number of tasks to return."
                        ]
                    ],
                    "additionalProperties": false
                ]
            ],
            [
                "name": "list_overdue_tasks",
                "title": "List Overdue Routina Tasks",
                "description": "Return routines and todos that are currently overdue, sorted by urgency and due date.",
                "annotations": readOnlyToolAnnotations(),
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "limit": [
                            "type": "integer",
                            "minimum": 0,
                            "description": "Maximum number of overdue tasks to return."
                        ]
                    ],
                    "additionalProperties": false
                ]
            ],
            [
                "name": "get_task",
                "title": "Get Routina Task",
                "description": "Return one Routina task by UUID.",
                "annotations": readOnlyToolAnnotations(),
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "id": [
                            "type": "string",
                            "description": "The Routina task UUID."
                        ]
                    ],
                    "required": ["id"],
                    "additionalProperties": false
                ]
            ],
            [
                "name": "search_routina_help",
                "title": "Search Routina Help",
                "description": "Search Routina\u{2019}s privacy-safe product guide for explanations of features, labels, controls, and interface concepts. This does not access personal task data.",
                "annotations": readOnlyToolAnnotations(),
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "query": [
                            "type": "string",
                            "description": "A question or phrase about Routina, such as \u{2018}What is Task Ladder?\u{2019} or \u{2018}numbers above Calendar day columns\u{2019}."
                        ],
                        "limit": [
                            "type": "integer",
                            "minimum": 1,
                            "maximum": 10,
                            "description": "Maximum number of help topics to return. Defaults to 5."
                        ]
                    ],
                    "required": ["query"],
                    "additionalProperties": false
                ]
            ],
            [
                "name": "get_routina_help_topic",
                "title": "Get Routina Help Topic",
                "description": "Return one complete Routina help topic by the topic ID supplied by search_routina_help. This does not access personal task data.",
                "annotations": readOnlyToolAnnotations(),
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "topicId": [
                            "type": "string",
                            "description": "The stable help topic ID, such as task-ladder or planner-day-counts."
                        ]
                    ],
                    "required": ["topicId"],
                    "additionalProperties": false
                ]
            ]
        ]
    }

    private func callTool(from message: [String: Any]) async throws -> [String: Any] {
        guard let params = message["params"] as? [String: Any],
              let name = params["name"] as? String else {
            throw ServerError.invalidParams("tools/call requires params.name.")
        }

        let arguments = params["arguments"] as? [String: Any] ?? [:]
        switch name {
        case "search_tasks":
            return try await callSearchTasks(arguments: arguments)
        case "list_overdue_tasks":
            return try await callListOverdueTasks(arguments: arguments)
        case "get_task":
            return try await callGetTask(arguments: arguments)
        case "search_routina_help":
            return try callSearchRoutinaHelp(arguments: arguments)
        case "get_routina_help_topic":
            return try callGetRoutinaHelpTopic(arguments: arguments)
        default:
            throw ServerError.unknownTool("Unknown tool: \(name)")
        }
    }

    private func readOnlyToolAnnotations() -> [String: Any] {
        [
            "readOnlyHint": true,
            "destructiveHint": false,
            "idempotentHint": true,
            "openWorldHint": false
        ]
    }

    private func callSearchTasks(arguments: [String: Any]) async throws -> [String: Any] {
        let snapshot = try await loadTaskSnapshot(
            query: MCPTaskQuery(
                searchText: arguments["searchText"] as? String,
                includeArchived: arguments["includeArchived"] as? Bool ?? true,
                includeCompleted: arguments["includeCompleted"] as? Bool ?? true,
                limit: optionalNonNegativeInt(arguments["limit"], name: "limit")
            ),
            options: options
        )
        return try toolTextResult(snapshot)
    }

    private func callListOverdueTasks(arguments: [String: Any]) async throws -> [String: Any] {
        let limit = try optionalNonNegativeInt(arguments["limit"], name: "limit")
        let snapshot = try await loadTaskSnapshot(
            query: MCPTaskQuery(
                searchText: nil,
                includeArchived: false,
                includeCompleted: false,
                limit: nil
            ),
            options: options
        )
        var overdueTasks = snapshot.tasks.filter { $0.primaryStatus == .overdue }
        if let limit {
            overdueTasks = Array(overdueTasks.prefix(limit))
        }
        let payload: [String: Any] = [
            "generatedAt": isoString(snapshot.generatedAt),
            "count": overdueTasks.count,
            "tasks": try jsonObject(overdueTasks)
        ]
        return try toolTextResult(payload)
    }

    private func callGetTask(arguments: [String: Any]) async throws -> [String: Any] {
        guard let idString = arguments["id"] as? String,
              let taskID = UUID(uuidString: idString) else {
            throw ServerError.invalidParams("get_task requires a valid UUID string in id.")
        }

        let snapshot = try await loadTaskSnapshot(
            query: MCPTaskQuery(
                searchText: nil,
                includeArchived: true,
                includeCompleted: true,
                limit: nil
            ),
            options: options
        )
        guard let task = snapshot.tasks.first(where: { $0.id == taskID }) else {
            throw ServerError.taskNotFound("No Routina task exists with id \(idString).")
        }
        return try toolTextResult(task)
    }

    private func callSearchRoutinaHelp(arguments: [String: Any]) throws -> [String: Any] {
        guard let query = arguments["query"] as? String,
              !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServerError.invalidParams("search_routina_help requires a non-empty query.")
        }
        let limit = try optionalPositiveInt(
            arguments["limit"],
            name: "limit",
            maximum: 10
        ) ?? 5
        let topics = RoutinaHelpCatalog.search(query, limit: limit)
        return try toolTextResult([
            "count": topics.count,
            "topics": try jsonObject(topics)
        ])
    }

    private func callGetRoutinaHelpTopic(arguments: [String: Any]) throws -> [String: Any] {
        guard let topicID = arguments["topicId"] as? String,
              !topicID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServerError.invalidParams("get_routina_help_topic requires a topicId.")
        }
        guard let topic = RoutinaHelpCatalog.topic(id: topicID) else {
            throw ServerError.helpTopicNotFound("No Routina help topic exists with id \(topicID).")
        }
        return try toolTextResult(topic)
    }

    private func optionalNonNegativeInt(_ value: Any?, name: String) throws -> Int? {
        guard let value else { return nil }
        if let intValue = value as? Int {
            guard intValue >= 0 else {
                throw ServerError.invalidParams("\(name) must be a non-negative integer.")
            }
            return intValue
        }
        if let number = value as? NSNumber {
            let intValue = number.intValue
            guard intValue >= 0, Double(intValue) == number.doubleValue else {
                throw ServerError.invalidParams("\(name) must be a non-negative integer.")
            }
            return intValue
        }
        throw ServerError.invalidParams("\(name) must be a non-negative integer.")
    }

    private func optionalPositiveInt(
        _ value: Any?,
        name: String,
        maximum: Int
    ) throws -> Int? {
        guard let value else { return nil }
        let intValue: Int
        if let value = value as? Int {
            intValue = value
        } else if let number = value as? NSNumber,
                  Double(number.intValue) == number.doubleValue {
            intValue = number.intValue
        } else {
            throw ServerError.invalidParams("\(name) must be an integer.")
        }
        guard (1...maximum).contains(intValue) else {
            throw ServerError.invalidParams("\(name) must be between 1 and \(maximum).")
        }
        return intValue
    }

    private func toolTextResult<T: Encodable>(_ value: T) throws -> [String: Any] {
        let text = try encodedJSONString(value)
        return [
            "content": [
                [
                    "type": "text",
                    "text": text
                ]
            ],
            "isError": false
        ]
    }

    private func toolTextResult(_ value: [String: Any]) throws -> [String: Any] {
        let data = try JSONSerialization.data(
            withJSONObject: value,
            options: [.prettyPrinted, .sortedKeys]
        )
        guard let text = String(data: data, encoding: .utf8) else {
            throw ServerError.invalidParams("Failed to encode tool result.")
        }
        return [
            "content": [
                [
                    "type": "text",
                    "text": text
                ]
            ],
            "isError": false
        ]
    }

    private func encodedJSONString<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        guard let text = String(data: data, encoding: .utf8) else {
            throw ServerError.invalidParams("Failed to encode tool result.")
        }
        return text
    }

    private func jsonObject<T: Encodable>(_ value: T) throws -> Any {
        let data = try encoder.encode(value)
        return try JSONSerialization.jsonObject(with: data)
    }

    private func sendResult(id: Any, result: [String: Any]) {
        send([
            "jsonrpc": "2.0",
            "id": id,
            "result": result
        ])
    }

    private func sendError(id: Any?, code: MCPErrorCode, message: String) {
        var response: [String: Any] = [
            "jsonrpc": "2.0",
            "error": [
                "code": code.rawValue,
                "message": message
            ]
        ]
        if let id {
            response["id"] = id
        }
        send(response)
    }

    private func send(_ object: [String: Any]) {
        do {
            let data = try JSONSerialization.data(
                withJSONObject: object,
                options: [.sortedKeys]
            )
            if let text = String(data: data, encoding: .utf8) {
                print(text)
                fflush(stdout)
            }
        } catch {
            writeLog("failed to send JSON-RPC response: \(error.localizedDescription)")
        }
    }
}

private func parseArguments(_ arguments: [String]) throws -> ServerOptions {
    var options = ServerOptions()
    var index = 0

    while index < arguments.count {
        switch arguments[index] {
        case "--snapshot-file":
            index += 1
            guard index < arguments.count else {
                throw ServerError.invalidArgument("Missing value for --snapshot-file.")
            }
            options.snapshotFileURL = URL(fileURLWithPath: arguments[index])

        case "--sandbox":
            options.applicationBundleIdentifier = "ir.hamedgh.Routinam.mac.dev"
            options.sandboxMode = true

        case "--production":
            options.applicationBundleIdentifier = "ir.hamedgh.Routinam"
            options.sandboxMode = false

        case "--in-memory":
            options.inMemory = true

        case "--help":
            print(usageText)
            Foundation.exit(EXIT_SUCCESS)

        default:
            throw ServerError.invalidArgument("Unknown argument: \(arguments[index])")
        }

        index += 1
    }

    return options
}

private func loadTaskSnapshot(
    query: MCPTaskQuery,
    options: ServerOptions
) async throws -> MCPTaskSnapshot {
    if options.inMemory {
        return MCPTaskQueryService.snapshot(
            from: [],
            query: query
        )
    }

    let fileURL = try options.snapshotFileURL ?? MCPReadOnlySnapshotStore.defaultFileURL(
        sandboxMode: options.sandboxMode
    )
    if !FileManager.default.fileExists(atPath: fileURL.path) {
        await launchRoutinaIfAvailable(bundleIdentifier: options.applicationBundleIdentifier)
        await waitForSnapshot(at: fileURL)
    }

    let catalog: MCPReadOnlyCatalog
    do {
        catalog = try MCPReadOnlySnapshotStore.load(from: fileURL)
    } catch {
        throw ServerError.snapshotUnavailable(
            "Routina's read-only AI data is unavailable. Open Routina, then enable Local AI Access in Settings > AI Connections. (\(error.localizedDescription))"
        )
    }

    return MCPTaskQueryService.snapshot(
        from: catalog.tasks,
        query: query,
        generatedAt: catalog.generatedAt
    )
}

private func waitForSnapshot(at fileURL: URL) async {
    for _ in 0..<30 {
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try? await Task.sleep(for: .milliseconds(100))
    }
}

private func launchRoutinaIfAvailable(bundleIdentifier: String) async {
    #if canImport(AppKit)
    guard let applicationURL = NSWorkspace.shared.urlForApplication(
        withBundleIdentifier: bundleIdentifier
    ) else { return }

    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    configuration.addsToRecentItems = false
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        NSWorkspace.shared.openApplication(
            at: applicationURL,
            configuration: configuration
        ) { _, _ in
            continuation.resume()
        }
    }
    #endif
}

private let usageText = """
Usage:
  RoutinaAIMCPServer [options]

Options:
  --snapshot-file <path>   Read a specific exported snapshot (primarily for tests).
  --sandbox                Use the Routina development app when a launch is needed.
  --production             Use the production Routina app (the default).
  --in-memory              Use an empty catalog for protocol smoke tests.
  --help                   Show this help text.
"""

private func isoString(_ date: Date) -> String {
    ISO8601DateFormatter().string(from: date)
}

private func writeLog(_ text: String) {
    FileHandle.standardError.write(Data((text + "\n").utf8))
}

do {
    let options = try parseArguments(Array(CommandLine.arguments.dropFirst()))
    try await MCPStdioServer(options: options).run()
} catch {
    writeLog("fatal: \(error.localizedDescription)")
    Foundation.exit(EXIT_FAILURE)
}
