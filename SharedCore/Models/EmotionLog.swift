import Foundation
import SwiftData

enum EmotionFamily: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case joy
    case calm
    case sadness
    case anger
    case fear
    case shameGuilt
    case disgust
    case surpriseCuriosity

    var id: Self { self }

    var title: String {
        switch self {
        case .joy: return "Joy"
        case .calm: return "Calm"
        case .sadness: return "Sadness"
        case .anger: return "Anger"
        case .fear: return "Fear"
        case .shameGuilt: return "Shame/Guilt"
        case .disgust: return "Disgust"
        case .surpriseCuriosity: return "Surprise/Curiosity"
        }
    }

    var systemImage: String {
        switch self {
        case .joy: return "sun.max.fill"
        case .calm: return "leaf.fill"
        case .sadness: return "cloud.rain.fill"
        case .anger: return "flame.fill"
        case .fear: return "exclamationmark.triangle.fill"
        case .shameGuilt: return "person.crop.circle.badge.exclamationmark"
        case .disgust: return "hand.raised.fill"
        case .surpriseCuriosity: return "sparkle.magnifyingglass"
        }
    }

    var defaultLabel: String {
        labels.first ?? title
    }

    var labels: [String] {
        switch self {
        case .joy:
            return ["happy", "excited", "proud", "grateful", "hopeful", "playful", "inspired"]
        case .calm:
            return ["calm", "content", "relaxed", "safe", "relieved", "grounded", "tender"]
        case .sadness:
            return ["sad", "lonely", "disappointed", "grief", "empty", "hopeless", "discouraged"]
        case .anger:
            return ["irritated", "frustrated", "angry", "resentful", "offended", "furious", "impatient"]
        case .fear:
            return ["anxious", "worried", "overwhelmed", "unsafe", "panicked", "nervous", "uncertain"]
        case .shameGuilt:
            return ["embarrassed", "ashamed", "guilty", "regretful", "exposed", "self-conscious"]
        case .disgust:
            return ["disgusted", "repelled", "uncomfortable", "judgmental", "averse"]
        case .surpriseCuriosity:
            return ["curious", "amazed", "confused", "startled", "intrigued", "astonished"]
        }
    }

    static func suggestedFamilies(valence: Double, arousal: Double) -> [EmotionFamily] {
        switch (valence >= 0, arousal >= 0) {
        case (true, true):
            return [.joy, .surpriseCuriosity]
        case (true, false):
            return [.calm]
        case (false, true):
            return [.fear, .anger, .disgust, .shameGuilt]
        case (false, false):
            return [.sadness, .shameGuilt]
        }
    }
}

enum EmotionBodyArea: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case head
    case face
    case throat
    case chest
    case stomach
    case shoulders
    case hands
    case wholeBody
    case energy

    var id: Self { self }

    var title: String {
        switch self {
        case .head: return "Head"
        case .face: return "Face"
        case .throat: return "Throat"
        case .chest: return "Chest"
        case .stomach: return "Stomach"
        case .shoulders: return "Shoulders"
        case .hands: return "Hands"
        case .wholeBody: return "Whole body"
        case .energy: return "Energy"
        }
    }
}

enum EmotionBodyAreaStorage {
    static func serialize(_ areas: [EmotionBodyArea]) -> String {
        areas.map(\.rawValue).joined(separator: "\n")
    }

    static func deserialize(_ storage: String) -> [EmotionBodyArea] {
        storage
            .split(whereSeparator: \.isNewline)
            .compactMap { EmotionBodyArea(rawValue: String($0)) }
    }
}

@Model
final class EmotionLog {
    var id: UUID = UUID()
    var familyRawValue: String = EmotionFamily.calm.rawValue
    var familyRawValuesStorage: String = ""
    var label: String = EmotionFamily.calm.defaultLabel
    var labelsStorage: String = ""
    var valence: Double = 0
    var arousal: Double = 0
    var intensity: Int = 3
    var bodyAreasStorage: String = ""
    var reflection: String?
    var linkedNoteID: UUID?
    var linkedGoalID: UUID?
    var linkedTaskID: UUID?
    var linkedPlaceID: UUID?
    var linkedSleepSessionID: UUID?
    var createdAt: Date?
    var updatedAt: Date?

