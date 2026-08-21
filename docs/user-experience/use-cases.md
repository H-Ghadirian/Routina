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

**Desired experience:** The shortest path asks for a meaningful title and confirms the save. Common natural-language dates and times are recognized when typed with the title, including a weekday plus day and month followed by a 24-hour time. An unqualified one-off date/time means when the task is available, while `due` or `by` explicitly means a deadline. On iOS, recognized one-off availability is visible as an `Available` detail before saving so the person can verify the date and time. Exact availability offers an optional reminder choice before saving and never silently creates one; using that reminder menu or its custom date picker keeps the attached Quick Add preview open until the person finishes or deliberately dismisses it. Pasting only a web link immediately attaches the link and proposes an editable title; when safe public metadata is available, the proposal becomes page-specific without delaying capture or overwriting a user edit. Continuing to compose the same Quick Add query—such as typing another character or adding a tag—preserves an edited preview title, resolved link metadata, and the selected reminder instead of treating each keystroke as a new task. Once Detected details appears, its rectangle stays spatially stable while typing and updates its contents in place; a partial unparsable value shows an updating state instead of making the whole editor disappear. Dates, recurrence, duration, tags, links, notes, and other details can be added when useful. A longer thought can open the full editor without retyping the title. Task count never blocks capture or redirects the person into a purchase flow.

**Successful outcome:** The person trusts that the item is saved, regardless of how many other tasks they keep, and can return to what they were doing.

**Example:** “Book dentist appointment” is captured immediately and can be refined later. “Physiotherapist Tuesday, 25 August 15:00” is captured as a task named “Physiotherapist,” available on that date at 15:00, with a visible choice of no reminder, one or two hours before, one day before, or a custom reminder; appending `#health` keeps that choice. Pasting a YouTube URL creates a linked task with an editable `Watch YouTube video` fallback and, when metadata resolves first, a title such as `Watch: Better Mobility`; appending `#watch` keeps the edited title without fetching the same URL again.

**Evidence:** User-reported capture failure on 2026-08-20.

**Availability:** Production capture on iOS and macOS; the asynchronous editable link-title preview is currently available in the Mac toolbar search-or-create path.

### UC-02 — Describe a one-time task without confusing its dates

**Situation:** A task is available at one time, intended for another day, due later, or needs a reminder.

**Need:** Express those meanings independently.

**Desired experience:** Routina uses distinct controls and plain summaries for availability, plan, deadline, and reminder. Changing one does not silently rewrite the others except where the relationship is explicit and previewed. When an exact availability time is changed into a Time block or Available window, that time becomes the new range start and any relative reminder stays anchored to it. Before relying on alerts, the person can review every notification actually queued on the current device, grouped by task or event. They can expand one source to see its chronological occurrences, remove one occurrence, or postpone it without changing the source schedule or another device.

**Successful outcome:** The task appears when and where the person expects, with the right level of urgency, and the person can verify and adjust individual reminders the device is currently prepared to deliver.

**Example:** A report becomes available Monday, is planned for Tuesday, is due Friday, and has a Thursday reminder. In Notifications settings, the report group contains that queued reminder; postponing it one hour leaves the Friday deadline and the task unchanged.

**Availability:** Production. Exact combinations depend on task type and platform.

### UC-02a — Keep a task's destination easy to reach

**Situation:** A task happens at a specific address, such as a clinic, shop, or meeting place, and the person may need directions later.

**Need:** Keep the address with the task and open it in a map app without turning it into a reusable geofenced Place.

**Desired experience:** Add Task and Edit Task let the person enter an address and explicitly find its map location. Task Details show the address and map together, with Apple Maps and Google Maps actions on iPhone. A typed address remains useful even when lookup cannot find coordinates.

**Successful outcome:** The person can confirm where the task happens from Task Details and start navigation without reopening the editor or recreating the address in another app.

**Example:** “Physiotherapist” stores “Alexanderplatz 1, Berlin”; Task Details show the address and map, and tapping Apple Maps or Google Maps opens that destination.

**Availability:** Production on iOS and macOS; provider actions are available where the corresponding URL handler is supported.

