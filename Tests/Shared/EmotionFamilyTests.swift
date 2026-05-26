import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct EmotionFamilyTests {
    @Test
    func suggestedFamilies_matchPleasantHighEnergyMood() {
        #expect(EmotionFamily.suggestedFamilies(valence: 0.65, arousal: 0.65) == [
            .joy,
            .surpriseCuriosity
        ])
    }

    @Test
    func suggestedFamilies_matchPleasantLowEnergyMood() {
        #expect(EmotionFamily.suggestedFamilies(valence: 0.65, arousal: -0.65) == [
            .calm
        ])
    }

    @Test
    func suggestedFamilies_matchUnpleasantHighEnergyMood() {
        #expect(EmotionFamily.suggestedFamilies(valence: -0.65, arousal: 0.65) == [
            .fear,
            .anger,
            .disgust,
            .shameGuilt
        ])
    }

    @Test
    func suggestedFamilies_matchUnpleasantLowEnergyMood() {
        let families = EmotionFamily.suggestedFamilies(valence: -0.65, arousal: -0.65)

        #expect(families == [
            .sadness,
            .shameGuilt
        ])
        #expect(!families.contains(.calm))
        #expect(!families.contains(.joy))
        #expect(!families.contains(.surpriseCuriosity))
    }
}
