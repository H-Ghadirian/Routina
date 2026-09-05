import Foundation

extension RoutinaScreenshotDataSeeder {
    struct SeedDates {
        var calendar: Calendar
        var today: Date

        init(referenceDate: Date, calendar: Calendar) {
            self.calendar = calendar
            self.today = calendar.startOfDay(for: referenceDate)
        }

        func at(dayOffset: Int, hour: Int, minute: Int = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
            return calendar.date(
                bySettingHour: hour,
                minute: minute,
                second: 0,
                of: day
            ) ?? day
        }
    }

    static func seedID(_ value: Int) -> UUID {
        let suffix = String(format: "%012X", value)
        guard let id = UUID(uuidString: "A11CE000-5EED-4000-8000-\(suffix)") else {
            preconditionFailure("Invalid screenshot fixture ID: \(value)")
        }
        return id
    }

    static func makeCustomSections(dates: SeedDates) -> [HomeCustomTaskSection] {
        let launchID = seedID(20_000)
        let laterID = seedID(20_003)
        return [
            HomeCustomTaskSection(
                id: launchID,
                surface: .radar,
                title: "Launch",
                createdAt: dates.at(dayOffset: -60, hour: 9),
                rules: HomeCustomTaskSectionRules(tagNames: ["Routina", "Work"]),
                colorHex: "#5856D6"
            ),
            HomeCustomTaskSection(
                id: seedID(20_001),
                parentSectionID: launchID,
                surface: .radar,
                title: "App Store",
                createdAt: dates.at(dayOffset: -45, hour: 9),
                rules: HomeCustomTaskSectionRules(tagNames: ["Release"]),
                colorHex: "#AF52DE"
            ),
            HomeCustomTaskSection(
                id: seedID(20_002),
                surface: .radar,
                title: "Personal",
                createdAt: dates.at(dayOffset: -55, hour: 9),
                rules: HomeCustomTaskSectionRules(tagNames: ["Personal", "Health"]),
                colorHex: "#34C759"
            ),
            HomeCustomTaskSection(
                id: laterID,
                surface: .backlog,
                title: "Later",
                createdAt: dates.at(dayOffset: -42, hour: 9),
                colorHex: "#FF9F0A"
            ),
            HomeCustomTaskSection(
                id: seedID(20_004),
                parentSectionID: laterID,
                surface: .backlog,
                title: "Research",
                createdAt: dates.at(dayOffset: -36, hour: 9),
                rules: HomeCustomTaskSectionRules(tagNames: ["Research"]),
                colorHex: "#64D2FF"
            ),
        ]
    }

    static func makeLogs(dates: SeedDates, tasks: [RoutineTask]) -> [RoutineLog] {
        var logs: [RoutineLog] = []
        var nextID = 1_000

        func append(
            taskIndex: Int,
            dayOffset: Int,
            hour: Int,
            minute: Int = 0,
            kind: RoutineLogKind = .completed,
            duration: Int? = nil
        ) {
            logs.append(
                RoutineLog(
                    id: seedID(nextID),
                    timestamp: dates.at(dayOffset: dayOffset, hour: hour, minute: minute),
                    taskID: tasks[taskIndex].id,
                    kind: kind,
                    actualDurationMinutes: duration,
                    hasSpecificWorkTime: duration == nil ? nil : true
                )
            )
            nextID += 1
        }

        for dayOffset in -28...0 {
            if dayOffset == 0 || !dayOffset.isMultiple(of: 7) {
                append(
                    taskIndex: 0,
                    dayOffset: dayOffset,
                    hour: 7,
                    minute: 35,
                    duration: 10
                )
            } else {
                append(taskIndex: 0, dayOffset: dayOffset, hour: 20, kind: .missed)
            }

            if dayOffset < 0, !dayOffset.isMultiple(of: 3) {
                append(
                    taskIndex: 1,
                    dayOffset: dayOffset,
                    hour: 10,
                    minute: 45,
                    duration: 75 + abs(dayOffset % 3) * 10
                )
            }

            if dayOffset < 0, dayOffset.isMultiple(of: 2) {
                append(
                    taskIndex: 2,
                    dayOffset: dayOffset,
                    hour: 16,
                    duration: 30
                )
            }

            if dayOffset <= -2, dayOffset.isMultiple(of: 2) {
                append(
                    taskIndex: 3,
                    dayOffset: dayOffset,
                    hour: 21,
                    duration: 25
                )
            }
        }

        for dayOffset in [-22, -15, -8] {
            append(taskIndex: 4, dayOffset: dayOffset, hour: 17, duration: 45)
        }

        for dayOffset in [-18, -11, -4] {
            append(taskIndex: 5, dayOffset: dayOffset, hour: 18, duration: 35)
        }

        append(taskIndex: 7, dayOffset: -3, hour: 15, kind: .canceled)
        return logs
    }

