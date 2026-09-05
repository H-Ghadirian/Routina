import Foundation

extension RoutineTask {
    var hasNotes: Bool {
        RoutineTask.sanitizedNotes(notes) != nil
    }

    var hasTaskDescription: Bool {
        RoutineTask.sanitizedDescription(taskDescription) != nil
    }

    var hasImage: Bool {
        imageData?.isEmpty == false
    }

    var hasVoiceNote: Bool {
        voiceNoteData?.isEmpty == false
    }

    var destinationCoordinate: LocationCoordinate? {
        get {
            Self.sanitizedDestinationCoordinate(
                latitude: destinationLatitude,
                longitude: destinationLongitude
            )
        }
        set {
            destinationLatitude = newValue?.latitude
            destinationLongitude = newValue?.longitude
        }
    }

    var hasDestination: Bool {
        destinationAddress != nil || destinationCoordinate != nil
    }

    var voiceNote: RoutineVoiceNote? {
        get {
            RoutineVoiceNote(
                data: voiceNoteData,
                durationSeconds: voiceNoteDurationSeconds,
                createdAt: voiceNoteCreatedAt
            )
        }
        set {
            voiceNoteData = newValue?.data
            voiceNoteDurationSeconds = newValue?.durationSeconds
            voiceNoteCreatedAt = newValue?.createdAt
        }
    }

    var priority: RoutineTaskPriority {
        get { RoutineTaskPriority(rawValue: priorityRawValue) ?? .none }
        set { priorityRawValue = newValue.rawValue }
    }

    var importance: RoutineTaskImportance {
        get { RoutineTaskImportance(rawValue: importanceRawValue) ?? .level2 }
        set { importanceRawValue = newValue.rawValue }
    }

    var urgency: RoutineTaskUrgency {
        get { RoutineTaskUrgency(rawValue: urgencyRawValue) ?? .level2 }
        set { urgencyRawValue = newValue.rawValue }
    }

    var pressure: RoutineTaskPressure {
        get { RoutineTaskPressure(rawValue: pressureRawValue) ?? .none }
        set {
            pressureRawValue = newValue.rawValue
            pressureUpdatedAt = newValue == .none ? nil : Date()
        }
    }

    var thinkingNeeded: RoutineTaskThinkingNeeded {
        get { RoutineTaskThinkingNeeded(rawValue: thinkingNeededRawValue) ?? .none }
        set { thinkingNeededRawValue = newValue.rawValue }
    }

    var color: RoutineTaskColor {
        get { RoutineTaskColor(rawValue: colorRawValue) ?? .none }
        set { colorRawValue = newValue.rawValue }
    }

    var autoAssumeDoneTimeOfDay: RoutineTimeOfDay? {
        get {
            guard let hour = autoAssumeDoneTimeOfDayHour,
                let minute = autoAssumeDoneTimeOfDayMinute
            else { return nil }
            return RoutineTimeOfDay(hour: hour, minute: minute)
        }
        set {
            autoAssumeDoneTimeOfDayHour = newValue?.hour
            autoAssumeDoneTimeOfDayMinute = newValue?.minute
        }
    }

    var supportsTaskDetailHeatmap: Bool {
        switch scheduleMode.taskType {
        case .routine:
            return true
        case .todo:
            return false
        }
    }

    var importanceUrgencyLabel: String {
        "\(importance.title) • \(urgency.title)"
    }

    var derivedPriorityFromMatrix: RoutineTaskPriority {
        let score = importance.sortOrder + urgency.sortOrder
        switch score {
        case ..<4:
            return .low
        case 4:
            return .medium
        case 5...6:
            return .high
        default:
            return .urgent
        }
    }

    var tags: [String] {
        get { RoutineTag.deserialize(tagsStorage) }
        set { tagsStorage = RoutineTag.serialize(newValue) }
    }

    var flags: [String] {
        get { RoutineFlag.deserialize(flagsStorage) }
        set { flagsStorage = RoutineFlag.serialize(newValue) }
    }

    var links: [String] {
        get {
            linkItems.map(\.url)
        }
        set {
            let sanitizedLinks = Self.sanitizedLinks(newValue)
            linksStorage = RoutineTaskLinkStorage.serialize(sanitizedLinks)
            link = sanitizedLinks.first
        }
    }

    var linkItems: [RoutineTaskLink] {
        get {
            let storedLinks = RoutineTaskLinkStorage.deserializeItems(linksStorage)
            if !storedLinks.isEmpty {
                return storedLinks
            }
            return Self.sanitizedLink(link).map { [RoutineTaskLink(title: nil, url: $0)] } ?? []
        }
        set {
            let sanitizedLinks = RoutineTaskLinkStorage.sanitizedItems(newValue)
            linksStorage = RoutineTaskLinkStorage.serializeItems(sanitizedLinks)
            link = sanitizedLinks.first?.url
        }
    }
}