    var family: EmotionFamily {
        get { families.first ?? primaryFamily }
        set {
            families = [newValue]
            if !newValue.labels.contains(primaryDisplayLabel) {
                labels = [newValue.defaultLabel]
            }
        }
    }

    var families: [EmotionFamily] {
        get {
            let storedFamilies = Self.deserializeFamilies(familyRawValuesStorage)
            return storedFamilies.isEmpty ? [primaryFamily] : storedFamilies
        }
        set {
            let resolvedFamilies = Self.normalizedFamilies(newValue)
            familyRawValuesStorage = Self.serializeFamilies(resolvedFamilies)
            familyRawValue = resolvedFamilies.first?.rawValue ?? EmotionFamily.calm.rawValue
        }
    }

    var labels: [String] {
        get {
            let storedLabels = Self.deserializeLabels(labelsStorage)
            if !storedLabels.isEmpty {
                return storedLabels
            }

            return [Self.cleanedText(label) ?? family.defaultLabel]
        }
        set {
            let resolvedLabels = Self.normalizedLabels(
                newValue,
                fallback: families.first?.defaultLabel ?? EmotionFamily.calm.defaultLabel
            )
            labelsStorage = Self.serializeLabels(resolvedLabels)
            label = resolvedLabels.first ?? families.first?.defaultLabel ?? EmotionFamily.calm.defaultLabel
        }
    }

    var bodyAreas: [EmotionBodyArea] {
        get { EmotionBodyAreaStorage.deserialize(bodyAreasStorage) }
        set { bodyAreasStorage = EmotionBodyAreaStorage.serialize(newValue) }
    }

    var primaryDisplayLabel: String {
        displayLabels.first ?? family.defaultLabel
    }

    var displayLabels: [String] {
        let resolvedLabels = Self.normalizedLabels(labels, fallback: family.defaultLabel)
        return resolvedLabels.isEmpty ? [family.defaultLabel] : resolvedLabels
    }

    var displayLabel: String {
        displayLabels.joined(separator: ", ")
    }

    var familiesDisplayTitle: String {
        families.map(\.title).joined(separator: ", ")
    }

    var displayTitle: String {
        "\(familiesDisplayTitle): \(displayLabel)"
    }

    var clampedIntensity: Int {
        min(max(intensity, 1), 5)
    }

    var hasContextLinks: Bool {
        linkedNoteID != nil
            || linkedGoalID != nil
            || linkedTaskID != nil
            || linkedPlaceID != nil
            || linkedSleepSessionID != nil
    }

