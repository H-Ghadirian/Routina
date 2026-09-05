import Foundation
import SwiftData

extension FocusSessionSupport {
    @MainActor
    @discardableResult
    static func finishFocus(
        sessionID: UUID?,
        kind: FocusSessionKind?,
        endedAt: Date = Date(),
        context: ModelContext,
        calendar: Calendar = .current,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> Bool {
        switch kind {
        case .sprint:
            return try finishSprintFocus(sessionID: sessionID, endedAt: endedAt, context: context, sourceDevice: sourceDevice)
        case .task, .tag, .unassigned, nil:
            if try finishTaskFocus(
                sessionID: sessionID,
                kind: kind,
                endedAt: endedAt,
                context: context,
                calendar: calendar,
                sourceDevice: sourceDevice
            ) {
                return true
            }

            guard kind == nil else { return false }
            return try finishSprintFocus(sessionID: sessionID, endedAt: endedAt, context: context, sourceDevice: sourceDevice)
        }
    }

    @MainActor
    @discardableResult
    static func pauseFocus(
        sessionID: UUID?,
        kind: FocusSessionKind?,
        pausedAt: Date = Date(),
        calendar: Calendar = .current,
        context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> Bool {
        if kind == .sprint {
            return try pauseSprintFocus(
                sessionID: sessionID,
                pausedAt: pausedAt,
                context: context,
                sourceDevice: sourceDevice
            )
        }

        if let session = try activeTaskFocus(sessionID: sessionID, kind: kind, in: context),
            session.pause(at: pausedAt)
        {
            try savePausedCountUpFocusSegment(for: session, pausedAt: pausedAt, calendar: calendar, context: context)
            let title = try focusTitle(for: session, in: context)
            DeviceActivityRecorder.recordAction(
                .paused,
                entity: .focusSession,
                entityID: session.id,
                entityTitle: title,
                details: "Paused focus session",
                sourceDevice: sourceDevice,
                at: pausedAt,
                in: context
            )
            try context.save()
            notifyFocusChanged(using: context)
            return true
        }

        guard kind == nil else { return false }
        return try pauseSprintFocus(
            sessionID: sessionID,
            pausedAt: pausedAt,
            context: context,
            sourceDevice: sourceDevice
        )
    }

    @MainActor
    @discardableResult
    static func resumeFocus(
        sessionID: UUID?,
        kind: FocusSessionKind?,
        resumedAt: Date = Date(),
        calendar: Calendar = .current,
        context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> Bool {
        if kind == .sprint {
            return try resumeSprintFocus(
                sessionID: sessionID,
                resumedAt: resumedAt,
                context: context,
                sourceDevice: sourceDevice
            )
        }

        if let session = try activeTaskFocus(sessionID: sessionID, kind: kind, in: context),
            let pausedAt = session.pausedAt
        {
            try savePausedCountUpFocusSegment(for: session, pausedAt: pausedAt, calendar: calendar, context: context)
            guard session.resume(at: resumedAt) else {
                return false
            }
            try saveResumedCountUpFocusSegment(for: session, resumedAt: resumedAt, calendar: calendar, context: context)
            let title = try focusTitle(for: session, in: context)
            DeviceActivityRecorder.recordAction(
                .resumed,
                entity: .focusSession,
                entityID: session.id,
                entityTitle: title,
                details: "Resumed focus session",
                sourceDevice: sourceDevice,
                at: resumedAt,
                in: context
            )
            try context.save()
            notifyFocusChanged(using: context)
            return true
        }

        guard kind == nil else { return false }
        return try resumeSprintFocus(
            sessionID: sessionID,
            resumedAt: resumedAt,
            context: context,
            sourceDevice: sourceDevice
        )
    }

    @MainActor
    @discardableResult
    static func abandonFocus(
        sessionID: UUID?,
        kind: FocusSessionKind?,
        endedAt: Date = Date(),
        context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> Bool {
        if kind == .sprint {
            return try abandonSprintFocus(
                sessionID: sessionID,
                endedAt: endedAt,
                context: context,
                sourceDevice: sourceDevice
            )
        }

        if let session = try activeTaskFocus(sessionID: sessionID, kind: kind, in: context) {
            session.closePauseIfNeeded(at: endedAt)
            session.abandonedAt = endedAt
            DayPlanFocusSessionPlannerSync.removeFocusBlock(for: session, context: context)

            let title = try focusTitle(for: session, in: context)
            DeviceActivityRecorder.recordAction(
                .ended,
                entity: .focusSession,
                entityID: session.id,
                entityTitle: title,
                details: "Abandoned focus session",
                sourceDevice: sourceDevice,
                at: endedAt,
                in: context
            )
            try context.save()
            notifyFocusChanged(using: context)
            return true
        }

        guard kind == nil else { return false }
        return try abandonSprintFocus(
            sessionID: sessionID,
            endedAt: endedAt,
            context: context,
            sourceDevice: sourceDevice
        )
    }

    @MainActor
    private static func finishTaskFocus(
        sessionID: UUID?,
        kind: FocusSessionKind?,
        endedAt: Date,
        context: ModelContext,
        calendar: Calendar,
        sourceDevice: RoutinaDeviceActivitySource?
    ) throws -> Bool {
        guard let session = try activeTaskFocus(sessionID: sessionID, kind: kind, in: context) else {
            return false
        }

        let pausedAt = session.pausedAt
        if let pausedAt {
            try savePausedCountUpFocusSegment(for: session, pausedAt: pausedAt, calendar: calendar, context: context)
        }
        session.closePauseIfNeeded(at: endedAt)
        session.completedAt = endedAt
        if pausedAt == nil,
            session.isTaskFocus,
            session.plannedDurationSeconds <= 0,
            let task = try task(id: session.taskID, in: context)
        {
            DayPlanFocusSessionPlannerSync.saveEndedCountUpFocusBlock(
                for: task,
                session: session,
                endedAt: endedAt,
                calendar: calendar,
                context: context
            )
        } else if pausedAt == nil,
            session.isTagFocus,
            session.plannedDurationSeconds <= 0,
            let tagName = session.focusTagName
        {
            DayPlanFocusSessionPlannerSync.saveEndedCountUpTagFocusBlock(
                tagName: tagName,
                session: session,
                endedAt: endedAt,
                calendar: calendar,
                context: context
            )
        }

        let title = try focusTitle(for: session, in: context)
        DeviceActivityRecorder.recordAction(
            .completed,
            entity: .focusSession,
            entityID: session.id,
            entityTitle: title,
            sourceDevice: sourceDevice,
            at: endedAt,
            in: context
        )
        try context.save()
        notifyFocusChanged(using: context)
        return true
    }

    @MainActor
    private static func finishSprintFocus(
        sessionID: UUID?,
        endedAt: Date,
        context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource?
    ) throws -> Bool {
        guard let session = try activeSprintFocus(sessionID: sessionID, in: context) else {
            return false
        }

        session.closePauseIfNeeded(at: endedAt)
        session.stoppedAt = endedAt
        DeviceActivityRecorder.recordAction(
            .completed,
            entity: .focusSession,
            entityID: session.id,
            entityTitle: try sprint(id: session.sprintID, in: context)?.title ?? "Sprint focus",
            sourceDevice: sourceDevice,
            at: endedAt,
            in: context
        )
        try context.save()
        notifyFocusChanged(using: context)
        return true
    }

    @MainActor
    private static func pauseSprintFocus(
        sessionID: UUID?,
        pausedAt: Date,
        context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource?
    ) throws -> Bool {
        guard let session = try activeSprintFocus(sessionID: sessionID, in: context),
            session.pause(at: pausedAt)
        else {
            return false
        }

        DeviceActivityRecorder.recordAction(
            .paused,
            entity: .focusSession,
            entityID: session.id,
            entityTitle: try sprint(id: session.sprintID, in: context)?.title ?? "Sprint focus",
            details: "Paused sprint focus session",
            sourceDevice: sourceDevice,
            at: pausedAt,
            in: context
        )
        try context.save()
        notifyFocusChanged(using: context)
        return true
    }

    @MainActor
    private static func resumeSprintFocus(
        sessionID: UUID?,
        resumedAt: Date,
        context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource?
    ) throws -> Bool {
        guard let session = try activeSprintFocus(sessionID: sessionID, in: context),
            session.resume(at: resumedAt)
        else {
            return false
        }

        DeviceActivityRecorder.recordAction(
            .resumed,
            entity: .focusSession,
            entityID: session.id,
            entityTitle: try sprint(id: session.sprintID, in: context)?.title ?? "Sprint focus",
            details: "Resumed sprint focus session",
            sourceDevice: sourceDevice,
            at: resumedAt,
            in: context
        )
        try context.save()
        notifyFocusChanged(using: context)
        return true
    }

    @MainActor
    private static func abandonSprintFocus(
        sessionID: UUID?,
        endedAt: Date,
        context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource?
    ) throws -> Bool {
        guard let session = try activeSprintFocus(sessionID: sessionID, in: context) else {
            return false
        }

        let title = try sprint(id: session.sprintID, in: context)?.title ?? "Sprint focus"
        let sessionID = session.id
        let allocations = try context.fetch(FetchDescriptor<SprintFocusAllocationRecord>())
            .filter { $0.sessionID == sessionID }
        for allocation in allocations {
            context.delete(allocation)
        }
        context.delete(session)
        DeviceActivityRecorder.recordAction(
            .ended,
            entity: .focusSession,
            entityID: sessionID,
            entityTitle: title,
            details: "Abandoned sprint focus session",
            sourceDevice: sourceDevice,
            at: endedAt,
            in: context
        )
        try context.save()
        notifyFocusChanged(using: context)
        return true
    }
}
