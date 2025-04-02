import AmplitudeSwift

struct AmplitudeTracker {
    public static let shared = AmplitudeTracker()

    private let amplitude: Amplitude
    private init() {
        amplitude = Amplitude(configuration: Configuration(
            apiKey: "96cf79741b029587a3e561437c4d94a7"
        ))
    }

    public func logEvent(_ event: String) {
        amplitude.track(eventType: event)
    }
}

