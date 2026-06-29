# Tasks Current Behavior

This page summarizes active task, todo, routine, checklist, and Home-list behavior. Decision records explain why these rules exist.

## Key Decisions

- [0045](../decisions/0045-split-routine-schedule-behavior-and-format.md)
- [0177](../decisions/0177-separate-interval-and-calendar-repeat-controls.md)
- [0197](../decisions/0197-separate-todo-date-and-time-availability.md)
- [0199](../decisions/0199-support-multiday-routine-start-flow.md)
- [0200](../decisions/0200-support-task-planned-dates.md)
- [0202](../decisions/0202-nest-daily-routines-under-mac-plan-today.md)
- [0204](../decisions/0204-avoid-duplicate-daily-repeat-choices.md)
- [0240](../decisions/0240-keep-checklist-runout-item-actions-item-scoped.md)
- [0246](../decisions/0246-show-multiday-ongoing-range.md)
- [0247](../decisions/0247-make-mac-daily-routine-grouping-optional.md)
- [0249](../decisions/0249-reset-daily-checklist-progress.md)
- [0252](../decisions/0252-stabilize-home-task-list-presentation-identity.md)
- [0253](../decisions/0253-guard-checklist-detail-mutations-through-reloads.md)
- [0259](../decisions/0259-allow-daily-checklist-auto-assumed-completion.md)
- [0260](../decisions/0260-hide-assumed-done-tasks-by-default.md)
- [0270](../decisions/0270-normalize-checklist-item-intervals.md)
- [0275](../decisions/0275-hide-places-behind-beta-toggle.md)
- [0284](../decisions/0284-hide-filter-query-sections-behind-beta-toggle.md)
- [0281](../decisions/0281-collapse-mac-future-tasks.md)
- [0283](../decisions/0283-preserve-mac-future-inner-sections.md)
- [0285](../decisions/0285-clarify-mac-sidebar-section-surfaces.md)
- [0287](../decisions/0287-remove-deleted-task-blocks-from-planner.md)
- [0290](../decisions/0290-limit-free-active-tasks-behind-subscription.md)
- [0293](../decisions/0293-add-settings-unlimited-task-override-while-products-unavailable.md)
- [0300](../decisions/0300-show-plan-to-do-tasks-in-planner-day-agenda.md)
- [0312](../decisions/0312-move-mac-task-timeline-filter-entry-to-toolbar.md)
- [0314](../decisions/0314-remove-status-grouping-and-collapse-deadline-groups.md)

## Current Contract

- Todos and routines share the task model, but their timing semantics are different.
- Free Routina allows up to 10 active tasks. Creating another active task requires an unlimited-task entitlement from a subscription or lifetime purchase; existing tasks are preserved even if the account already has more than 10 active tasks. Settings -> Support & About -> Purchases can temporarily unlock unlimited task creation while StoreKit products are unavailable; production defaults this override off.
- Active-task counting includes todos and routines that are not paused, snoozed, archived, done, or canceled.
- Todo availability has independent date and time axes. Date bounds, time windows, deadlines, reminders, and planned dates are separate concepts.
- Planned dates are date-only Home-list planning hints for todos and non-daily routines. They are not availability, deadline, reminder, completion history, or stored Planner blocks. Planner day agendas surface active date-only planned tasks for the selected day.
- Deleting a task also removes persisted task-backed Planner blocks for that task so deleted work does not remain on the calendar.
- Task Detail calendar overdue markers run only while an overdue task is unresolved. If a completion, cancellation, or missed log resolves the task, later days stop showing as overdue.
- Daily routines already belong to the daily routine area and do not expose stored planned-date controls.
- Home `Today` includes active unpinned tasks planned for the current day, plus weekly/month-day calendar routines whose configured occurrence is today. A calendar routine with a canceled occurrence for today is not shown in the today plan. Rolling interval routines such as `Every 7 days` stay in the normal due/status sections unless explicitly planned.
- On Mac, daily routines are shown inside `Today`. By default they visually merge into the today list; Settings can restore a nested `Daily Routines` group.
- On Mac, `Today` and `Future` use full-bleed section surfaces for their headers and expanded content so their rows visibly belong to those sections. The `Today` and `Future` top-level surfaces use square horizontal edges without colored left or right borders. Mac sidebar task cards keep a small gap between rows.
- Home task-list grouping offers `None`, `Deadline Date`, and `Tags`; legacy saved `Status` grouping preferences normalize to `Deadline Date`.
- On Mac, normal active tasks outside `Today` are grouped under a collapsed-by-default `Future` section. Existing deadline, tag, and ungrouped inner organization and manual ordering are preserved inside `Future`; deadline-date groups and tag groups keep their own collapsible section behavior, and tag groups keep their color treatment.
- Routines separate schedule behavior from format. Due/Gentle controls pressure and status; Interval/Calendar controls cadence; Standard/Checklist controls finish behavior.
- Adding checklist items to a routine that previously had none promotes Standard completion to Checklist completion when no sequential steps would be discarded. Existing Standard routines that already carry checklist items remain editable as legacy optional checklist data.
- Auto-assume done is opt-in for daily Standard routines without steps/checklists and daily Checklist-completion routines in both Due and Gentle styles. Todos, checklist runout routines, Standard routines with optional checklist items, routines with steps, and non-daily cadences do not qualify.
- Calendar repeats offer weekday and month-day choices. Interval repeats own the single daily-repeat path.
- Multi-day routines use a `Start` -> in-progress -> `Stop` lifecycle. Their detail calendar shows an ongoing range while active and a completed span after stopping.
- Checklist runout item actions are item-scoped. Completing all currently due items records routine completion.
- Checklist item intervals are stored as meaningful cadence only for checklist runout routines. Checklist-completion routines and optional checklist data normalize item intervals to a neutral one-day value.
- Daily checklist-completion progress lasts for the current day only. Tomorrow starts unchecked unless the routine was completed and recorded in history.
- Daily Checklist-completion routines with auto-assume done use day-level assumption only; assumed completion does not fake completed checklist item IDs, and current-day partial checklist progress suppresses assumed presentation until the routine is fully completed or progress is cleared.
- Home task filters hide assumed-done rows by default; users can turn on `Show assumed done` in `All` or `Routines` views to review, confirm, or correct assumed days.
- On Mac, the Home toolbar filter button beside search opens `Both`, `Task List`, and `Timeline` filters in one segmented detail screen. Tags and importance/urgency live under `Both` and apply to both task-list and Timeline filtering. Task and Timeline sidebars no longer render their own filter icon buttons, but active task filters can still show summaries and clear actions in the sidebar.
- Home task filter Query sections are hidden by default behind Support & About -> Beta Experiments -> `Show filter query sections`; existing advanced query state remains compatible and still appears in active filter summaries when nonempty.
- Home status filters offer `Done Today` only for `All` and `Routines`; Todos use Timeline for completed work instead of keeping completed rows in the active task list.
- Once a checklist-completion routine is completed for a selected day, its checklist rows present as checked and read-only from selected-day completion evidence, even though in-progress checklist IDs are cleared after the final item. The toolbar Undo action reopens/removes the completed day without flashing stale completed checklist state back into the rows.
- Selected checklist item mutations keep their post-action detail state through stale Home reloads, including final completion after item-progress IDs reset.
- Optional checklists attached to ordinary tasks can block manual completion until all required items are checked.
- Task place sections, linked-place badges, and place-based task filters are hidden while the Places beta setting is off.
- Home task lists derive visible sections from one stable presentation model. Each task ID appears in at most one row per presentation, and section identity is based on durable keys rather than visible section titles.
