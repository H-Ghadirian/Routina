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

**Desired experience:** The shortest path asks for a meaningful title and confirms the save. Common natural-language dates and times are recognized when typed with the title, including a weekday plus day and month followed by a 24-hour time. An unqualified one-off date/time means when the task is available, while `due` or `by` explicitly means a deadline. On Mac, the global `+` menu keeps `Add New Task` beside Focus and shows Control-Option-Command-T for the direct keyboard route, so capture stays discoverable even though `+` now represents more than creation. On iOS, recognized one-off availability is visible as an `Available` detail before saving so the person can verify the date and time. Exact availability offers an optional reminder choice before saving and never silently creates one; using that reminder menu or its custom date picker keeps the attached Quick Add preview open until the person finishes or deliberately dismisses it. Pasting only a web link immediately attaches the link and proposes an editable title; when safe public metadata is available, the proposal becomes page-specific without delaying capture or overwriting a user edit. Continuing to compose the same Quick Add query—such as typing another character or adding a tag—preserves an edited preview title, resolved link metadata, and the selected reminder instead of treating each keystroke as a new task. Once Detected details appears, its rectangle stays spatially stable while typing and updates its contents in place; a partial unparsable value shows an updating state instead of making the whole editor disappear. Dates, recurrence, duration, tags, links, notes, and other details can be added when useful. A longer thought can open the full editor without retyping the title. Task count never blocks capture or redirects the person into a purchase flow.

**Successful outcome:** The person trusts that the item is saved, regardless of how many other tasks they keep, and can return to what they were doing.

**Example:** “Book dentist appointment” is captured immediately and can be refined later. “Physiotherapist Tuesday, 25 August 15:00” is captured as a task named “Physiotherapist,” available on that date at 15:00, with a visible choice of no reminder, one or two hours before, one day before, or a custom reminder; appending `#health` keeps that choice. Pasting a YouTube URL creates a linked task with an editable `Watch YouTube video` fallback and, when metadata resolves first, a title such as `Watch: Better Mobility`; appending `#watch` keeps the edited title without fetching the same URL again.

**Evidence:** User-reported capture failure on 2026-08-20. Refined by user-provided Mac toolbar and workspace-menu screenshots on 2026-08-27 requesting one `+` menu for Add New Task and Focus with visible shortcuts.

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

**Desired experience:** Today, planned work, recurring responsibilities, future work, and intentionally hidden or backlogged work have understandable places. Important context is visible without opening every item. On iOS, Home ends with Backlog, Timeline, and Task Ladder rows so deferred work, history, and ranked comparison remain reachable without replacing a bottom tab; the rows remain below the creation action even when Home has no tasks and stay out of the dedicated Search results. In the Mac main task list, the title gets the complete first line; people who value the full wording of long task names over uniform row height can enable multiline titles in Task List appearance. Status, planning labels, Tags, behavior Flags, and linked Goals always follow the complete title block so a badge never shortens the task's primary identifier. A task with an unfinished linked prerequisite reads as Blocked in the Home task list and wherever Task Details summarizes its effective state, never simultaneously as To Do, Ready, or In Progress; resolving the prerequisite restores the person's earlier workflow state without rewriting its history. Repeating task chains advance one completion at a time: finishing a prerequisite unlocks the dependent until that dependent finishes, even if the prerequisite immediately recurs or is paused to leave the active list. Optional grouping and filters reduce noise without deleting anything, and compact filter screens name each choice once instead of making the person scan repeated headings. On iOS, Priority groups the related choices; in the Mac Stats sidebar, Importance and Urgency appear as separate filter sections. In both places they remain independently adjustable, so changing one judgment never requires reselecting the other. Choosing filter tags feels like choosing tags while editing a task: one searchable plus/check list keeps each tag in one place, while the filter-only Show/Hide and All/Any choices remain explicit. After returning to Filters, the Filter tags row shows every active tag and grows to fit rather than hiding selections behind truncation or a count. On Mac, Shared Flag filtering follows that same compact searchable pattern rather than exposing or duplicating the full Flag catalog in Task List, Timeline, and Calendar: one edit action opens a combined Include/Exclude picker, chosen Flags remain visible outside it as removable summaries, and each multi-Flag rule exposes its own All/Any choice while that side is being edited. Include is a deliberate way to inspect normally hidden tasks, while Exclude remains the final veto when rules overlap.

