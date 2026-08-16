# Use Cases

This is the central catalog of user situations Routina is intended to support. It is organized by the person's goal rather than by app screen.

Availability is stated at a journey level:

- **Production:** available in the current production experience on at least one named platform.
- **Development experiment:** implemented for evaluation but not promised in production.
- **Proposed:** desired experience that has not been adopted as current behavior.
- **Mixed:** the core journey is available, while named parts vary by platform or build.

See [Current Behavior](../current-behavior/README.md) for the exact active contract and [Decisions](../decisions/README.md) for rationale.

## Capture

### UC-01 — Capture something before it is forgotten

**Situation:** A person remembers something they need or want to do, often while their attention is elsewhere.

**Need:** Save a clear task in seconds without deciding every scheduling detail now.

**Desired experience:** The shortest path asks for a meaningful title and confirms the save. Dates, recurrence, duration, tags, links, notes, and other details can be added when useful. A longer thought can open the full editor without retyping the title.

**Successful outcome:** The person trusts that the item is saved and can return to what they were doing.

**Example:** “Book dentist appointment” is captured immediately. The person later adds a weekday availability window and a reminder.

**Availability:** Production on iOS and macOS; entry points differ by platform.

### UC-02 — Describe a one-time task without confusing its dates

**Situation:** A task is available at one time, intended for another day, due later, or needs a reminder.

**Need:** Express those meanings independently.

**Desired experience:** Routina uses distinct controls and plain summaries for availability, plan, deadline, and reminder. Changing one does not silently rewrite the others except where the relationship is explicit and previewed.

**Successful outcome:** The task appears when and where the person expects, with the right level of urgency.

**Example:** A report becomes available Monday, is planned for Tuesday, is due Friday, and has a Thursday reminder.

**Availability:** Production. Exact combinations depend on task type and platform.

### UC-03 — Create a routine that matches real life

**Situation:** A responsibility repeats, but repetition may be fixed, interval-based, gentle, checklist-based, or temporarily paused.

**Need:** Describe the cadence and completion meaning without forcing every routine into a strict daily streak.

**Desired experience:** The person chooses how the routine repeats, when it is available, whether it should feel due or gently ready, and what counts as completion. The app previews the result in understandable language.

**Successful outcome:** The routine returns at the expected time, preserves its history, and can be changed without starting over.

**Example:** “Water plants” becomes available every seven days after completion and gives a gentle nudge rather than becoming overdue.

**Availability:** Production, with some advanced combinations varying by platform.

## Decide and Organize

### UC-04 — Understand what deserves attention now

**Situation:** The person opens Routina with many active and future items.

**Need:** See a calm, scannable set of relevant work.

**Desired experience:** Today, planned work, recurring responsibilities, future work, and intentionally hidden or backlogged work have understandable places. Important context is visible without opening every item. Optional grouping and filters reduce noise without deleting anything, and compact filter screens name each choice once instead of making the person scan repeated headings. On iOS, Priority groups the related choices while keeping Importance and Urgency independently adjustable, so changing one judgment never requires reselecting the other. Choosing filter tags feels like choosing tags while editing a task: one searchable plus/check list keeps each tag in one place, while the filter-only Show/Hide and All/Any choices remain explicit. After returning to Filters, the Filter tags row shows every active tag and grows to fit rather than hiding selections behind truncation or a count.

**Successful outcome:** The person can identify a useful next action without first reorganizing the whole system.

**Example:** Today's planned call and available daily routine are visible; next month's renewal stays in Future.

**Availability:** Production, with richer organization on macOS.

### UC-05 — Find an existing item quickly

**Situation:** The person remembers part of a task, tag, note, or recent activity but not where it is organized.

**Need:** Search without losing the surrounding workspace or accidentally creating a duplicate.

**Desired experience:** Search accepts typing immediately, returns understandable matches, and keeps clear recovery paths when filters hide a known item. Creating from a no-result query is offered only when it will not encourage an obvious duplicate.

**Successful outcome:** The person opens the intended item or confidently creates a new one.

**Example:** Searching “dentist” finds the task even though it is not in today's section; searching a genuinely new phrase can seed a new task.

**Availability:** Production on iOS and macOS.

### UC-06 — Choose work that fits the current moment

**Situation:** Several tasks matter, but the person has limited time or energy.

**Need:** Compare realistic options without relying on urgency alone.

**Desired experience:** Routina can narrow or rank actionable work using available time, energy, importance, urgency, pressure, and thinking needed. Missing information is gathered progressively, and any recommendation remains explainable and optional.

**Successful outcome:** The person chooses a task that fits both their capacity and responsibilities.

**Example:** With 30 minutes and low energy, the person sees a short low-thinking task instead of a two-hour deep-work task.

