enum HomeFeatureLoadFailureSupport {
    static let message = "Failed to load tasks."

    static func logFailure(using logger: (String) -> Void = { print($0) }) {
        logger(message)
    }
}