On Mac, `Shared` offers every Task Ladder value as an independent cross-surface filter and uses the current values the person sees in Task Ladder. The scope explains that it applies to task-backed Task List, Timeline, and Calendar rows, while active dots keep filters in the other scopes discoverable. Timeline Type and Status remain independently adjustable, so choosing one never resets the other. Shared Tags stays calm when the catalog is large: one edit action opens a combined Include/Exclude searchable popover, selected rules stay visible as removable summaries outside it, and deliberate browse keeps selected tags pinned with bounded suggestions. The Tag editor sits in a titled teal panel, while the equivalent Flag editor sits in a titled orange panel, so each family is visually clear without repeating two large action rows. In the narrow companion pane, a single-choice filter remains segmented when its choices fit one line and becomes one compact menu picker when segments would wrap. Shared Task Ladder and Task List menu rows place the title leading and the value trailing on one line, and every picker uses the same width so both edges stay aligned as selections change. Fullscreen filter editing keeps the controls at a readable centered width and uses that width for full-width, single-row choices whenever they fit. Task List puts its three visibility switches before Task type and uses the same left-aligned text, right-aligned switch, and full-row interaction as Appearance, so the card begins with the immediate show/hide choices and scans as one coherent form. Stats retains its own compact collapsible Tags interaction instead of repeating the full catalog as include, suggestion, and exclude chip clouds.

**Successful outcome:** The person can identify a useful next action without first reorganizing the whole system.

**Example:** Today's planned call and available daily routine are visible; next month's renewal stays in Future. A long `[iOS] Replace ProductSliderItem…` title uses the whole first line while `#HSE` and `In Progress` share the line below; enabling Multiline Titles reveals the title's remaining words above those labels. In a repeating release chain, “Release Candidate” shows Blocked until “Run Test.io” is completed. It stays unlocked when “Run Test.io” recurs or is paused, then the next “Release Candidate” pass waits for the next Test.io completion.

**Availability:** Production, with richer organization on macOS.

**Evidence:** User-requested Mac filter redesign and Stats follow-up on 2026-08-24. User feedback with a supplied Mac main-task-list image on 2026-08-25 established that the title should own the first line and secondary labels should move below it, then requested an optional multiline title layout in that list's Appearance screen. User feedback on 2026-08-26 requested Backlog, Timeline, and Task Ladder as the final iOS Home rows before any tab-bar changes. User-supplied fullscreen Mac Filter images on 2026-08-27 established that controls which fit on one line should not retain the companion pane's forced multiline layout, follow-up Appearance images established that title/subtitle labels and switches must form stable columns instead of drifting with each label's intrinsic width, Shared Tags feedback replaced its disclosure and empty states with direct Include/Exclude actions that reveal active rules inline, subsequent Flag-filter feedback first requested the same compact searchable interaction and then clarified that Flag filters belong once in Shared rather than in every surface. The same clarification kept Calendar's Assumed done layer toggle separate from the Auto Assume Done behavior Flag. Final companion-pane feedback explicitly replaced multiline Task Ladder and Task List segments with compact pickers while preserving fullscreen segments. Further Task List Filter and Appearance comparisons requested that visibility toggles move before Task type and directly reuse Appearance's left-label/right-switch rows, then that compact Task Ladder titles and menu pickers share one leading/trailing row. A final Shared screenshot requested that each Include/Exclude pair gain its own titled, color-backed Tags or Flags group, then follow-up feedback moved Include/Exclude selection and All/Any editing into one popover per group while retaining visible active-rule summaries. Final Task List feedback extended the Task Ladder's one-line title/picker pattern to every compact Task List menu and requested one stable picker width across both sections.

### UC-05 — Find an existing item quickly

**Situation:** The person remembers part of a task, tag, note, or recent activity but not where it is organized.

**Need:** Search without losing the surrounding workspace or accidentally creating a duplicate.

**Desired experience:** Search accepts typing immediately, returns understandable matches, and keeps clear recovery paths when filters or normal placement hide a known item. A broader query includes every eligible item that a more specific version of the same query can find, even when other matches already occupy normal task-list sections. On Mac, Planner, Backlog, and Task Ladder keep one predictable top search/create control while each workspace searches its own organization. Planner keeps its calendar-location behavior. Backlog preserves matching super-section and subsection context and labels matches elsewhere as outside Backlog. Clicking the result summary opens Task Details; an active organizational match can be shown in Planner, while a completed one-off match can be shown in Timeline where its completion evidence lives, and either can be deliberately moved. Task Ladder keeps ranked context, reports nested paths, locates a selected match without flattening the ladder, and explains when a match is excluded. Creating from a no-result query is offered only when no existing task matches globally; Backlog creation names each destination as `Backlog › <section>` and calls the normal non-Backlog destination `Main task list`.