**Availability:** Mixed. Guided choice is currently iOS-oriented; macOS also provides a separate task-ranking workspace.

### UC-06A — Compare meaningful peers without losing the overall picture

**Situation:** The person has tasks from unrelated parts of life and several possible ways to satisfy some recurring commitments. Comparing every leaf task directly—such as calling Mom against fixing an analytics ticket—creates noise.

**Need:** Compare broad commitments or groups at the general level, then compare only the relevant tasks inside the chosen context, without changing what task completion means.

**Desired experience:** Task Ladder placement and completion remain separate. A container-only group such as Company opens its own ladder but never completes. Each group value can be explicit, absent, or inherited from the highest value among its actionable direct tasks, so the general ladder reflects the group's current work without copying metadata. A real repeating commitment such as Exercise can be activated as a Task Ladder group while it is created, edited, viewed in Task Details, or organized in the Ladder, without losing its recurrence or history and even before it has children. When Exercise already has linked tasks, its nested ladder offers the eligible links as child suggestions rather than placing them automatically; the person can accept or reject each suggestion without changing or removing the link. It can then contain Walk, Gym, or Swim while each option independently does nothing to Exercise, asks whether it can complete Exercise, or completes Exercise automatically. One click on a Ladder row shows the task or container-group details, so Exercise can be inspected without leaving the general comparison; a deliberate double-click opens its inner ladder. The person can add more tasks from Exercise itself or return any nested task to the general ladder without losing it.

**Successful outcome:** The root ladder stays small enough to compare, nested ladders contain meaningful peers, and the person can explain both where a task appears and what completing it will do.

**Example:** The root compares Company, Exercise, Family, and an independent “Call Mom” task. Company inherits High pressure while any actionable direct Company task has High pressure, then falls to the next-highest available value as that work leaves the Ladder. Company opens independent work obligations. Exercise opens activity choices; completing Walk asks whether today’s Exercise commitment should also be fulfilled.

**Availability:** Development experiment on macOS. Temporary group focus and a cross-group “What should I do now?” recommendation remain proposed.

### UC-07 — Keep someday or hidden work without daily noise

**Situation:** Some work is worth keeping but should not compete with everyday priorities.

**Need:** Move it off the radar while retaining searchability, context, and a return path.

**Desired experience:** Pausing, archiving, backlog organization, and visibility rules have distinct meanings. The item is not lost, completed, or silently rescheduled.

**Successful outcome:** Everyday views remain manageable and deferred work can be recovered deliberately.

**Example:** A future home-renovation idea moves to Backlog and can later return to normal task lists.

**Availability:** Mixed; pause and archive are broadly available, while the dedicated Backlog workspace is on macOS.

## Plan and Act

### UC-08 — Build a realistic day plan

**Situation:** The person wants to combine fixed commitments, flexible tasks, routines, and available time.

**Need:** Turn intention into a visual day without changing every task into a deadline.

**Desired experience:** The Planner distinguishes fixed schedule, all-day intent, date-only planning, and flexible work. Items can be placed, moved, reviewed, or removed from the plan while retaining their original task meaning.

**Successful outcome:** The person can see whether the day fits and adjust before committing attention.

**Example:** A 10:00 appointment stays fixed, “write outline” is placed in a 45-minute block, and “buy groceries” remains an all-day intention.

**Availability:** Production on macOS. Compact-platform planning routes may differ.

### UC-09 — Focus on chosen work

**Situation:** The person has selected a task and wants a bounded period of attention.

**Need:** Start a focus session with enough context and optional distraction protection.

**Desired experience:** The person can choose the task and duration, see active progress, pause or finish appropriately, and understand how the session will appear in history. Blocking is offered only where the current platform can support it.

**Successful outcome:** The session supports attention without making later history ambiguous.

**Example:** Start 25 minutes on “Draft proposal,” block selected Mac apps, pause for an interruption, then resume and finish.

**Availability:** Mixed by platform and protection capability.

## Record and Correct Reality

### UC-10 — Record what actually happened

**Situation:** A task was completed, missed, canceled, or finished at a different time than planned.

**Need:** Keep an honest record without rewriting the original plan.

**Desired experience:** Outcomes are distinct, the relevant occurrence is clear, and late entry or correction is possible where the meaning remains unambiguous. An assumption never looks identical to a confirmed completion.

**Successful outcome:** Timeline, Planner, and Stats tell a consistent story.

**Example:** A 09:00 routine is completed at 10:15 and logged against the 09:00 occurrence; yesterday's missed occurrence remains separately resolvable.

**Availability:** Production.

### UC-11 — Add context that explains the day

