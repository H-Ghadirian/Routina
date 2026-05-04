import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct HomeFeatureLoadFailureSupportTests {
    @Test
    func logFailureUsesSharedMessage() {
        var messages: [String] = []

        HomeFeatureLoadFailureSupport.logFailure { message in
            messages.append(message)
        }

        #expect(messages == [HomeFeatureLoadFailureSupport.message])
    }
}