**Successful outcome:** The person opens the intended item or confidently creates a new one.

**Example:** Searching “dentist” finds the task even though it is not in today's section. From Backlog, searching “Read mail” can show `Radar › Future` without pretending the task is backlogged; `Show in Planner` preserves the query and reveals its planning context. A completed “Watch movie” result instead offers `Show in Timeline`, while clicking its summary opens the task itself. On Mac, searching “watch” does not omit a known task that also appears for “watch m”. Searching a genuinely new phrase can seed a new task.

**Availability:** Production on iOS and macOS.

### UC-05a — Understand why a Settings search result matches

**Situation:** The person remembers a setting or behavior, but not which Settings category owns it.

**Need:** Search by the setting's meaning and understand the result before opening it.

**Desired experience:** Settings search matches both destination names and the user-facing controls inside them. A result names the matching control or behavior, so `hide` does not merely return `Flags`; it explains that Flags contains Hide from Task Lists, Hide from Calendar List, Hide from Timeline, and Hide from Task Ladder. Selecting the result opens the same destination and leaves its controls unchanged.

**Successful outcome:** The person knows why a category matched and can reach the relevant control without guessing.

**Example:** Searching `hide` returns `Flags` with the four hide behaviors shown beneath it. Searching `backup` can return `iCloud & Backup` with its sync, export, import, or backup concepts.

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

**Search requirement:** iOS Task Ladder owns a native local search, while the persistent Mac search/create control finds Task Ladder tasks without squeezing the Ladder into Planner's sidebar. A nested match reports its group and current value, locating it preserves rank order, and a match excluded by lifecycle, Blocked state, a Flag, or an unfinished prerequisite remains visible with that reason.

**Desired experience:** Task Ladder is easy to find at the end of iOS Home and in the main Mac window's labeled workspace menu. Each route opens within its existing app hierarchy instead of creating a detached window. On Mac, that global workspace menu names the root once; the Ladder's own compact control bar shows the metric, direction, item count, group action, and refresh without repeating the workspace title or sort description, while a local title appears only after entering a nested ladder. Value-section headers name the value rather than restating read-only or sorting state already communicated by the controls. Its placement and completion meanings remain separate. A container-only group such as Company opens its own ladder but never completes. Each group value can be explicit, absent, or inherited from the highest value among its actionable direct tasks, so the general ladder reflects the group's current work without copying metadata. Editing an existing container keeps its name and emoji present, and changing only a metric remains saveable without re-entering its identity. A real repeating commitment such as Exercise can be activated as a Task Ladder group while it is created, deliberately edited, or organized in the Ladder, without losing its recurrence or history and even before it has children. Ordinary Task Details stays focused on broadly useful task information; changing an existing task's group role happens through Edit Task. When Exercise already has linked tasks, its nested ladder offers the eligible links as child suggestions rather than placing them automatically; the person can accept or reject each suggestion without changing or removing the link. It can then contain Walk, Gym, or Swim while each option independently does nothing to Exercise, asks whether it can complete Exercise, or completes Exercise automatically. A Mac click or iOS row activation shows task or container-group details, while Mac double-click or the explicit iOS inner-ladder button opens the ranked peers inside it. Mac keeps exactly the active row visibly selected as the person moves among groups and tasks, including while lazy rows are reused during scrolling. The person can add more tasks from Exercise itself or return any nested task to the general ladder without losing it.

**Successful outcome:** The root ladder stays small enough to compare, nested ladders contain meaningful peers, and the person can explain both where a task appears and what completing it will do.

**Example:** The root compares Company, Exercise, Family, and an independent “Call Mom” task. Company inherits High pressure while any actionable direct Company task has High pressure, then falls to the next-highest available value as that work leaves the Ladder. Company opens independent work obligations. Exercise opens activity choices; completing Walk asks whether today’s Exercise commitment should also be fulfilled.

**Availability:** Available on iOS and macOS, with group creation and placement management richer on macOS. Temporary group focus and a cross-group “What should I do now?” recommendation remain proposed.

**Evidence:** User-reported first-edit failure with supplied macOS images on 2026-08-26 established that an existing container group's identity must load with its metric choices and that a metric-only change must remain saveable. User-supplied Mac Task Ladder images on 2026-08-26 established that changing the selected group must not leave selection tint on other lazy rows, then showed that the root workspace title, sort direction, group terminology, and read-only section meaning were repeated across adjacent header layers and should be stated once.