**Evidence:** User-requested destination workflow on 2026-08-20.

### UC-03 — Create a routine that matches real life

**Situation:** A responsibility repeats, but repetition may be fixed, interval-based, gentle, checklist-based, or waiting for the person to activate it again after completion.

**Need:** Describe the cadence and completion meaning without forcing every routine into a strict daily streak.

**Desired experience:** The person chooses how the routine repeats, when it is available, whether it should feel due or gently ready, and what counts as completion. For work whose next use is unknown, `When needed` pauses it after completion and the person can use `Resume` whenever it is needed again; ordinary `No schedule` remains available immediately. The app previews the result in understandable language.

**Successful outcome:** The routine returns at the expected time, preserves its history, and can be changed without starting over.

**Example:** “Water plants” becomes available every seven days after completion and gives a gentle nudge rather than becoming overdue. “Replace the filter” uses `When needed`, disappears from active work after it is completed, and returns when the person resumes it before the next replacement.

**Availability:** Production, with some advanced combinations varying by platform.

## Decide and Organize

### UC-04 — Understand what deserves attention now

**Situation:** The person opens Routina with many active and future items.

**Need:** See a calm, scannable set of relevant work.

**Desired experience:** Today, planned work, recurring responsibilities, future work, and intentionally hidden or backlogged work have understandable places. Important context is visible without opening every item. A task with an unfinished linked prerequisite reads as Blocked in the Home task list and wherever Task Details summarizes its effective state, never simultaneously as To Do, Ready, or In Progress; resolving the prerequisite restores the person's earlier workflow state without rewriting its history. Repeating task chains advance one completion at a time: finishing a prerequisite unlocks the dependent until that dependent finishes, even if the prerequisite immediately recurs or is paused to leave the active list. Optional grouping and filters reduce noise without deleting anything, and compact filter screens name each choice once instead of making the person scan repeated headings. On iOS, Priority groups the related choices; in the Mac Stats sidebar, Importance and Urgency appear as separate filter sections. In both places they remain independently adjustable, so changing one judgment never requires reselecting the other. Choosing filter tags feels like choosing tags while editing a task: one searchable plus/check list keeps each tag in one place, while the filter-only Show/Hide and All/Any choices remain explicit. After returning to Filters, the Filter tags row shows every active tag and grows to fit rather than hiding selections behind truncation or a count.

**Successful outcome:** The person can identify a useful next action without first reorganizing the whole system.

**Example:** Today's planned call and available daily routine are visible; next month's renewal stays in Future. In a repeating release chain, “Release Candidate” shows Blocked until “Run Test.io” is completed. It stays unlocked when “Run Test.io” recurs or is paused, then the next “Release Candidate” pass waits for the next Test.io completion.

**Availability:** Production, with richer organization on macOS.

### UC-05 — Find an existing item quickly

**Situation:** The person remembers part of a task, tag, note, or recent activity but not where it is organized.

**Need:** Search without losing the surrounding workspace or accidentally creating a duplicate.

**Desired experience:** Search accepts typing immediately, returns understandable matches, and keeps clear recovery paths when filters or normal placement hide a known item. A broader query includes every eligible item that a more specific version of the same query can find, even when other matches already occupy normal task-list sections. Creating from a no-result query is offered only when it will not encourage an obvious duplicate.

**Successful outcome:** The person opens the intended item or confidently creates a new one.

**Example:** Searching “dentist” finds the task even though it is not in today's section. On Mac, searching “watch” does not omit a known “Watch movie” task that also appears for “watch m”. Searching a genuinely new phrase can seed a new task.

**Availability:** Production on iOS and macOS.

### UC-06 — Choose work that fits the current moment

**Situation:** Several tasks matter, but the person has limited time or energy.

**Need:** Compare realistic options without relying on urgency alone.

**Desired experience:** Routina can narrow or rank actionable work using available time, energy, importance, urgency, pressure, and thinking needed. Missing information is gathered progressively, and any recommendation remains explainable and optional. While the guided iOS journey is still being evaluated, release versions leave it out of More; development builds keep it together under Review tasks and mark the screen with an orange `DEV` label.

**Successful outcome:** The person chooses a task that fits both their capacity and responsibilities.