    static func makePlannerBlocks(
        dates: SeedDates,
        tasks: [RoutineTask]
    ) -> [DayPlanBlockRecord] {
        let dayKey = DayPlanStorage.dayKey(for: dates.today, calendar: dates.calendar)
        let specifications = [
            PlannerBlockSpecification(taskIndex: 0, startMinute: 7 * 60 + 30, durationMinutes: 30),
            PlannerBlockSpecification(taskIndex: 1, startMinute: 9 * 60 + 30, durationMinutes: 90),
            PlannerBlockSpecification(taskIndex: 7, startMinute: 13 * 60, durationMinutes: 30),
            PlannerBlockSpecification(taskIndex: 6, startMinute: 14 * 60, durationMinutes: 90),
            PlannerBlockSpecification(taskIndex: 2, startMinute: 17 * 60 + 15, durationMinutes: 30),
        ]

        return specifications.enumerated().map { index, specification in
            let task = tasks[specification.taskIndex]
            return DayPlanBlockRecord(
                id: seedID(3_000 + index),
                taskID: task.id,
                dayKey: dayKey,
                startMinute: specification.startMinute,
                durationMinutes: specification.durationMinutes,
                titleSnapshot: task.name ?? "Untitled task",
                emojiSnapshot: task.emoji,
                createdAt: dates.at(dayOffset: -1, hour: 18),
                updatedAt: dates.at(dayOffset: -1, hour: 18)
            )
        }
    }

    static func makeFocusSessions(
        dates: SeedDates,
        tasks: [RoutineTask]
    ) -> [FocusSession] {
        (0..<14).map { index in
            let dayOffset = -(index + 1)
            let startedAt = dates.at(
                dayOffset: dayOffset,
                hour: index.isMultiple(of: 3) ? 14 : 9,
                minute: 30
            )
            let durationMinutes = 45 + (index % 4) * 15
            return FocusSession(
                id: seedID(4_000 + index),
                taskID: index.isMultiple(of: 4) ? tasks[6].id : tasks[1].id,
                startedAt: startedAt,
                plannedDurationSeconds: TimeInterval(durationMinutes * 60),
                completedAt: startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
            )
        }
    }

    static func makeNotes(dates: SeedDates) -> [RoutineNote] {
        [
            RoutineNote(
                id: seedID(7_000),
                title: "Screenshot direction",
                body: "Keep the interface calm and spacious. Show enough real activity to make every screen feel lived in.",
                tags: ["Routina", "Creative"],
                createdAt: dates.at(dayOffset: -2, hour: 11),
                updatedAt: dates.at(dayOffset: -1, hour: 15)
            ),
            RoutineNote(
                id: seedID(7_001),
                title: "Weekly reflection",
                body: "The best work happened after protecting the first ninety minutes of the morning.",
                tags: ["Reflection", "Focus"],
                createdAt: dates.at(dayOffset: -6, hour: 18),
                updatedAt: dates.at(dayOffset: -6, hour: 18)
            ),
            RoutineNote(
                id: seedID(7_002),
                body: "Finished the core flow. Next: polish the visuals and prepare the release notes.",
                tags: ["Status", "Routina"],
                createdAt: dates.at(dayOffset: -1, hour: 17),
                updatedAt: dates.at(dayOffset: -1, hour: 17)
            ),
        ]
    }

    static func makeSleepSessions(dates: SeedDates) -> [SleepSession] {
        (0..<10).map { index in
            let startedAt = dates.at(dayOffset: -(index + 1), hour: 23)
            let durationMinutes = 7 * 60 + 15 + (index % 4) * 15
            return SleepSession(
                id: seedID(5_000 + index),
                startedAt: startedAt,
                endedAt: startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60)),
                targetDurationMinutes: 8 * 60,
                createdAt: startedAt,
                updatedAt: startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
            )
        }
    }

    static func makeAwaySessions(
        dates: SeedDates,
        tasks: [RoutineTask]
    ) -> [AwaySession] {
        [
            (6_000, -1, 12, AwaySessionPreset.meal, "Lunch break", 35),
            (6_001, -2, 16, AwaySessionPreset.outside, "Afternoon walk", 30),
            (6_002, -4, 11, AwaySessionPreset.reset, "Screen break", 15),
            (6_003, -6, 18, AwaySessionPreset.windDown, "Evening reset", 30),
        ].map { id, dayOffset, hour, preset, title, durationMinutes in
            let startedAt = dates.at(dayOffset: dayOffset, hour: hour)
            return AwaySession(
                id: seedID(id),
                preset: preset,
                title: title,
                linkedTaskID: preset == .outside ? tasks[2].id : nil,
                startedAt: startedAt,
                plannedDurationSeconds: TimeInterval(durationMinutes * 60),
                completedAt: startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60)),
                createdAt: startedAt,
                updatedAt: startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
            )
        }
    }

    struct PlannerBlockSpecification {
        var taskIndex: Int
        var startMinute: Int
        var durationMinutes: Int
    }

}