### UC-06B — Let recurring work become timely without staying permanently urgent

**Situation:** A repeating responsibility matters differently across its cycle. Some tasks need little attention until the due date, while others should become progressively more pressing as that date approaches.

**Need:** Describe when a repeating task should gain attention so that it does not compete too early or remain artificially urgent after completion.

**Desired experience:** The person defines each metric as one readable sentence: its value after completion, whether it changes, when it changes, its higher target, and the relevant number of days. Importance can jump only on the due date, Urgency can rise gradually over its own lead window, and Pressure can stay low through the due date and rise only while overdue. iOS and macOS use the same menu-picker language without segmented controls, shared timing, enable toggles, metric checkboxes, or steppers. A before-due window never exceeds an After done recurrence interval, so a task that repeats every two days cannot confusingly claim to rise for seven days before its next due date. The four Task Ladder values stay together in Add/Edit; one-time tasks do not mention temporal behavior, and an ineligible repeating task names the concrete Behavior & Schedule choice needed. Returning every changing metric to `does not change` turns the rule off. For an ordinary task, Task Details keeps the four values directly editable. Once Changes over time is configured, Task Details becomes a review surface: it identifies the After done values, distinguishes the derived Now values, lists each independent timing policy, keeps Thinking fixed and read-only with the group, and directs changes through Edit Task so the source values and rules are changed together. Task Ladder's read-only Now view likewise explains an adjusted task without silently rewriting After done values.

**Successful outcome:** The task becomes prominent at the right time, falls back predictably after the occurrence is resolved, and never requires the person to keep manually raising and lowering its values.

**Example:** “Prepare monthly report” resets to Low Importance, Low Urgency, and Low Pressure after completion. Importance changes to High only on the due date; Urgency rises to Immediate over five days before due; Pressure remains Low on the due date, then rises one level every two overdue days until High or completion.

**Evidence:** User-described need on 2026-08-16; clarified on 2026-08-18 that resulting values must be understandable from Task Details, Edit Task, Add Task, and Task Ladder; refined on 2026-08-23 around editing boundaries and eligibility; and revised on 2026-08-24 after a two-day repeat exposed that one shared seven-day lead window had no coherent after-completion meaning. The user explicitly requested one independently configurable picker sentence per metric and clear after-done, due-date, transition, and overdue meanings.

**Availability:** Development experiment on iOS and macOS for repeating Due routines.

### UC-07 — Keep someday or hidden work without daily noise

**Situation:** Some work is worth keeping but should not compete with everyday priorities.

**Need:** Move it off the radar while retaining searchability, context, and a return path.

**Search requirement:** iOS Backlog owns a native local search. Mac Backlog keeps its resizable full-workspace split view while using the same persistent top search/create control as Planner. A matching task elsewhere is identified with its real location and can be opened directly without being counted as backlogged or recreated as a duplicate. Mac can additionally show it in Planner when it is still organizational work, show a completed one-off in Timeline, or deliberately move it into Backlog. A genuinely new task requires an explicit Backlog section or a deliberate Main task list choice.

**Desired experience:** Pausing, archiving, backlog organization, and visibility rules have distinct meanings. Backlog is reachable from the end of iOS Home and as a labeled, full-size workspace in the main Mac window rather than a detached window or hidden app-menu command. Both platforms show the same understandable super-section plus one-level subsection organization, keep deliberately created empty sections visible, and let each level collapse without hiding search matches. Collapsed sections stay collapsed while the person leaves and returns; search expansion never overwrites those choices. Opening Add Task on Mac is a reversible detour: Cancel returns to the Backlog workspace instead of redirecting the person to Planner. A task's `Move to > Backlog` menu keeps all Backlog destinations behind one nested menu and can create a new Backlog super section at the point of use, assigning the task that started the action; Settings remains available for preparing an empty catalog. In Mac Settings -> Sections, a `Main task list` / `Backlog` segmented picker makes the destination of each section obvious and keeps section creation and top-level ordering in the selected surface. Section names and automatic tag rules are independent per destination, so a concept such as `Health` can organize each surface without a misleading duplicate-name error or one surface blocking the other's rule. A tagged Backlog super section automatically gathers matching active tasks hidden from normal task lists even when they retain a Main task list path; that path is not overwritten and returns when the hiding Flag is removed. An explicit Backlog path remains stronger within Backlog, and ordinary tasks without the hiding behavior do not move into Backlog unexpectedly. On iOS, the person can open Task Details and move an explicitly backlogged task to Home from the compact list. The item is not lost, completed, or silently rescheduled. Configuring Flag behavior stays progressive: each Flag shows only the rules already attached to it, `Add Rule` lists the remaining behaviors, and every attached rule can be removed in place.

