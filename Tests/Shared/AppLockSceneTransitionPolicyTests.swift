import Testing
@testable import RoutinaAppSupport

struct AppLockSceneTransitionPolicyTests {
    @Test
    func authenticationPromptSceneCycleIsConsumedWithoutStartingAnotherAuthentication() {
        var policy = AppLockSceneTransitionPolicy()

        let locksForPrompt = policy.shouldLockWhenSceneBecomesInactive(isAuthenticating: true)
        let authenticatesAfterPrompt = policy.shouldAuthenticateWhenSceneBecomesActive()
        #expect(locksForPrompt == false)
        #expect(authenticatesAfterPrompt == false)

        let locksForLaterDeparture = policy.shouldLockWhenSceneBecomesInactive(isAuthenticating: false)
        let authenticatesAfterLaterDeparture = policy.shouldAuthenticateWhenSceneBecomesActive()
        #expect(locksForLaterDeparture)
        #expect(authenticatesAfterLaterDeparture)
    }

    @Test
    func eachGateConsumesItsOwnAuthenticationPromptSceneCycle() {
        var policy = AppLockSceneTransitionPolicy()

        let firstGateLocks = policy.shouldLockWhenSceneBecomesInactive(isAuthenticating: true)
        let secondGateLocks = policy.shouldLockWhenSceneBecomesInactive(isAuthenticating: true)
        let firstGateAuthenticates = policy.shouldAuthenticateWhenSceneBecomesActive()
        let secondGateAuthenticates = policy.shouldAuthenticateWhenSceneBecomesActive()
        let laterActivationAuthenticates = policy.shouldAuthenticateWhenSceneBecomesActive()

        #expect(firstGateLocks == false)
        #expect(secondGateLocks == false)
        #expect(firstGateAuthenticates == false)
        #expect(secondGateAuthenticates == false)
        #expect(laterActivationAuthenticates)
    }

    @Test
    func ordinarySceneCycleStillLocksAndAuthenticates() {
        var policy = AppLockSceneTransitionPolicy()

        let shouldLock = policy.shouldLockWhenSceneBecomesInactive(isAuthenticating: false)
        let shouldAuthenticate = policy.shouldAuthenticateWhenSceneBecomesActive()

        #expect(shouldLock)
        #expect(shouldAuthenticate)
    }

    @Test
    func enteringBackgroundDuringAuthenticationRequiresAuthenticationOnReturn() {
        var policy = AppLockSceneTransitionPolicy()

        let locksForPrompt = policy.shouldLockWhenSceneBecomesInactive(isAuthenticating: true)
        policy.sceneEnteredBackground()
        let authenticatesAfterBackground = policy.shouldAuthenticateWhenSceneBecomesActive()

        #expect(locksForPrompt == false)
        #expect(authenticatesAfterBackground)
    }
}
