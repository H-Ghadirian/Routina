import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct RoutinaPublicLinksTests {
    @Test
    func publicLinksUsePublishedRoutinaPageAnchors() {
        #expect(RoutinaPublicLinks.support.absoluteString == "https://h-ghadirian.github.io/")
        #expect(RoutinaPublicLinks.privacyPolicy.absoluteString == "https://h-ghadirian.github.io/#privacy")
        #expect(RoutinaPublicLinks.termsOfUse.absoluteString == "https://h-ghadirian.github.io/#terms")
    }
}