**Successful outcome:** Everyday views remain manageable and deferred work can be recovered deliberately.

**Example:** A future home-renovation idea moves to `Home › Renovation` in Backlog and can later return to normal task lists. Searching for “carpenter” reveals it in that hierarchy even when its section was collapsed. Its Backlog Flag shows only its chosen task-list rule instead of every behavior Routina supports.

**Current limitation:** Backlog has no unsectioned explicit destination. Mac task move menus can create-and-assign a new section, while Settings is required when the person wants to prepare an empty catalog. The iOS Backlog surface browses and searches the shared catalog but does not create sections inline. The task form's `Path` menu offers `Backlog › <section>` after a section exists, and the beta Board's separately named backlog can still add ambiguity.

**Evidence:** User feedback and supplied macOS screenshots on 2026-08-17 confirmed that the expected Backlog destinations were absent when the catalog contained only ordinary Radar sections. User feedback and supplied macOS screenshots on 2026-08-22 established the need to make Backlog, Task Ladder, and Settings easier to find while avoiding another competing drawer. Further feedback on 2026-08-22 established the need for sidebar-like Backlog super/subsections, one persistent search/create control across Planner, Backlog, and Task Ladder, truthful recovery when a Backlog query matches a task on the Radar, direct detail opening from outside-result rows, Timeline rather than Planner handoff for completed matches, and a clear Settings distinction between ordinary and Backlog section catalogs. User feedback on 2026-08-23 established that canceling Add Task from Backlog must return to Backlog rather than Planner, and supplied screenshots plus clarification established that Main task list and Backlog sections require independent automatic-tag rules. User feedback on 2026-08-26 established that Backlog disclosure choices must survive switching to another main-window workspace and back, then requested Backlog, Timeline, and Task Ladder as the final iOS Home rows.

**Availability:** Mixed; pause and archive are broadly available, while the integrated Backlog workspace is available on iOS and macOS with richer management on Mac.

## Plan and Act

### UC-08 — Build a realistic day plan

**Situation:** The person wants to combine fixed commitments, flexible tasks, routines, and available time.

**Need:** Turn intention into a visual day without changing every task into a deadline.

**Desired experience:** The Planner distinguishes fixed schedule, all-day intent, date-only planning, and flexible work. Items can be placed, moved, reviewed, or removed from the plan while retaining their original task meaning. Editing a task's fixed scheduled time immediately moves its automatically generated block, while a block the person deliberately moved or resized remains where they placed it. Each timed placement appears once; synchronization must not multiply one block into several overlapping copies. On macOS, day columns become narrower while they remain readable: a constrained block card preserves its original emoji/title/time positions; when width is tight it protects the title first, then adds the time or range, and then the emoji or status icon whenever each additional field fits. Calendar List calls recorded completion activity `Done` and lets the person independently expand or collapse every non-empty task section for each visible day while its count stays visible. A person can assign `Hide from Calendar List` to tracking or automatically assumed work that is useful elsewhere but not useful in this side-by-side review; the task then leaves Planned, Assumed done, Confirmed assumed done, and Done columns without losing its Schedule placement, focused day-sidebar access, assumptions, completions, history, or Stats. Removing the Flag restores it whenever the normal date and filter conditions match. Shared Include flags can temporarily recover that task for deliberate review without removing its behavior marker; Shared Exclude flags can temporarily suppress matching task-backed rows across Schedule, List, and the other Mac task surfaces. The separate Calendar Assumed done toggle remains a layer choice, not a Flag filter. The range control never offers Week or 3 Days when the current width cannot render that choice. Planner view, Calendar task view, and range stay compact as current-value controls until the person selects one; that control reveals its direct segments in place, pushes later controls right, and remains the only expanded choice until a selection collapses it or another choice opens. The selected Calendar/Timeline, Schedule/List, and preferred Day/3 Days/Week values remain the person's choices after switching away and after relaunching Routina; a narrow-window fallback does not replace the preferred range. A tight or visually crowded header shows `Go to date` as a calendar icon instead of ellipsized date text without changing that choice interaction.

