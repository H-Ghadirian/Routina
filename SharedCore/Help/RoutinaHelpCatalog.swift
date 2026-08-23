import Foundation

public struct RoutinaHelpTopic: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let summary: String
    public let details: [String]
    public let aliases: [String]
    public let keywords: [String]
    public let platforms: [String]
    public let availability: String
    public let relatedTopicIDs: [String]
    public let exampleQuestions: [String]

    public init(
        id: String,
        title: String,
        summary: String,
        details: [String],
        aliases: [String],
        keywords: [String],
        platforms: [String],
        availability: String,
        relatedTopicIDs: [String] = [],
        exampleQuestions: [String] = []
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.details = details
        self.aliases = aliases
        self.keywords = keywords
        self.platforms = platforms
        self.availability = availability
        self.relatedTopicIDs = relatedTopicIDs
        self.exampleQuestions = exampleQuestions
    }
}

public enum RoutinaHelpCatalog {
    public static let starterQuestions = [
        "What is Task Ladder?",
        "What do the numbers above Calendar day columns mean?",
        "What is the difference between Availability, Plan to do, Schedule, Deadline, and Reminder?",
        "What does Assumed done mean?",
        "What is the difference between Flags and Tags?",
        "How do I enable changes over time?",
        "How does Backlog work?"
    ]

