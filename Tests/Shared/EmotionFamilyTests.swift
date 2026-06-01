import Foundation
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
    func emotionLogStoresMultipleFamiliesAndSpecificFeelings() {
        let log = EmotionLog(
            families: [.fear, .anger, .fear],
            labels: ["anxious", "frustrated", "anxious", " "],
            valence: -0.7,
            arousal: 0.8,
            intensity: 6
        )

        #expect(log.families == [.fear, .anger])
        #expect(log.labels == ["anxious", "frustrated"])
        #expect(log.family == .fear)
        #expect(log.label == "anxious")
        #expect(log.displayLabel == "anxious, frustrated")
        #expect(log.familiesDisplayTitle == "Fear, Anger")
        #expect(log.clampedIntensity == 5)
    }

    @Test
    func emotionLogTreatsLegacySingleSelectionAsOneItemLists() {
        let log = EmotionLog(
            family: .calm,
            label: "relaxed",
            valence: 0.6,
            arousal: -0.4,
            intensity: 2
        )

        #expect(log.families == [.calm])
        #expect(log.labels == ["relaxed"])
        #expect(log.displayLabel == "relaxed")
        #expect(log.familiesDisplayTitle == "Calm")
    }

    @Test
    func emotionLogUpdateEditsExistingSelectionAndTimestamp() {
        let createdAt = Date(timeIntervalSince1970: 100)
        let updatedAt = Date(timeIntervalSince1970: 200)
        let log = EmotionLog(
            family: .calm,
            label: "relaxed",
            valence: 0.6,
            arousal: -0.5,
            intensity: 2,
            createdAt: createdAt,
            updatedAt: createdAt
        )

        log.update(
            families: [.fear, .anger],
            labels: ["worried", "frustrated"],
            valence: -0.8,
            arousal: 0.7,
            intensity: 5,
            bodyAreas: [.chest],
            reflection: "After the call",
            linkedNoteID: UUID(),
            linkedGoalID: nil,
            linkedTaskID: nil,
            linkedPlaceID: nil,
            linkedSleepSessionID: nil,
            updatedAt: updatedAt
        )

        #expect(log.createdAt == createdAt)
        #expect(log.updatedAt == updatedAt)
        #expect(log.families == [.fear, .anger])
        #expect(log.labels == ["worried", "frustrated"])
        #expect(log.displayLabel == "worried, frustrated")
        #expect(log.valence == -0.8)
        #expect(log.arousal == 0.7)
        #expect(log.intensity == 5)
        #expect(log.bodyAreas == [.chest])
        #expect(log.reflection == "After the call")
        #expect(log.linkedNoteID != nil)
    }

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
    func fearLabels_includeDisorientationFeelings() {
        #expect(EmotionFamily.fear.labels.contains("confused"))
        #expect(EmotionFamily.fear.labels.contains("lost"))
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
