import Foundation

struct GoalCreationDraftSnapshot: Codable, Equatable {
    var draft: GoalsFeature.GoalDraft

    init(draft: GoalsFeature.GoalDraft = GoalsFeature.GoalDraft()) {
        self.draft = draft
    }

    var isMeaningful: Bool {
        draft.id == nil
            && (RoutineGoal.cleanedTitle(draft.title) != nil
                || RoutineGoal.cleanedEmoji(draft.emoji) != nil
                || RoutineGoal.cleanedNotes(draft.notes) != nil
                || draft.targetDate != nil
                || !draft.tags.isEmpty
                || !draft.tagDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || draft.color != .none
                || draft.parentGoalID != nil)
    }

    func persist(client: CreationDraftClient) {
        guard isMeaningful else {
            CreationDraftPersistence.clear(.goal, client: client)
            return
        }

        CreationDraftPersistence.save(self, for: .goal, client: client)
    }

    static func load(client: CreationDraftClient) -> GoalCreationDraftSnapshot? {
        CreationDraftPersistence.load(Self.self, for: .goal, client: client)
    }
}

struct RoutineNoteDraftSnapshot: Codable, Equatable {
    var title = ""
    var bodyText = ""
    var tags: [String] = []
    var tagDraft = ""
    var imageData: Data?
    var voiceNote: RoutineVoiceNote?
    var attachments: [AttachmentItem] = []

    var isMeaningful: Bool {
        RoutineNote.cleanedText(title) != nil
            || RoutineNote.cleanedText(bodyText) != nil
            || !tags.isEmpty
            || !tagDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || imageData?.isEmpty == false
            || voiceNote != nil
            || !attachments.isEmpty
    }

    func persist() {
        guard isMeaningful else {
            CreationDraftPersistence.clear(.note)
            return
        }

        CreationDraftPersistence.save(self, for: .note)
    }

    static func load() -> Self? {
        CreationDraftPersistence.load(Self.self, for: .note)
    }
}

struct EmotionLogDraftSnapshot: Codable, Equatable {
    var valence = 0.25
    var arousal = -0.15
    var selectedFamilies: [EmotionFamily] = [.calm]
    var selectedLabels: [String] = [EmotionFamily.calm.defaultLabel]
    var intensity = 3.0
    var selectedBodyAreas: [EmotionBodyArea] = []
    var reflection = ""
    var linkedNoteID: UUID?
    var linkedGoalID: UUID?
    var linkedTaskID: UUID?
    var linkedPlaceID: UUID?
    var linkedSleepSessionID: UUID?

    var isMeaningful: Bool {
        valence != 0.25
            || arousal != -0.15
            || selectedFamilies != [.calm]
            || selectedLabels != [EmotionFamily.calm.defaultLabel]
            || intensity != 3.0
            || !selectedBodyAreas.isEmpty
            || EmotionLog.cleanedText(reflection) != nil
            || linkedNoteID != nil
            || linkedGoalID != nil
            || linkedTaskID != nil
            || linkedPlaceID != nil
            || linkedSleepSessionID != nil
    }

    func persist() {
        guard isMeaningful else {
            CreationDraftPersistence.clear(.emotion)
            return
        }

        CreationDraftPersistence.save(self, for: .emotion)
    }

    static func load() -> Self? {
        CreationDraftPersistence.load(Self.self, for: .emotion)
    }
}

struct RoutineEventDraftSnapshot: Codable, Equatable {
    var title = ""
    var notesText = ""
    var emoji = ""
    var isAllDay = true
    var startDate = Date()
    var endDate = Date().addingTimeInterval(60 * 60)
    var reminderAt: Date?
    var tags: [String] = []
    var tagDraft = ""

    func isMeaningful(comparedTo baseline: RoutineEventDraftSnapshot) -> Bool {
        RoutineEvent.cleanedText(title) != nil
            || RoutineEvent.cleanedText(notesText) != nil
            || RoutineEvent.cleanedText(emoji) != nil
            || isAllDay != baseline.isAllDay
            || startDate != baseline.startDate
            || endDate != baseline.endDate
            || reminderAt != baseline.reminderAt
            || !tags.isEmpty
            || !tagDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func persist(comparedTo baseline: RoutineEventDraftSnapshot) {
        guard isMeaningful(comparedTo: baseline) else {
            CreationDraftPersistence.clear(.event)
            return
        }

        CreationDraftPersistence.save(self, for: .event)
    }

    static func load() -> Self? {
        CreationDraftPersistence.load(Self.self, for: .event)
    }
}
