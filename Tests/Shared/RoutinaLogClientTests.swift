import ConcurrencyExtras
import Dependencies
import Testing
@testable import RoutinaAppSupport

@Suite("Routina logging")
struct RoutinaLogClientTests {
    @Test("The facade uses the scoped logging dependency")
    func facadeUsesScopedDependency() {
        let errors = LockIsolated<[String]>([])
        let notices = LockIsolated<[String]>([])

        withDependencies {
            $0.routinaLogClient = RoutinaLogClient(
                error: { message in errors.withValue { $0.append(message) } },
                notice: { message in notices.withValue { $0.append(message) } }
            )
        } operation: {
            RoutinaLog.error("failure")
            RoutinaLog.notice("recovery")
        }

        #expect(errors.value == ["failure"])
        #expect(notices.value == ["recovery"])
    }
}