    public static let topics: [RoutinaHelpTopic] = [
        RoutinaHelpTopic(
            id: "task-ladder",
            title: "Task Ladder",
            summary: "Task Ladder is a full-size workspace in the main macOS window for comparing active tasks by one value at a time.",
            details: [
                "Choose Task Ladder from the main window’s workspace menu or press Shift-Command-R. It can compare Pressure, Urgency, Importance, Thinking needed, or Estimated time.",
                "The persistent top search finds root and nested Ladder tasks without changing their rank. Locate enters the matching group and reveals the row. Matches excluded by lifecycle, Blocked state, a Flag, or an unfinished prerequisite are listed separately with the reason.",
                "Pressure, Urgency, Importance, and Thinking needed use value sections such as High, Medium, Low, and No value. Moving a task across sections changes only the selected value; ordering within a section is a separate tie-break for that value.",
                "Estimated time is a factual numeric sort, so it cannot be manually reordered. Task Ladder placement is independent of Home, Backlog, and task-completion relationships.",
                "Paused, snoozed, blocked, completed, canceled, archived, and tasks hidden by a matching Flag do not appear. Groups can collect comparable tasks into smaller nested ladders."
            ],
            aliases: [
                "task ranking",
                "ranking ladder",
                "compare tasks",
                "priority ladder"
            ],
            keywords: [
                "pressure",
                "urgency",
                "importance",
                "thinking needed",
                "estimated time",
                "groups",
                "mac"
            ],
            platforms: ["macOS"],
            availability: "Available on macOS.",
            relatedTopicIDs: ["flags-and-tags", "backlog"],
            exampleQuestions: [
                "What is Task Ladder?",
                "Does moving a task in Task Ladder change its Home position?",
                "Why is a task missing from Task Ladder?"
            ]
        ),
        RoutinaHelpTopic(
            id: "planner-day-counts",
            title: "Numbers above Planner day columns",
            summary: "In Calendar Schedule, the number above a day is the total visible task-work count for that date.",
            details: [
                "The total combines the day\u{2019}s Planned tasks, Assumed done items, and Dones. Selecting the number opens the right-side day list with that breakdown.",
                "Planned tasks can include date-only Plan to do tasks, task-backed all-day items, and timed task blocks. Dones are recorded completion activity and can include visible unassigned or tag Focus activity.",
                "Calendar search, task filters, hidden activity, and layer visibility can change the count. It does not count standalone Events, Away, Sleep, or other protected-session blocks.",
                "Calendar List replaces the compact day-header number with separate per-day section counts."
            ],
            aliases: [
                "calendar day numbers",
                "numbers above calendar columns",
                "day header count",
                "calendar count badge",
                "numbers on top of day columns"
            ],
            keywords: [
                "planner",
                "calendar",
                "schedule",
                "day",
                "column",
                "count",
                "planned tasks",
                "assumed done",
                "dones"
            ],
            platforms: ["macOS"],
            availability: "Available in macOS Planner > Calendar > Schedule.",
            relatedTopicIDs: ["planner-time-meanings", "assumed-done"],
            exampleQuestions: [
                "What do the numbers above Calendar day columns mean?",
                "Why did a Calendar day count change?"
            ]
        ),
        RoutinaHelpTopic(
            id: "planner-time-meanings",
            title: "Availability, Plan to do, Schedule, Deadline, and Reminder",
            summary: "Routina keeps different meanings of time separate so planning does not silently become obligation.",
            details: [
                "Availability says when a task can be done. An available window is not automatically a scheduled Planner block.",
                "Plan to do is date-only intent: you want to consider the task on a day, but it does not create a time block or notification by itself.",
                "Schedule is a fixed time or explicit Planner placement. A task can have a scheduled block while retaining its separate deadline.",
                "Deadline says when a one-off task is due and can make it overdue. Reminder controls when Routina notifies you; changing it does not move the task in Planner.",
                "Completion records what actually happened. It remains distinct from all of the planning fields above."
            ],
            aliases: [
                "task dates",
                "planner dates",
                "plan versus deadline",
                "availability versus schedule",
                "due date versus reminder"
            ],
            keywords: [
                "availability",
                "plan to do",
                "schedule",
                "deadline",
                "reminder",
                "completion",
                "calendar"
            ],
            platforms: ["iOS", "iPadOS", "macOS"],
            availability: "The concepts are shared across platforms; available controls depend on task type and platform.",
            relatedTopicIDs: ["planner-day-counts", "repeating-tasks"],
            exampleQuestions: [
                "What is the difference between Availability and Schedule?",
                "Does Plan to do create a reminder?",
                "Why is a task in Planner before its deadline?"
            ]
        ),
        RoutinaHelpTopic(
            id: "assumed-done",
            title: "Assumed done",
            summary: "Assumed done is Routina\u{2019}s synthetic suggestion that eligible work probably happened; it is not yet a confirmed completion.",
            details: [
                "Assumed activity can appear in Home, Planner, Calendar List, and review surfaces when an eligible task has the configured automatic behavior.",
                "It does not create completion history until you confirm it. Confirming records a real completion; rejecting removes that assumption.",
                "Assumed and confirmed activity remain visually and semantically distinct so Timeline, Planner, and Stats do not overstate what happened.",
                "Calendar filters can hide assumed activity without changing the underlying task or creating a completion."
            ],
            aliases: [
                "auto assumed done",
                "automatic completion",
                "probably done",
                "synthetic completion"
            ],
            keywords: [
                "assumed",
                "confirm",
                "reject",
                "completion",
                "planner",
                "calendar",
                "history"
            ],
            platforms: ["iOS", "iPadOS", "macOS"],
            availability: "Available for eligible tasks configured with automatic assumption behavior.",
            relatedTopicIDs: ["planner-day-counts", "flags-and-tags"],
            exampleQuestions: [
                "What does Assumed done mean?",
                "Does Assumed done count as a real completion?",
                "How do I confirm or reject an assumed completion?"
            ]
        ),
        RoutinaHelpTopic(
            id: "flags-and-tags",
            title: "Flags and Tags",
            summary: "Tags describe and organize tasks; Flags can apply explicit behavior rules to tasks.",
            details: [
                "Use Tags for topics, projects, contexts, search, grouping, and filtering, such as #Home or #Admin.",
                "Use Flags when a task needs a behavior rule, such as hiding it from normal task lists, Task Ladder, or Timeline, or enabling another supported task behavior.",
                "A task can have both Tags and Flags. Neither one archives or deletes the task unless an explicitly assigned Flag rule says how a surface should treat it.",
                "Filters for Tags and Flags are independent, so revealing a hidden task in one surface does not change its saved Flag assignment."
            ],
            aliases: [
                "flags versus tags",
                "tag vs flag",
                "task labels",
                "behavior flags"
            ],
            keywords: [
                "organize",
                "filter",
                "hide",
                "rules",
                "task ladder",
                "timeline"
            ],
            platforms: ["iOS", "iPadOS", "macOS"],
            availability: "Tags and task Flags are available across Routina\u{2019}s current task surfaces; exact controls vary by platform.",
            relatedTopicIDs: ["task-ladder", "backlog", "assumed-done"],
            exampleQuestions: [
                "What is the difference between Flags and Tags?",
                "Why is a flagged task hidden from Home but still in Planner?"
            ]
        ),
        RoutinaHelpTopic(
            id: "backlog",
            title: "Backlog",
            summary: "Backlog is a full-size workspace in the main macOS window for work intentionally kept off the main task list.",
            details: [
                "Choose Backlog from the main window’s workspace menu or press Shift-Command-B.",
                "Routina has no generic unsectioned Backlog destination. A Home task's Move to > Backlog menu can create a new Backlog super section and assign that task; Settings can create an empty section for later use.",
                "Backlog super sections can contain one level of subsection. Empty sections stay visible so you can add a subsection immediately, and both levels can collapse.",
                "In macOS Settings -> Sections, use the Main task list / Backlog segmented picker to see and create sections for one workspace surface at a time. Subsections stay with their parent surface.",
                "Use the persistent top search to find deferred tasks by their text, tags, Flags, destination, or Backlog path. A matching task outside Backlog is labelled with its real location. Click its summary to open Task Details; active organizational matches can be shown in Planner, completed one-off matches can be shown in Timeline, and either can be moved to an explicit Backlog section without creating a duplicate.",
                "Moving a task to a Backlog section removes it from normal Home placement without completing, pausing, or deleting it. Move to Main Task List returns it to ordinary Home placement.",
                "The separate beta Board backlog is unrelated and does not create sections in the Backlog workspace."
            ],
            aliases: [
                "off radar",
                "backlog window",
                "move to backlog",
                "radar"
            ],
            keywords: [
                "section",
                "home",
                "hidden",
                "move",
                "mac",
                "board backlog"
            ],
            platforms: ["macOS"],
            availability: "Available on macOS.",
            relatedTopicIDs: ["task-ladder", "flags-and-tags"],
            exampleQuestions: [
                "How does Backlog work?",
                "Why can\u{2019}t I move a task to Backlog?",
                "What is the difference between Backlog and Board backlog?"
            ]
        ),
        RoutinaHelpTopic(
            id: "focus",
            title: "Focus",
            summary: "Focus records a bounded period of attention and can attribute that time to a task, a tag, or no item.",
            details: [
                "A Focus session can count up or use a fixed duration. Supported sessions can be paused, resumed, and finished while active time remains distinct from paused wall-clock time.",
                "Task Focus connects the session to a task. Tag Focus records time for a context such as #Admin. Unassigned Focus records attention without choosing either.",
                "Completed Focus activity can appear in Planner, Timeline, and Stats. On supported Mac flows, recorded tag Focus can be corrected from Calendar Schedule.",
                "Optional distraction blocking is available only where the current platform and build support it."
            ],
            aliases: [
                "focus timer",
                "focus session",
                "pomodoro",
                "tag focus",
                "task focus"
            ],
            keywords: [
                "timer",
                "count up",
                "duration",
                "pause",
                "planner",
                "timeline",
                "stats",
                "blocking"
            ],
            platforms: ["iOS", "iPadOS", "macOS"],
            availability: "Core Focus is available across platforms; attribution, editing, and blocking options vary.",
            relatedTopicIDs: ["planner-day-counts"],
            exampleQuestions: [
                "What does Focus record?",
                "What is the difference between Task Focus and Tag Focus?",
                "Why does Focus appear in Calendar?"
            ]
        ),
        RoutinaHelpTopic(
            id: "repeating-tasks",
            title: "Repeating tasks and routines",
            summary: "Repeating tasks preserve reusable work while separating cadence, availability, due pressure, and completion meaning.",
            details: [
                "Due routines can become due or overdue. Gentle routines stay available without overdue pressure and can use a later nudge.",
                "A repeating task can repeat by interval, calendar pattern, checklist item runout, or have no cadence. Availability separately says whether it is all-day, at a time, in a time block, or within a window.",
                "No schedule keeps reusable work available immediately after completion. When needed pauses it after completion until you choose Resume.",
                "Standard completion finishes the occurrence directly. Checklist and sequential-step options can require more progress before completion.",
                "Changes over time appears with the Task Ladder values for a Repeating routine set to Due with an active interval or calendar cadence. The form explains which choice is needed when the rule is unavailable."
            ],
            aliases: [
                "routines",
                "recurring tasks",
                "repeat types",
                "due versus gentle",
                "no schedule",
                "when needed",
                "changes over time",
                "due-date values"
            ],
            keywords: [
                "repeat",
                "interval",
                "calendar",
                "checklist",
                "runout",
                "availability",
                "overdue",
                "resume",
                "importance",
                "urgency",
                "pressure"
            ],
            platforms: ["iOS", "iPadOS", "macOS"],
            availability: "Repeating tasks are available across platforms; advanced combinations vary by task type and platform.",
            relatedTopicIDs: ["planner-time-meanings", "assumed-done"],
            exampleQuestions: [
                "What is the difference between Due and Gentle routines?",
                "What does When needed do?",
                "What is the difference between No schedule and When needed?",
                "How do I enable changes over time?"
            ]
        )
    ]