**Situation:** Work alone does not explain the person's time or capacity.

**Need:** Record relevant context such as sleep, time away, a note, an event, an emotion, or a place visit without pretending it is a task.

**Desired experience:** Each record keeps its own meaning and appears in a coherent personal history. Optional context features do not complicate the core task experience when unavailable or disabled, including by leaving unavailable choices in creation or history filters.

**Successful outcome:** Later review explains the day more accurately.

**Example:** A sick day and an afternoon sleep session explain why planned tasks were not completed.

**Availability:** Development experiment for several context types; production availability is intentionally limited. See the current-behavior feature gates.

## Review and Adapt

### UC-12 — Reconstruct a day or period

**Situation:** The person wants to remember what happened and how plans changed.

**Need:** Review one chronological history across relevant activity types.

**Desired experience:** The Timeline presents clear outcomes and context in a stable order, supports filtering and date navigation, opens the source record for detail or correction, and offers only type filters whose features are currently available. A person can keep activity from behavior-heavy or private tasks out of the default history through a Flag rule, then deliberately reveal matching activity from the Timeline's Flag filter without losing or changing the underlying record.

**Successful outcome:** The person understands the period without relying on memory or combining several disconnected logs.

**Example:** Review yesterday to see completed work, a canceled routine, focus time, and a contextual note; select a hidden task's Flag when that quieter activity is relevant to the review.

**Availability:** Production, with available record types varying by feature gate.

### UC-13 — Learn from patterns without false precision

**Situation:** The person wants to know how work, focus, routines, or wellbeing changed over time.

**Need:** See meaningful summaries for a chosen period and understand their scope.

**Desired experience:** Stats uses the same selected date boundaries across reports, hides empty or unavailable reports, distinguishes recorded from assumed activity, and lets the person customize what matters.

**Successful outcome:** The person identifies a useful pattern without mistaking an estimate or incomplete dataset for certainty.

**Example:** Compare focus time and completed work this month, while assumed routine completions remain visibly separate from recorded completions.

**Availability:** Production for core reports; optional reports vary by platform, data, permission, and feature gate.

### UC-14 — Change the system as life changes

**Situation:** A routine, priority, schedule, or organizational structure no longer fits.

**Need:** Adjust it without losing history or creating duplicate records.

**Desired experience:** Editing affects future behavior in a previewable way. Pausing, archiving, restoring, reorganizing, and changing cadence preserve past meaning. Risky changes provide confirmation or recovery. On iOS Task Details, secondary maintenance actions such as sharing a task link, canceling an eligible todo, or deleting the task stay together in a familiar top-bar overflow instead of competing with completion or being scattered through Edit Task.

**Successful outcome:** Routina adapts with the person rather than forcing a restart.

**Example:** A weekly routine becomes biweekly after completion while its earlier weekly history remains intact.

**Availability:** Production; exact editing choices depend on item type.

## Trust and Continuity

### UC-15 — Continue safely across devices

**Situation:** The person captures on one device and later plans or reviews on another.

**Need:** Trust that personal data and durable preferences remain coherent.

**Desired experience:** Synchronization is unobtrusive, conflicts do not silently discard history, and manual refresh reports only what it can verify. Platform-specific layouts preserve the same product concepts. On iOS, the task calendar stays collapsed until it is useful, and each task remembers whether the person left its calendar expanded or collapsed when Task Details is reopened.

**Successful outcome:** The person continues the same task or review without reconstructing work.

**Example:** Capture a task on iPhone, then find and schedule it on Mac after synchronization.

**Availability:** Production where iCloud is configured and available.

### UC-16 — Back up, recover, or reset personal data safely

**Situation:** The person is changing devices, troubleshooting synchronization, or considering a destructive reset.

**Need:** Protect personal history before taking a risky action.

**Desired experience:** Backup and restore are complete and understandable. Destructive operations require a recent backup and device-owner authentication. Diagnostics explain the build and sync state without copying personal content.

**Successful outcome:** The person can recover data or proceed with an informed reset without an avoidable loss.

**Example:** Before resetting cloud data, Routina requires a recent export and fresh authentication.

**Availability:** Production.

## Coverage Gaps to Validate

The catalog reflects the current product direction, but these questions still need direct user evidence:

- Which moment causes the most friction: capture, choosing, planning, or correcting history?
- Do people understand the distinction between availability, planning, deadline, reminder, and scheduled time without explanation?
- Which review patterns lead to a useful decision rather than passive dashboard viewing?
- Which contextual records are valuable enough to promote from development experiments into production?
- How much cross-platform consistency do people expect, and where do they prefer platform-specific workflows?
- Which recovery actions are difficult to discover after an item is hidden, paused, archived, or moved to Backlog?