**Example:** With 30 minutes and low energy, the person sees a short low-thinking task instead of a two-hour deep-work task.

**Availability:** Mixed. Guided choice and missing-detail review are development experiments on iOS; macOS also provides a separate development task-ranking workspace.

### UC-06A — Compare meaningful peers without losing the overall picture

**Situation:** The person has tasks from unrelated parts of life and several possible ways to satisfy some recurring commitments. Comparing every leaf task directly—such as calling Mom against fixing an analytics ticket—creates noise.

**Need:** Compare broad commitments or groups at the general level, then compare only the relevant tasks inside the chosen context, without changing what task completion means.

**Desired experience:** Task Ladder placement and completion remain separate. A container-only group such as Company opens its own ladder but never completes. Each group value can be explicit, absent, or inherited from the highest value among its actionable direct tasks, so the general ladder reflects the group's current work without copying metadata. A real repeating commitment such as Exercise can be activated as a Task Ladder group while it is created, deliberately edited, or organized in the Ladder, without losing its recurrence or history and even before it has children. Ordinary Task Details stays focused on broadly useful task information; changing an existing task's group role happens through Edit Task. When Exercise already has linked tasks, its nested ladder offers the eligible links as child suggestions rather than placing them automatically; the person can accept or reject each suggestion without changing or removing the link. It can then contain Walk, Gym, or Swim while each option independently does nothing to Exercise, asks whether it can complete Exercise, or completes Exercise automatically. One click on a Ladder row shows the task or container-group details, so Exercise can be inspected without leaving the general comparison; a deliberate double-click opens its inner ladder. The person can add more tasks from Exercise itself or return any nested task to the general ladder without losing it.

**Successful outcome:** The root ladder stays small enough to compare, nested ladders contain meaningful peers, and the person can explain both where a task appears and what completing it will do.

**Example:** The root compares Company, Exercise, Family, and an independent “Call Mom” task. Company inherits High pressure while any actionable direct Company task has High pressure, then falls to the next-highest available value as that work leaves the Ladder. Company opens independent work obligations. Exercise opens activity choices; completing Walk asks whether today’s Exercise commitment should also be fulfilled.

**Availability:** Development experiment on macOS. Temporary group focus and a cross-group “What should I do now?” recommendation remain proposed.

### UC-06B — Let recurring work become timely without staying permanently urgent

**Situation:** A repeating responsibility matters differently across its cycle. Some tasks need little attention until the due date, while others should become progressively more pressing as that date approaches.

**Need:** Describe when a repeating task should gain attention so that it does not compete too early or remain artificially urgent after completion.

**Desired experience:** The person keeps stable Base values between occurrences and can choose either an on-due-date change or a gradual increase over a visible lead window for Importance, Urgency, and/or Pressure while creating, editing, or reviewing the task. Task Details explains that the saved value can be low now while the occurrence heats up later, and Task Ladder's read-only Now view explains an adjusted task with its due timing without silently rewriting Base. Completing the current occurrence advances its due date and normally returns the task to Base until the next configured window begins.

**Successful outcome:** The task becomes prominent at the right time, falls back predictably after the occurrence is resolved, and never requires the person to keep manually raising and lowering its values.

**Example:** “Put out recycling” stays low until its Tuesday due date, then changes at once. “Prepare monthly report” begins increasing three days before month-end, reaches its highest urgency on the due date, and returns to its normal level after completion.

**Evidence:** User-described need on 2026-08-16; user clarified on 2026-08-18 that the option should be visible in Task Details, Edit Task, and Add Task as well as Task Ladder. The selected curves, lead-window control, affected dimensions, and Base/Now mental model remain product assumptions to validate through use.

**Availability:** Development experiment on iOS and macOS for repeating Due routines.

### UC-07 — Keep someday or hidden work without daily noise

**Situation:** Some work is worth keeping but should not compete with everyday priorities.

**Need:** Move it off the radar while retaining searchability, context, and a return path.

**Desired experience:** Pausing, archiving, backlog organization, and visibility rules have distinct meanings. The item is not lost, completed, or silently rescheduled. Configuring Flag behavior stays progressive: each Flag shows only the rules already attached to it, `Add Rule` lists the remaining behaviors, and every attached rule can be removed in place.