**Successful outcome:** The person can see whether the day fits and adjust before committing attention.

**Example:** A 10:00 appointment stays fixed, “write outline” is placed in a 45-minute block, and “buy groceries” remains an all-day intention. An automatically assumed tracking task carries Hide from Calendar List, so it stays out of the `Assumed done` column while its assumption remains available elsewhere; selecting that Flag under Shared Include flags reveals it temporarily for review. The person can keep a busy day’s `Done` rows collapsed while retaining the completion count, then expand only that section to review it. Selecting Week expands the range control into Day / 3 Days / Week segments while Calendar and Schedule remain compact; if only Day and 3 Days fit, Week is absent until the window widens again.

**Evidence:** User-requested Calendar List wording and disclosure consistency on 2026-08-24. Refined by user-provided Planner and Task Detail screenshots on 2026-08-24 requesting the same one-at-a-time expanding segmented interaction for Calendar, Schedule, and Week. User feedback with a supplied Planner header image on 2026-08-26 established that the three selected values must survive returning to Planner and app relaunches. User feedback with a supplied Calendar List image on 2026-08-27 requested a task-level Flag that keeps automatically assumed work out of that list without removing its underlying evidence, then clarified that reusable Flag include/exclude filtering belongs in Shared while Calendar's Assumed done layer toggle remains separate.

**Availability:** Production on macOS. Compact-platform planning routes may differ.

### UC-09 — Focus on chosen work

**Situation:** The person has selected a task and wants a bounded period of attention.

**Need:** Start a focus session with enough context and optional distraction protection.

**Desired experience:** The person can choose the task and duration, see active progress, pause or finish appropriately, and understand how the session will appear in history. When an active timer appears at the top of iOS Home, its entire banner opens controls regardless of whether the timer belongs to a task, tag, plan, or sprint. The person can pause or resume it, finish and keep the focused time, or abandon it without completed history; task Focus also provides a direct route to its task. This remains true when the timer began on Mac and arrived through iCloud, so changing devices does not strand the active session. Finishing, editing, or deleting task Focus preserves it as separate Focus evidence and never silently changes Actual time; recording actual time is an explicit action. Any future conversion must let the person choose the intended occurrence and remain correct if the Focus record changes. While an active session must stay open so its controls remain available, its header does not show a chevron or clickable disclosure behavior until collapsing is possible again. In Mac one-off Task Details, Actual time and Focus remain related under Effort without turning the task view into two permanent editors: the collapsed card reports populated effort evidence, expanded rows show each value and action once, and Log time or Start focus opens a focused editor only when requested. Those transient popovers keep only the committing action because clicking outside already dismisses them without changing the task; a duplicate Cancel button should not compete with Log time or Start focus. Countdown reveals its duration there, Count up shows no duration it will ignore, and a running or blocked session replaces start actions without preventing manual Actual-time logging. Recent Focus sessions keep their duration and edit action together without repeated dashboard totals or a default block grid. Once the task has retained Focus history, Focus stays visible and available rather than offering a switch that can hide that evidence; deleting every retained session restores the optional choice. On Mac, Focus lives in the global `+` menu beside Add New Task instead of occupying the Planner header. Its Control-Option-Command-F shortcut is visible in that native menu, and choosing it opens one sheet where duration and work attribution can be reviewed together; the latest attributed duration and an available latest tag are restored so a common choice can be repeated without rebuilding it. An active timer is managed from the existing macOS timer/status menu rather than making the Planner header change shape. Blocking is offered only where the current platform can support it.

The Mac trigger presents the plus, `New` label, and chevron as one compact clickable control aligned with the adjacent workspace menu. Focus availability follows eligible work rather than whichever rows the current workspace happens to display, so filtering or placement cannot make the global action appear unavailable while a startable task still exists.

The last duration selected in that sheet is shown as Last choice and selected by default the next time it opens. Attributed Focus history remains the fallback for an existing installation that has no saved picker choice.

**Successful outcome:** The session supports attention without making later history ambiguous.

**Example:** Start 25 minutes on “Draft proposal” on Mac, then tap its banner on iPhone, pause for an interruption, resume, and finish. Later, open Mac Focus after a count-up `#HSE` session and find `Count up · #HSE` ready to repeat or change in the same sheet.