    init(
        id: UUID = UUID(),
        family: EmotionFamily,
        label: String,
        valence: Double,
        arousal: Double,
        intensity: Int,
        bodyAreas: [EmotionBodyArea] = [],
        reflection: String? = nil,
        linkedNoteID: UUID? = nil,
        linkedGoalID: UUID? = nil,
        linkedTaskID: UUID? = nil,
        linkedPlaceID: UUID? = nil,
        linkedSleepSessionID: UUID? = nil,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date()
    ) {
        self.id = id
        applyEmotionSelection(families: [family], labels: [label])
        self.valence = Self.clampedAffectValue(valence)
        self.arousal = Self.clampedAffectValue(arousal)
        self.intensity = min(max(intensity, 1), 5)
        self.bodyAreasStorage = EmotionBodyAreaStorage.serialize(bodyAreas)
        self.reflection = Self.cleanedText(reflection)
        self.linkedNoteID = linkedNoteID
        self.linkedGoalID = linkedGoalID
        self.linkedTaskID = linkedTaskID
        self.linkedPlaceID = linkedPlaceID
        self.linkedSleepSessionID = linkedSleepSessionID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(
        id: UUID = UUID(),
        families: [EmotionFamily],
        labels: [String],
        valence: Double,
        arousal: Double,
        intensity: Int,
        bodyAreas: [EmotionBodyArea] = [],
        reflection: String? = nil,
        linkedNoteID: UUID? = nil,
        linkedGoalID: UUID? = nil,
        linkedTaskID: UUID? = nil,
        linkedPlaceID: UUID? = nil,
        linkedSleepSessionID: UUID? = nil,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date()
    ) {
        self.id = id
        applyEmotionSelection(families: families, labels: labels)
        self.valence = Self.clampedAffectValue(valence)
        self.arousal = Self.clampedAffectValue(arousal)
        self.intensity = min(max(intensity, 1), 5)
        self.bodyAreasStorage = EmotionBodyAreaStorage.serialize(bodyAreas)
        self.reflection = Self.cleanedText(reflection)
        self.linkedNoteID = linkedNoteID
        self.linkedGoalID = linkedGoalID
        self.linkedTaskID = linkedTaskID
        self.linkedPlaceID = linkedPlaceID
        self.linkedSleepSessionID = linkedSleepSessionID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func detachedCopy() -> EmotionLog {
        EmotionLog(
            id: id,
            families: families,
            labels: labels,
            valence: valence,
            arousal: arousal,
            intensity: intensity,
            bodyAreas: bodyAreas,
            reflection: reflection,
            linkedNoteID: linkedNoteID,
            linkedGoalID: linkedGoalID,
            linkedTaskID: linkedTaskID,
            linkedPlaceID: linkedPlaceID,
            linkedSleepSessionID: linkedSleepSessionID,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    static func cleanedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func clampedAffectValue(_ value: Double) -> Double {
        min(max(value, -1), 1)
    }

    static func serializeFamilies(_ families: [EmotionFamily]) -> String {
        normalizedFamilies(families).map(\.rawValue).joined(separator: "\n")
    }

    static func deserializeFamilies(_ storage: String) -> [EmotionFamily] {
        storage
            .split(whereSeparator: \.isNewline)
            .compactMap { EmotionFamily(rawValue: String($0)) }
            .reduce(into: [EmotionFamily]()) { result, family in
                guard !result.contains(family) else { return }
                result.append(family)
            }
    }

    static func serializeLabels(_ labels: [String]) -> String {
        normalizedLabels(labels, fallback: nil).joined(separator: "\n")
    }

    static func deserializeLabels(_ storage: String) -> [String] {
        normalizedLabels(
            storage.split(whereSeparator: \.isNewline).map(String.init),
            fallback: nil
        )
    }

    private var primaryFamily: EmotionFamily {
        EmotionFamily(rawValue: familyRawValue) ?? .calm
    }

    private func applyEmotionSelection(families: [EmotionFamily], labels: [String]) {
        let resolvedFamilies = Self.normalizedFamilies(families)
        let fallbackLabel = resolvedFamilies.first?.defaultLabel ?? EmotionFamily.calm.defaultLabel
        let resolvedLabels = Self.normalizedLabels(labels, fallback: fallbackLabel)

        familyRawValue = resolvedFamilies.first?.rawValue ?? EmotionFamily.calm.rawValue
        familyRawValuesStorage = Self.serializeFamilies(resolvedFamilies)
        label = resolvedLabels.first ?? fallbackLabel
        labelsStorage = Self.serializeLabels(resolvedLabels)
    }

    private static func normalizedFamilies(_ families: [EmotionFamily]) -> [EmotionFamily] {
        let uniqueFamilies = families.reduce(into: [EmotionFamily]()) { result, family in
            guard !result.contains(family) else { return }
            result.append(family)
        }
        return uniqueFamilies.isEmpty ? [.calm] : uniqueFamilies
    }

    private static func normalizedLabels(_ labels: [String], fallback: String?) -> [String] {
        let uniqueLabels = labels.reduce(into: [String]()) { result, label in
            guard let cleanedLabel = cleanedText(label),
                  !result.contains(cleanedLabel)
            else { return }
            result.append(cleanedLabel)
        }

        if !uniqueLabels.isEmpty {
            return uniqueLabels
        }

        guard let fallback = cleanedText(fallback) else { return [] }
        return [fallback]
    }
}

extension EmotionLog: Equatable {
    static func == (lhs: EmotionLog, rhs: EmotionLog) -> Bool {
        lhs.id == rhs.id
    }
}