**Successful outcome:** Everyday views remain manageable and deferred work can be recovered deliberately.

**Example:** A future home-renovation idea moves to Backlog and can later return to normal task lists. Its Backlog Flag shows only its chosen task-list rule instead of every behavior Routina supports.

**Current limitation:** The dedicated Mac Backlog has no unsectioned explicit destination. The person must first discover the separate Backlog window and create a section before Home's `Move to` menu or a task form's `Path` menu offers `Backlog › <section>`. Those menus do not explain the missing prerequisite when no Backlog section exists, and the beta Board's separately named backlog can add ambiguity.

**Evidence:** User feedback and supplied macOS screenshots on 2026-08-17 confirmed that the expected Backlog destinations were absent when the catalog contained only ordinary Radar sections.

**Availability:** Mixed; pause and archive are broadly available, while the dedicated Backlog workspace is on macOS.

## Plan and Act

### UC-08 — Build a realistic day plan

**Situation:** The person wants to combine fixed commitments, flexible tasks, routines, and available time.

**Need:** Turn intention into a visual day without changing every task into a deadline.

**Desired experience:** The Planner distinguishes fixed schedule, all-day intent, date-only planning, and flexible work. Items can be placed, moved, reviewed, or removed from the plan while retaining their original task meaning. Editing a task's fixed scheduled time immediately moves its automatically generated block, while a block the person deliberately moved or resized remains where they placed it. Each timed placement appears once; synchronization must not multiply one block into several overlapping copies. On macOS, day columns become narrower while they remain readable: a constrained block card preserves its original emoji/title/time positions; when width is tight it protects the title first, then adds the time or range, and then the emoji or status icon whenever each additional field fits. The range control never offers Week or 3 Days when the current width cannot render that choice. A tight or visually crowded header keeps its current view choices available through compact menus and shows `Go to date` as a calendar icon instead of ellipsized date text. When loaded data adds the Planner Focus control in Calendar, the date control collapses to that icon independently so the remaining choices can stay expanded if they fit.

**Successful outcome:** The person can see whether the day fits and adjust before committing attention.

**Example:** A 10:00 appointment stays fixed, “write outline” is placed in a 45-minute block, and “buy groceries” remains an all-day intention. Narrowing the Mac window changes the range selector into a menu; if only Day and 3 Days fit, Week is absent until the window widens again.

**Availability:** Production on macOS. Compact-platform planning routes may differ.

### UC-09 — Focus on chosen work

**Situation:** The person has selected a task and wants a bounded period of attention.

**Need:** Start a focus session with enough context and optional distraction protection.

**Desired experience:** The person can choose the task and duration, see active progress, pause or finish appropriately, and understand how the session will appear in history. On Mac, pressing Focus opens one sheet where duration and work attribution can be reviewed together; the latest attributed duration and an available latest tag are restored so a common choice can be repeated without rebuilding it. Blocking is offered only where the current platform can support it.

The last duration selected in that sheet is shown as Last choice and selected by default the next time it opens. Attributed Focus history remains the fallback for an existing installation that has no saved picker choice.

**Successful outcome:** The session supports attention without making later history ambiguous.

**Example:** Start 25 minutes on “Draft proposal,” block selected Mac apps, pause for an interruption, then resume and finish. Later, open Mac Focus after a count-up `#HSE` session and find `Count up · #HSE` ready to repeat or change in the same sheet.

**Availability:** Mixed by platform and protection capability.

## Record and Correct Reality

### UC-10 — Record what actually happened

**Situation:** A task was completed, missed, canceled, or finished at a different time than planned.

**Need:** Keep an honest record without rewriting the original plan.

**Desired experience:** Outcomes are distinct, the relevant occurrence is clear, and late entry or correction is possible where the meaning remains unambiguous. An assumption never looks identical to a confirmed completion. On Mac, a completed tag Focus block can be corrected in context from Calendar `Schedule`, with its Focus history and calendar evidence staying aligned.

**Successful outcome:** Timeline, Planner, and Stats tell a consistent story.