**Evidence:** User-reported Focus, time, and estimate confusion and explicit correction request on 2026-08-24. Refined by user feedback on 2026-08-25 that the active iOS Home timer appeared non-actionable and needed cross-device Pause/Resume, Finish, and Abandon controls. Refined again by user-provided Mac toolbar and workspace-menu screenshots on 2026-08-27 requesting Focus inside the global `+` menu with a visible keyboard shortcut, then by direct feedback that an unexpectedly disabled Focus row and the detached `+` trigger were unclear.

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

**Desired experience:** The Timeline presents clear outcomes and context in a stable order, supports filtering and date navigation, opens the source record for detail or correction, and offers only type filters whose features are currently available. A person can keep activity from behavior-heavy or private tasks out of the default history through a Flag rule, then deliberately reveal matching task activity without losing or changing the underlying record. On Mac this uses the same Shared Include/Exclude Flag rule as Task List and Calendar, with selected Flags visible as removable chips and no duplicate Flag catalog in Timeline; standalone Timeline records remain available because they do not carry task Flags.

**Successful outcome:** The person understands the period without relying on memory or combining several disconnected logs.

**Example:** Review yesterday to see completed work, a canceled routine, focus time, and a contextual note; select a hidden task's Flag when that quieter activity is relevant to the review.

**Availability:** Production, with available record types varying by feature gate.

### UC-13 — Learn from patterns without false precision

**Situation:** The person wants to know how work, focus, repeating tasks, or wellbeing changed over time.

**Need:** See meaningful summaries for a chosen period and understand their scope.

**Desired experience:** Stats clearly separates current General Stats from Date Range Stats, so changing the range never appears to affect values such as open One-time tasks or the current Repeating-task inventory. Done, Canceled, and Missed remain selected-period outcomes. Date-bound reports use the same selected boundaries, empty or unavailable reports stay hidden, and a one-day range does not render a trend chart for created tasks. Stats distinguishes recorded from assumed activity, counts synchronized copies of one focus session only once, and lets the person customize what matters. Time charts use the available width on each device and keep date axes sparse, complete, and readable instead of truncating labels or compressing the plot into unused space. On Mac, the sidebar keeps Scope, Show, Time Range, Importance, and Urgency on compact single rows inside passive colored cards. Each current value is a native menu picker, so choosing a filter never expands its option list into the sidebar or moves the controls below it. Only Custom Range reveals additional fields because the person must choose two inclusive dates; Query, Tags, and Flags keep focused multi-value interactions.

**Successful outcome:** The person can scan the period and identify a useful pattern without decoding overlapping labels, overlooking a compressed chart, or mistaking an estimate or incomplete dataset for certainty.

**Example:** Open the Time Range menu, choose Month, and immediately scan the newly scoped reports without the sidebar changing height. For a project review, choose Custom and edit both inclusive dates directly below that row.

**Evidence:** Refined by user-provided Mac Stats and Planner screenshots on 2026-08-27, then revised by follow-up feedback that expanding single-choice segments added effort and sidebar movement without benefit. The same feedback requested inline menu pickers for all five single-choice filters. Related follow-up established Repeating/One-time wording, removal of the one-day created-task chart, and a clear general-versus-date-range split while keeping Missed period-scoped.

**Availability:** Production for core reports; optional reports vary by platform, data, permission, and feature gate.

### UC-14 — Change the system as life changes

Settings search should take the person directly to Flags, Tags, Sections, or iCloud & Backup without searching personal task content. Behavior-bearing built-in Flags remain visible and editable on tasks, while ordinary personal labels use Tags.

**Situation:** A routine, priority, schedule, or organizational structure no longer fits.

**Need:** Adjust it without losing history or creating duplicate records.

