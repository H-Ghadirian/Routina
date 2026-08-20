import Foundation
import Testing
@testable @preconcurrency import RoutinaAppSupport

struct TaskDestinationTests {
    @Test
    func mapProviderURLsKeepAddressAndCoordinates() throws {
        let coordinate = LocationCoordinate(latitude: 52.5200, longitude: 13.4050)

        let appleURL = try #require(
            TaskDestinationMapProvider.appleMaps.url(
                address: "Alexanderplatz 1, Berlin",
                coordinate: coordinate
            )
        )
        let appleComponents = try #require(URLComponents(url: appleURL, resolvingAgainstBaseURL: false))
        let appleQuery = Dictionary(
            uniqueKeysWithValues: (appleComponents.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )
        #expect(appleQuery["q"] == "Alexanderplatz 1, Berlin")
        #expect(appleQuery["ll"] == "52.52,13.405")

        let googleURL = try #require(
            TaskDestinationMapProvider.googleMaps.url(
                address: "Alexanderplatz 1, Berlin",
                coordinate: coordinate
            )
        )
        let googleComponents = try #require(URLComponents(url: googleURL, resolvingAgainstBaseURL: false))
        let googleQuery = Dictionary(
            uniqueKeysWithValues: (googleComponents.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )
        #expect(googleQuery["api"] == "1")
        #expect(googleQuery["query"] == "Alexanderplatz 1, Berlin")
    }

    @Test
    func taskDestinationSanitizesAddressAndCoordinatesAndCopiesThem() {
        let task = RoutineTask(
            name: "Physiotherapist",
            destinationAddress: "  Alexanderplatz 1, Berlin  ",
            destinationLatitude: 52.5200,
            destinationLongitude: 13.4050,
            scheduleMode: .oneOff
        )

        #expect(task.destinationAddress == "Alexanderplatz 1, Berlin")
        #expect(task.destinationCoordinate == LocationCoordinate(latitude: 52.5200, longitude: 13.4050))

        let copy = task.detachedCopy()
        #expect(copy.destinationAddress == task.destinationAddress)
        #expect(copy.destinationCoordinate == task.destinationCoordinate)
    }
}