**Example:** A 09:00 routine is completed at 10:15 and logged against the 09:00 occurrence; yesterday's missed occurrence remains separately resolvable. A recorded `#Admin` Focus block that began at the wrong time can be opened from the Mac calendar and corrected without turning it into task activity.

**Availability:** Production.

### UC-11 — Add context that explains the day

**Situation:** Work alone does not explain the person's time or capacity.

**Need:** Record relevant context such as sleep, time away, a note, an event, an emotion, or a place visit without pretending it is a task.

**Desired experience:** Each record keeps its own meaning and appears in a coherent personal history. Optional context features do not complicate the core task experience when unavailable or disabled, including by leaving unavailable choices in creation or history filters. On iOS, disabling Sleep or its shake shortcut means a physical shake cannot open or complete a Sleep-mode start.

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

**Desired experience:** Stats uses the same selected date boundaries across reports, hides empty or unavailable reports, distinguishes recorded from assumed activity, counts synchronized copies of one focus session only once, and lets the person customize what matters. Time charts use the available width on each device and keep date axes sparse, complete, and readable instead of truncating labels or compressing the plot into unused space.

**Successful outcome:** The person can scan the period and identify a useful pattern without decoding overlapping labels, overlooking a compressed chart, or mistaking an estimate or incomplete dataset for certainty.

**Example:** Compare focus time and completed work this month, while assumed routine completions remain visibly separate from recorded completions.

**Availability:** Production for core reports; optional reports vary by platform, data, permission, and feature gate.

### UC-14 — Change the system as life changes

**Situation:** A routine, priority, schedule, or organizational structure no longer fits.

**Need:** Adjust it without losing history or creating duplicate records.

**Desired experience:** Editing affects future behavior in a previewable way. Pausing, archiving, restoring, reorganizing, and changing cadence preserve past meaning. Risky changes provide confirmation or recovery. Behavior-bearing Flags already assigned to a task remain visible and editable when Edit Task opens, even when the task has no organizational tags. Task Details stays focused on information already attached to the task instead of ending with a wide card whose only purpose is to add fields. Full Edit and the smaller `Add a detail` action stay together in the header: Edit remains direct, while the adjacent chooser opens as an anchored popover on Mac and a sheet on iOS. Secondary maintenance actions such as sharing a task link, canceling an eligible todo, or deleting the task remain in the familiar overflow rather than being mixed with editing. Empty Linked Tasks stay out of the default details; the person can start a relationship from `Add a detail`, after which the linked-task section becomes visible. On iOS Task Details, the task name and completion path stay ahead of secondary Calendar review. Today is not repeated as selected context, while choosing another day makes the action target explicit as `Viewing`. Saved one-off reminders are visible directly in Task Details with their date and time, so the person can verify notification timing without opening Edit Task. Importance, Urgency, Pressure, and Thinking needed stay together in the header in a compact adaptive order that remains comfortably tappable and stacks for larger accessibility text. Simple completion does not acquire empty card chrome. While the full task name remains visible in the header, the navigation bar does not repeat or truncate it; after scrolling removes that full title, a text-only navigation title appears without spending space on the emoji, and disappears again when the full title returns. Completion-creating actions use the same green semantic cue on iOS and Mac, while undoing or stopping uses orange; labels and icons keep the meaning accessible without relying on color alone.

**Mac task-detail refinement:** Done and its secondary task-action overflow read as one lifecycle family through a joined control, while the green or orange Done segment remains clearly primary and the neutral `⋮` segment stays independently clickable.

**Successful outcome:** Routina adapts with the person rather than forcing a restart.

**Example:** A weekly routine becomes biweekly after completion while its earlier weekly history remains intact.

**Evidence:** User-described need and interaction preferences on 2026-08-21.

**Availability:** Production on iOS and macOS; exact editing choices depend on item type.

## Trust and Continuity

### UC-15 — Continue safely across devices

**Situation:** The person captures on one device and later plans or reviews on another, starts using Routina without an Apple Account, or signs out after previously synchronizing.

**Need:** Trust that personal data and durable preferences remain coherent, and understand which data is only on this device, which data reached iCloud, and which Apple Account owns the cloud copy.