**Desired experience:** Editing affects future behavior in a previewable way. Pausing, archiving, restoring, reorganizing, and changing cadence preserve past meaning. Risky changes provide confirmation or recovery. Behavior-bearing Flags already assigned to a task remain visible and editable when Edit Task opens, even when the task has no organizational tags. Task Details stays focused on information already attached to the task instead of ending with a wide card whose only purpose is to add fields. Description, links, images, files, voice notes, and notes share one content area that names each present content type instead of repeating a generic Details heading; large images stay below the compact overview so they do not displace identity or primary actions. On Mac, assigned Tags and Flags share one compact metadata card while their separate headings and chip styles keep organizational labels distinct from behavior-bearing Flags; the groups use one row when their complete content fits and adapt to two labeled rows when it does not. Full Edit and the smaller `Add a detail` action stay together in the header: Edit remains direct, while the adjacent chooser opens as an anchored popover on Mac and a sheet on iOS. Each field-specific option depends on that field: in particular, Estimate remains available whenever the duration estimate is missing, even when Actual time, Story points, or Focus is already configured. Secondary maintenance actions such as sharing a task link, canceling an eligible todo, or deleting the task remain in the familiar overflow rather than being mixed with editing. Empty Linked Tasks stay out of the default details; the person can start a relationship from `Add a detail`, after which the linked-task section becomes visible. When several relationship meanings are available, the person sees one scalable grouped menu whose labels complete a sentence from the current task's perspective instead of a permanent wall of choices. Choosing another task does not silently create a behavioral link: Routina restates which task blocks or completes which and waits for `Add Relationship`. Relationship creation stays deliberate and manual instead of presenting AI guesses that the person must repeatedly reject. Existing relationships remain easy to scan, while one `Add` action keeps creating a new linked task and choosing an existing task available in the same focused flow on iOS and Mac. Add and Edit Task keep relationship choices draft-owned until Save, while Task Details confirms and persists an existing-task link directly. On iOS Task Details, the task name and completion path stay ahead of secondary Calendar review. Today is not repeated as selected context, while choosing another day makes the action target explicit as `Viewing`. An assumed day is identified by a compact status treatment rather than an instructional paragraph; the direct confirmation action and its adjacent routine-action menu make the available paths understandable, with Not today prioritized when it applies. Saved one-off reminders are visible directly in Task Details with their date and time, so the person can verify notification timing without opening Edit Task. Importance, Urgency, Pressure, and Thinking needed stay together in the header in a compact adaptive order that remains comfortably tappable and stacks for larger accessibility text. Optional iOS History reads as a compact activity list rather than a stack of glowing action cards: outcomes appear once, Gregorian and Persian dates have separate lines, duration appears only when recorded, and each row exposes corrections through a clear actions menu or a deliberate swipe reveal. Simple completion does not acquire empty card chrome. While the full task name remains visible in the header, the navigation bar does not repeat or truncate it; after scrolling removes that full title, a text-only navigation title appears without spending space on the emoji, and disappears again when the full title returns. Completion-creating actions use the same green semantic cue on iOS and Mac, while undoing or stopping uses orange; labels and icons keep the meaning accessible without relying on color alone.

**Task configuration refinement:** Add and Edit use a predictable three-part core: Behavior & Schedule for what the task does over time, Task Ladder values for the four independent judgments and their optional changes over time, and Organization for Path, Tags, Flags, and Task Ladder grouping. The person does not have to search several distant cards for related values, and Task Details can remain a compact review-and-action surface. A separate Effort group keeps Time estimate, Actual time, Story points, and Focus together because they describe related aspects of work, while compact semantic labels and field-specific actions make clear that planned duration, recorded duration, relative size, and attention-session tracking do not enable or overwrite one another. Optional values look like values that can be set or cleared; only Focus looks like an on/off capability.

**Mac task-detail refinement:** Done and its secondary task-action overflow read as one lifecycle family through a joined control, while the green or orange Done segment remains clearly primary and the neutral `⋮` segment stays independently clickable.

**Successful outcome:** Routina adapts with the person rather than forcing a restart.

**Example:** Link `Buy tickets` to `Walk in the Zoo` by choosing `is blocked by`; before saving, Routina states that Walk in the Zoo stays blocked until Buy tickets is completed. A task with a titled reference link and an explanatory screenshot shows `LINKS` and `IMAGE` together in one content card; a weekly routine can still become biweekly without losing its earlier weekly history.

**Evidence:** User-described need and interaction preferences on 2026-08-21, including direct feedback that duplicate Details sections and separated link/image content were confusing, that Jira's scalable relationship vocabulary was the intended reference for linked-task composition, and that repeated use produced mostly poor AI relationship suggestions that should be removed rather than presented without a reliable quality-control path. Refined by user feedback on 2026-08-23 that assumed-done instructional copy was excessive, completion and related routine actions should communicate their relationship through a compact inline control, and iOS Task Detail History was too noisy and difficult to scan or correct. Refined again on 2026-08-24: Focus, Time, Estimate, and Story points belong to Effort, but their combined toggle-based editor was confusing because related fields appeared behaviorally coupled.

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

**Example:** In macOS Planner Calendar, the person asks what the number above Tuesday means and learns that it combines visible Planned tasks, Assumed done, and Done activity for that day; selecting it opens the breakdown, and current Calendar filters can change the number.

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