    public static func topic(id: String) -> RoutinaHelpTopic? {
        let normalizedID = normalizedPhrase(id)
        return topics.first { normalizedPhrase($0.id) == normalizedID }
    }

    public static func search(_ query: String, limit: Int = 5) -> [RoutinaHelpTopic] {
        let boundedLimit = max(0, min(limit, 10))
        guard boundedLimit > 0 else { return [] }

        let queryPhrase = normalizedPhrase(query)
        let queryTerms = searchableTerms(query)
        guard !queryTerms.isEmpty else {
            return Array(topics.prefix(boundedLimit))
        }

        return topics
            .compactMap { topic -> (topic: RoutinaHelpTopic, score: Int)? in
                let score = score(topic, queryPhrase: queryPhrase, queryTerms: queryTerms)
                return score > 0 ? (topic, score) : nil
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.topic.title.localizedCaseInsensitiveCompare(rhs.topic.title) == .orderedAscending
            }
            .prefix(boundedLimit)
            .map(\.topic)
    }

    private static func score(
        _ topic: RoutinaHelpTopic,
        queryPhrase: String,
        queryTerms: Set<String>
    ) -> Int {
        let title = normalizedPhrase(topic.title)
        let id = normalizedPhrase(topic.id)
        let aliases = topic.aliases.map(normalizedPhrase)

        var result = 0
        if queryPhrase == title || queryPhrase == id || aliases.contains(queryPhrase) {
            result += 200
        } else if title.contains(queryPhrase) || aliases.contains(where: { $0.contains(queryPhrase) }) {
            result += 80
        }

        let titleTerms = searchableTerms(topic.title)
        let aliasTerms = searchableTerms(topic.aliases.joined(separator: " "))
        let keywordTerms = searchableTerms(topic.keywords.joined(separator: " "))
        let summaryTerms = searchableTerms(topic.summary)
        let detailTerms = searchableTerms(topic.details.joined(separator: " "))

        for term in queryTerms {
            if titleTerms.contains(term) { result += 20 }
            if aliasTerms.contains(term) { result += 14 }
            if keywordTerms.contains(term) { result += 10 }
            if summaryTerms.contains(term) { result += 5 }
            if detailTerms.contains(term) { result += 2 }
        }
        return result
    }

    private static func normalizedPhrase(_ value: String) -> String {
        searchableTerms(value).sorted().joined(separator: " ")
    }

    private static func searchableTerms(_ value: String) -> Set<String> {
        let stopWords: Set<String> = [
            "a", "an", "and", "are", "at", "be", "do", "does", "each", "for", "how", "i",
            "in", "is", "it", "mean", "means", "of", "on", "the", "to", "what", "why"
        ]
        let folded = value.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        return Set(
            folded
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .map(canonicalTerm)
                .filter { !$0.isEmpty && !stopWords.contains($0) }
        )
    }

    private static func canonicalTerm(_ value: String) -> String {
        guard value.count > 3, value.hasSuffix("s"), !value.hasSuffix("ss") else {
            return value
        }
        return String(value.dropLast())
    }
}