**Desired experience:** Synchronization is unobtrusive, conflicts do not silently discard history, and manual refresh reports only what it can verify. Account availability is explicit before a cloud action: Routina does not describe local records as synchronized while the person is signed out, and an account transition does not silently discard, expose, upload, or merge one account's data into another account. A long first refresh makes its continuing progress understandable with visible activity and an exact received-item count instead of treating elapsed time alone as failure or inventing a percentage, while later refreshes normally check only recent changes. Every manual refresh still reaches a bounded verified success or an actionable failure; on failure, existing local data stays available while Routina explains whether to check the connection, iCloud sign-in, or service availability and offers a retry. Task relationships arrive with their tasks, so a prerequisite created on Mac produces the same Linked Tasks content and effective Blocked state on iOS. Platform-specific layouts preserve the same product concepts. On iOS, the task calendar stays collapsed until it is useful, and each task remembers whether the person left its calendar expanded or collapsed when Task Details is reopened.

**Successful outcome:** The person continues the same task or review without reconstructing work.

**Example:** Link a task to an unfinished prerequisite on Mac, then see the same relationship and Blocked state on iPhone after synchronization. If a deliberate refresh cannot reach iCloud, continue using the local task list, check the connection or iCloud account, and retry instead of waiting on an endless spinner. If the person signs out or changes accounts, explain the status and the effect on both local and cloud copies before any merge or removal.

**Availability:** Local use is production; cross-device continuity requires iCloud to be configured and an Apple Account to be available. The signed-out and account-transition safeguards described above are intended behavior but are not fully implemented or device-verified yet.

### UC-16 — Back up, recover, or reset personal data safely

**Situation:** The person is changing devices, troubleshooting synchronization, or considering a destructive reset.

**Need:** Protect personal history before taking a risky action.

**Desired experience:** Backup and restore are complete and understandable. Destructive operations require a recent backup and device-owner authentication. Diagnostics explain the build and sync state without copying personal content.

**Successful outcome:** The person can recover data or proceed with an informed reset without an avoidable loss.

**Example:** Before resetting cloud data, Routina requires a recent export and fresh authentication.

**Availability:** Production.

### UC-17 — Ask what an unfamiliar Routina feature means

**Situation:** A person encounters a Routina workspace, label, number, or distinction they do not understand and wants an answer in the language they would naturally use.

**Need:** Understand what the feature is for, what the visible information means, and what an action would or would not change without searching technical project documentation.

**Desired experience:** After connecting an MCP-compatible AI client, the person can ask questions such as “What is Task Ladder?”, “What are the numbers above Calendar day columns?”, or “What is the difference between Availability and Schedule?” The answer comes from curated Routina help, states meaningful platform or availability limits, distinguishes similarly named concepts, and does not require personal task access. AI Connections shows how to connect, offers copyable questions, separates product help from personal-task access, states that every tool is read-only, and provides recovery when setup or shared task data is unavailable.

**Successful outcome:** The person can interpret Routina and decide what to do next without guessing, exposing personal tasks just to obtain product help, or receiving an answer based on a generic productivity app.

**Example:** In macOS Planner Calendar, the person asks what the number above Tuesday means and learns that it combines visible Planned tasks, Assumed done, and Dones for that day; selecting it opens the breakdown, and current Calendar filters can change the number.

**Evidence:** User-described need and examples on 2026-08-18.

**Availability:** Production on macOS through the local MCP connection and its AI Connections guide. The initial help catalog is curated rather than exhaustive.

## Coverage Gaps to Validate

The catalog reflects the current product direction, but these questions still need direct user evidence:

- Which moment causes the most friction: capture, choosing, planning, or correcting history?
- Do people understand the distinction between availability, planning, deadline, reminder, and scheduled time without explanation?
- Which review patterns lead to a useful decision rather than passive dashboard viewing?
- Which contextual records are valuable enough to promote from development experiments into production?
- How much cross-platform consistency do people expect, and where do they prefer platform-specific workflows?
- Which recovery actions are difficult to discover after an item is hidden, paused, archived, or moved to Backlog?
