# Project Decision Log

This directory contains Routina's project decision records. These records are the source of truth for important choices that should guide future work.

## How to Use This Log

- Read this index and relevant decision records before making meaningful project changes.
- Add a new decision record when a change introduces or revises a long-term project decision.
- Prefer creating a new record that supersedes an older one instead of rewriting history.
- Move superseded records into `docs/decisions/superseded/` and update links so active records stay in the top-level decision directory.
- Keep records focused on the reason for a decision, the choice made, and the consequences.

Use decision records for architecture, conventions, data model, dependencies, product behavior, build setup, and other choices future contributors should preserve or understand. Tiny fixes, copy edits, and purely mechanical cleanup usually do not need a decision record.

## Merged Active Decision State

This section is the cleaned, category-level merge of the numbered records. The records below remain the source for rationale, tradeoffs, and implementation boundaries.

Priority rules:

1. Explicit `Supersedes` or `Superseded by` links win first.
2. If records overlap without an explicit link, prefer the later accepted record.
3. Older records remain historical context in `superseded/` and may still describe migration or compatibility fallbacks.

### Latest Conflict Priorities

These are ordered from newest resolver to oldest resolver.

- **[0183](0183-support-todo-availability-time-windows.md) refines [0182](0182-show-todo-all-day-as-availability.md) for todo availability:** Todo forms use the full Availability set: `Any time`, `All-day`, `At time`, and `Window`. One-off todo exact-time/window availability is stored on the one-day recurrence rule, while deadline and reminder remain separate.
- **[0182](0182-show-todo-all-day-as-availability.md) refines [0179](0179-make-all-day-an-availability-choice.md) for todo form controls:** Todo forms show Availability below the Routine/Todo picker; all-day remains independent from deadline controls. Superseded in part by [0183](0183-support-todo-availability-time-windows.md), which adds todo exact-time and window availability.
- **[0181](0181-allow-gentle-calendar-repeats.md) refines [0178](0178-make-recurrence-availability-independent.md) for Gentle cadence:** Due/Gentle controls overdue pressure, while Interval/Calendar controls cadence; Gentle routines can use calendar repeats and use the next calendar occurrence for gentle nudge timing.
- **[0180](0180-clarify-schedule-behavior-summary.md) refines [0046](0046-label-routine-schedule-behavior-as-due-and-gentle.md) for schedule behavior badge previews:** Routine forms show expected Due/Gentle row badges with one concise explanatory line, without repeating cadence or availability text in the preview.
- **[0179](0179-make-all-day-an-availability-choice.md) refines [0093](0093-support-all-day-routines.md) and [0178](0178-make-recurrence-availability-independent.md) for task form scheduling controls:** Routine all-day is presented as an Availability timing choice; routine Availability appears before repeat type/calendar pattern controls, while todo all-day remains an independent task property outside deadline controls.
- **[0178](0178-make-recurrence-availability-independent.md) refines [0009](0009-support-routine-time-ranges.md) and [0177](0177-separate-interval-and-calendar-repeat-controls.md) for recurrence availability:** Routine forms show `Availability` as an independent section for Due repeats and Gentle interval cadences; interval recurrence rules may store exact time or time ranges while the interval still determines the scheduled day.
- **[0177](0177-separate-interval-and-calendar-repeat-controls.md) refines recurrence form presentation:** Routine forms first choose whether a repeat is `Interval` or `Calendar`; calendar repeats then reveal `Daily`, `Weekday`, and `Month day` patterns. Stored recurrence kinds remain unchanged.
- **[0176](0176-nest-runout-under-checklist-cadence.md) refines [0175](0175-use-routine-finish-mode-for-checklist-creation.md) and [0045](0045-split-routine-schedule-behavior-and-format.md) for routine checklist creation:** Routine forms present Completion as Standard or Checklist only; Runout is a checklist cadence/timing choice inside the repeat cadence area, while stored schedule modes still preserve checklist and runout variants.
- **[0175](0175-use-routine-finish-mode-for-checklist-creation.md) refines [0045](0045-split-routine-schedule-behavior-and-format.md), [0069](0069-support-optional-task-checklists.md), and [0101](0101-treat-empty-checklists-as-optional-task-details.md) for routine checklists:** Empty standard routines no longer offer Checklist as an optional More Details reveal; choosing Checklist in Completion is the routine checklist creation path, while todos and existing routine checklist content remain supported.
- **[0174](0174-do-not-restore-mac-add-task-composer.md) refines [0074](0074-parse-mac-add-task-title.md) and [0076](0076-select-saved-home-items-after-creation.md) for Mac task creation:** Add Task is a transient Mac Home sidebar mode; it can be opened in-session, but temporary view-state persistence normalizes it to Routines so relaunch never restores a stale form navigator without form state.
- **[0173](0173-use-ios-new-tab-sheet.md) supersedes part of [0071](0071-move-ios-task-add-to-tab-bar.md) and [0073](0073-open-ios-home-actions-horizontally.md) for compact iOS capture actions:** The bottom-bar `Task` action is now `New`, and tapping it opens a compact action sheet with Event, Emotion, Note, Goal, Task, Check In, Away, and Going to sleep while Home keeps Home-specific controls such as filters.
- **[0172](0172-hide-battery-routines-until-enabled.md) refines device-aware routine creation:** Battery charge routines are opt-in, default off, and removed while disabled so Charge Mac, Charge iPhone, and related managed routines only appear after the user enables the setting.
- **[0171](0171-remove-default-check-in-activity-tags.md) refines [0014](0014-model-place-check-ins-as-place-sessions.md), [0023](0023-edit-place-check-ins-from-day-timeline.md), and [0039](0039-move-mac-check-in-to-home-toolbar.md) for place check-ins:** New check-ins no longer offer or apply the built-in Work, Commute, Errands, Exercise, Rest, Social, and Other activity tags; legacy values remain readable for existing sessions and backups.
- **[0170](0170-treat-backup-reset-as-complete-user-data-operations.md) refines [0167](0167-merge-icloud-and-backup-settings.md) and [0168](0168-require-recent-backup-for-cloud-data-reset.md) for data continuity:** Default `.routinabackup` exports, backup import, and destructive reset are complete user-data operations over the SwiftData user model set, while legacy `.json` backup remains compatibility-only for older task/place/goal/log payloads.
- **[0168](0168-require-recent-backup-for-cloud-data-reset.md) refines [0165](0165-suggest-backup-before-cloud-data-reset.md), [0166](0166-use-app-lock-for-cloud-data-reset.md), and [0167](0167-merge-icloud-and-backup-settings.md) for cloud data reset recovery:** Cloud data reset requires a successful local backup export from the last 24 hours before App Lock authentication or destructive reset can begin.
- **[0167](0167-merge-icloud-and-backup-settings.md) refines [0165](0165-suggest-backup-before-cloud-data-reset.md) and [0166](0166-use-app-lock-for-cloud-data-reset.md) for Settings data continuity:** iCloud sync/reset and backup import/export live in one iCloud & Backup Settings section, while legacy Backup navigation routes to the merged destination.
- **[0166](0166-use-app-lock-for-cloud-data-reset.md) supersedes [0164](superseded/0164-require-password-for-cloud-data-reset.md) for cloud data reset authentication:** Cloud data reset uses App Lock and fresh device authentication instead of a custom one-time deletion password.
- **[0165](0165-suggest-backup-before-cloud-data-reset.md) refines [0166](0166-use-app-lock-for-cloud-data-reset.md) for cloud data reset recovery:** The reset confirmation presents backup first, with a direct backup export action and visible backup status before the App Lock confirmation section.
- **[0163](0163-name-raw-current-location-check-ins-opportunistically.md) refines [0015](0015-support-map-based-place-check-ins.md) and [0023](0023-edit-place-check-ins-from-day-timeline.md) for raw current-location check-ins:** Raw current-location check-ins still save immediately, but use local best-effort names from nearby user-named raw sessions, nearby saved places, or a time fallback. Map and timeline surfaces offer a non-blocking `Save as Place` path that links the source check-in to the new saved place.
- **[0160](0160-support-mac-browser-website-blocking.md) refines [0159](0159-support-entered-website-blocking-on-ios.md), [0158](0158-generalize-protected-mode-blocking-settings.md), and [0099](0099-block-selected-mac-apps-during-focus.md) for Mac website blocking:** Entered domains are now enforced on Mac through best-effort browser automation for Safari and common Chromium browsers while enabled protected modes are active. This is browser-level blocking, not system-wide network filtering.
- **[0159](0159-support-entered-website-blocking-on-ios.md) refines [0158](0158-generalize-protected-mode-blocking-settings.md) and [0085](0085-shield-apps-and-websites-during-focus.md) for website blocking:** Users can type website domains directly on iOS. Entered domains are normalized, store Focus/Away/Sleep applicability, and are enforced through iOS Screen Time web-content filtering alongside picker tokens. Native macOS website blocking remains deferred.
- **[0158](0158-generalize-protected-mode-blocking-settings.md) refines [0085](0085-shield-apps-and-websites-during-focus.md), [0099](0099-block-selected-mac-apps-during-focus.md), [0104](0104-enable-mac-focus-app-blocking-by-default.md), [0125](0125-support-away-sessions.md), and [0012](0012-model-sleep-as-app-level-session-mode.md) for protected-mode blocking:** Blocking lives in one Settings section with Focus, Away, and Sleep applicability. iOS uses one Screen Time selection gated by enabled modes; macOS stores selected apps with per-app mode applicability. Sleep now participates in blocker sync.
- **[0157](0157-reward-planner-work-in-adventure.md) refines [0150](0150-add-mac-adventure-progression-mvp.md), [0005](0005-show-timeline-activity-in-day-planner.md), and [0008](0008-confirm-timeline-activity-as-planner-block.md) for Adventure rewards:** Saved planner blocks, full planned hours, and planner refinements earn small Adventure rewards from persisted `DayPlanBlockRecord` data.
- **[0156](0156-reward-board-focus-in-adventure.md) refines [0150](0150-add-mac-adventure-progression-mvp.md) for Adventure rewards:** Board focus blocks from `SprintFocusSessionRecord` are their own Adventure coin source, separate from task/unassigned focus blocks.
- **[0155](0155-link-away-activity-in-planner.md) refines [0125](0125-support-away-sessions.md) and [0005](0005-show-timeline-activity-in-day-planner.md) for planner presentation:** Completed timeline activity that overlaps Away is linked into the Away planner block and suppressed as a separate automatic activity card, preserving both records while showing one planner block.
- **[0154](0154-present-mac-away-start-inline.md) refines [0125](0125-support-away-sessions.md) and [0070](0070-include-sleep-in-mac-add-menu.md) for Mac Away start:** Choosing Away from the Mac Home Add menu opens the starter in the main detail area instead of a sheet, while the active Away session behavior remains unchanged.
- **[0153](0153-make-mac-adventure-worlds-and-creatures-explicit-unlocks.md) refines [0152](0152-support-choice-based-mac-adventure-unlocks.md) for Mac Adventure ownership:** Adventure progress makes worlds and stage creatures eligible, but only explicit local unlock IDs make them chosen/owned. Users can choose any eligible world and then any eligible creature inside a chosen world; the path is not linear by default.
- **[0152](0152-support-choice-based-mac-adventure-unlocks.md) refines [0150](0150-add-mac-adventure-progression-mvp.md) for Mac Adventure unlocks:** Adventure still derives progress from activity history, but item ownership is chosen by the user and stored as local app setting state. Maps present stages as encounters without route lines over the artwork.
- **[0149](0149-use-rolling-achievement-period-windows.md) refines [0145](0145-separate-recent-wins-from-achievements.md) and [0146](0146-tab-achievement-status-and-periods.md) for achievement periods:** Recent Wins and Achieved badge period filters use rolling date windows through the current reference instant. Today starts at the beginning of the current day; week, month, and year start at the beginning of the day one calendar week, month, or year before the reference date.
- **[0148](0148-support-count-up-away-sessions.md) refines [0125](0125-support-away-sessions.md) for Away timers:** Away supports fixed-duration and count-up sessions. Count-up uses `plannedDurationSeconds == 0`, has no planned end, does not auto-complete by expiry, and contributes by elapsed protected time. Planned-duration Away achievements still count only completed fixed-duration sessions.
- **[0146](0146-tab-achievement-status-and-periods.md) supersedes [0132](superseded/0132-categorize-achievement-badges.md) for achievements browsing:** Achievements keep domain categories, but In Progress and Achieved are tabs; Achieved adds Today, This Week, This Month, and This Year period filters.
- **[0145](0145-separate-recent-wins-from-achievements.md) supersedes [0141](superseded/0141-show-achievement-period-celebrations.md) for recent accomplishments:** Recent Wins is a top-level Stats scope, not a preface inside Achievements. Achievements returns to all-time badge progress.
- **[0143](0143-present-mac-note-editing-inline.md) supersedes the Mac Home modal default implied by [0142](0142-edit-standalone-notes.md):** Note editing in Mac Home replaces the detail area with the editor; other note detail hosts may keep the sheet fallback.
- **[0140](0140-open-sleep-links-in-planner.md) supersedes the read-only sleep-row behavior in [0083](0083-open-emotion-context-links.md):** Sleep links now use `routina://sleep/<uuid>` and open the macOS Planner to the protected sleep block; iOS keeps Timeline fallback until it has planner routing.
- **[0129](0129-hide-abandoned-focus-sessions-from-timeline.md) supersedes [0126](superseded/0126-show-focus-sessions-in-timeline.md) for focus timeline evidence:** Active, paused, and completed focus sessions can appear in Timeline; abandoned task focus sessions stay out.
- **[0105](0105-remove-abandoned-focus-blocks-from-planner.md) supersedes [0103](superseded/0103-record-count-up-focus-blocks-at-elapsed-duration.md), [0102](superseded/0102-create-planner-blocks-when-task-focus-starts.md), and [0007](superseded/0007-show-active-focus-timers-in-planner.md) for focus planner blocks:** Starting task focus creates a planner representation, count-up duration is corrected to elapsed whole minutes when finished, and abandoned or canceled task focus removes the focus-created planner block.
- **[0093](0093-support-all-day-routines.md) supersedes [0090](superseded/0090-support-manual-all-day-tasks.md) and [0086](superseded/0086-show-all-day-calendar-events-in-planner.md) for all-day planner behavior:** All-day is a task property for todos and routines. Imported all-day calendar metadata remains highest priority for preserving multi-day spans.
- **[0073](0073-open-ios-home-actions-horizontally.md) updates [0055](0055-move-ios-home-place-and-sleep-into-action-rail.md) and supersedes [0054](superseded/0054-open-ios-home-top-actions-vertically.md) and [0052](superseded/0052-use-compact-ios-home-actions.md) for iOS Home actions:** Home actions expand horizontally in the navigation bar; task creation belongs to the iOS Task tab action; bottom floating action controls are gone.
- **[0070](0070-include-sleep-in-mac-add-menu.md) supersedes [0066](superseded/0066-include-check-in-in-mac-add-menu.md) and part of [0039](0039-move-mac-check-in-to-home-toolbar.md), while [0078](0078-present-mac-emotion-creation-inline.md) extends the active menu:** The Mac Home sidebar `+` menu owns quick capture/actions for Emotion, Note, Goal, Task, Check In, and Sleep; place status controls stay in the Home toolbar.
- **[0043](0043-split-task-row-color-badge-visibility.md) supersedes part of [0038](0038-configure-home-task-row-fields.md) for task row color visibility:** Row tint/background and the row-edge color badge are separate visibility fields.
- **[0031](0031-auto-check-in-at-saved-places.md) supersedes [0026](superseded/0026-require-explicit-saved-place-check-in-action.md) for saved-place check-ins:** Automatic saved-place check-in can exist when enabled, but automatic rows stay labeled and confirmable.
- **[0021](0021-keep-mac-places-in-home-split-shell.md) supersedes [0017](superseded/0017-show-mac-map-check-in-inline.md)-[0020](superseded/0020-show-mac-places-as-workspace.md) for Mac Places:** Places remains inside the shared Home split shell instead of becoming a separate workspace.
- **[0003](0003-resolve-exact-time-missed-assumptions.md) partially supersedes [0002](0002-exact-time-routines-miss-after-day.md) for exact-time routines:** Missed assumptions stay visible until resolved as done, missed, or canceled.

### Active Categories

- **Project governance and platform conventions:** Keep active numbered records in this directory and superseded records in `superseded/` for long-term product, data, build, dependency, convention, and architecture decisions. Routina targets the current Apple platform baseline, Swift 6, native Apple patterns, Liquid Glass custom surfaces, native macOS undo/redo, and behavior-preserving refactors when large touched files would otherwise stay hard to review.
- **Tasks, routines, and scheduling:** Recurrence lives in typed SwiftData columns, with legacy JSON only as migration input. Forms present Availability as an independent any-time/all-day/exact-time/window choice before asking whether a routine due day repeats by interval or calendar pattern. Todo Availability supports the same four timing choices, with exact-time/window stored on the one-day recurrence rule and deadline controls kept separate. Routines store Due/Gentle scheduling and Standard/Checklist/Runout format separately; Due/Gentle controls overdue pressure while Interval/Calendar controls cadence, including Gentle calendar repeats. Forms present Standard/Checklist finish with Runout nested under checklist cadence/timing. Exact-time and time-range routines resolve missed assumptions instead of staying overdue forever. Optional checklists can attach to ordinary tasks and block manual completion until every item is done. All-day intent is first-class task data for todos and routines; all-day is mutually exclusive with recurrence exact-time/window availability in forms and save builders. Device battery charge routines are opt-in and removed while their setting is disabled.
- **Planner, timeline, and events:** Timeline is evidence for done, missed, canceled, sleep, place, note, emotion, event, and accepted focus activity. The planner can surface unplanned timeline activity, but automatic suggestions come only from completed activity and can be hidden as presentation state. Planner all-day lanes accept task, timed-block, and completed-activity drops. Standalone events render as calendar-visible, read-only planner blocks.
- **Focus, Away, Sleep, and shielding:** Sleep, Focus, and Away are app-level protected session types that must not overlap. Task, unassigned, and board focus can pause/resume, count active time instead of paused wall-clock time, and feed planner, timeline, stats, widgets, Live Activities, Watch payloads, and achievements. Away uses dedicated stats, can be fixed-duration or count-up, and links overlapping completed activity into the Away planner block instead of showing duplicate planner cards. Blocking is configured in one Settings section with Focus, Away, and Sleep applicability. iOS shields, iOS entered-website web-content filters, Mac browser-level website automation, and the macOS app blocker apply while an enabled protected mode is active, then clear when protection ends.
- **Stats, achievements, wins, and Adventure:** Stats supports customizable, reorderable, adaptive-width dashboards with factual cards and charts for outcomes, focus, goals, emotions, estimates, hourly rhythm, Health movement, Sleep, Wins, and Achievements. Achievements are recalculated presentation state across Focus, Sleep, Away, Done, Emotions, Places, Goals, and Notes. Recent Wins is its own Stats scope for rolling current-period accomplishments. Mac Adventure derives coins, XP, stage stars, and world/stage eligibility from existing activity history, rewards task focus, board focus, and persisted planner work as separate sources, stores chosen worlds, stage creatures, and item ownership in local app setting state, presents maps as encounters instead of route lines, and shares the Mac Stats sidebar tab behind a `Stats / Adventure` segment.
- **Home navigation, creation, and editing:** Mac Home keeps one split shell for Details, Planner, Board, and Places, with root-owned toolbar content and a sidebar Done-counter exception. The Mac sidebar `+` menu opens Emotion, Note, Goal, Task, Check In, Away, and Sleep. Mac note, emotion, goal, and Away start flows prefer the main detail area. iOS uses an app-owned More tab, Home-specific filter controls, and a bottom-bar `New` action that opens a compact sheet for Event, Emotion, Note, Goal, Task, Check In, Away, and Going to sleep.
- **Places, check-ins, and maps:** Place check-ins are duration-based `PlaceCheckInSession` records and timeline evidence, distinct from planner blocks, sleep, and focus. The Places map supports saved-place creation, map-based check-in, grouped history markers, raw current-location sessions, configurable automatic saved-place check-ins, and correction through Places/check-in history surfaces. New check-ins do not offer built-in default activity tags; legacy activity values remain readable for older sessions and backups. Raw current-location check-ins use local best-effort names and can be promoted into saved places after capture without blocking the check-in.
- **Notes, emotions, media, and links:** Standalone notes, emotion logs, and events are first-class SwiftData records with timeline filters and backup/import support. Notes can be edited without changing their original timeline date. Emotion logs store multiple families/details, pleasantness, energy, intensity, context links, and a Tired quick-log path. Task comments/notes and standalone notes expose Markdown-style editing controls. Task links, task voice notes, note media, place images, and timeline media filters preserve evidence across backup/import and CloudKit repair.
- **Goals, tags, filters, and list organization:** Goals support parent/child hierarchy, inline editing, normalized tags, and tag-derived task suggestions. Tags compare case-insensitively and accent-insensitively while preserving existing display spelling. Home list grouping supports None, Status, Deadline Date, and Tags, with shared filters for goal presence and media. Task row field visibility separates row tint/background from the row-edge color badge.
- **Data continuity, devices, and deep links:** Backup/import, CloudKit direct pull repair, reset, duplicate cleanup, iCloud usage estimates, and sharing should preserve new owned data and retain compatibility with older payloads. Default `.routinabackup` export/import and destructive reset are complete user-data operations over the SwiftData user model set, while legacy `.json` backup remains compatibility-only for older task/place/goal/log payloads. iCloud sync/reset and backup import/export live in one iCloud & Backup Settings section. Data-wide reset actions show backup/export first when possible and require a successful local backup export from the last 24 hours plus App Lock fresh device authentication before destructive work can begin. Routina records per-installation device sessions and action-origin logs. Production and development builds use separate `routina://` and `routina-dev://` deep-link schemes for tasks, goals, notes, sprints, and sleep sessions.

## Open Questions

- `docs/routina-features-web.html` is older than the decision log entries for missed outcomes, sleep sessions, and place sessions. Should the public feature guide be updated to describe timeline activity as done, missed, canceled, sleep, and place/session history instead of only completed and canceled work?
- `docs/recurring-window-routines.md` proposes recurring-window and flexible-gap schedules, but no accepted decision record currently adopts that model. Should this be promoted into a numbered decision before implementation?
- [0021](0021-keep-mac-places-in-home-split-shell.md) says the `Details / Planner / Board / Places` picker stays in the detail-column header, while [0022](0022-own-mac-home-toolbar-at-split-shell.md) moves global Home toolbar content to the root split-view shell. Should the mode picker be treated as detail-header content or as global Home toolbar content?
- [0093](0093-support-all-day-routines.md) keeps manual all-day tasks as one-day blocks while preserving imported multi-day calendar spans. Should Routina add a first-class manual multi-day task-span model?
- [0140](0140-open-sleep-links-in-planner.md) keeps iOS sleep links on a Timeline fallback until the phone app has a planner destination. Should iOS add sleep-block planner routing, or is the Timeline fallback the intended compact behavior?
- [0146](0146-tab-achievement-status-and-periods.md) derives achieved-period badges by comparing current all-time badges with pre-period history because unlock rows are not persisted. Is that approximation enough, or should badge unlock and celebration history become persisted state?
- [0160](0160-support-mac-browser-website-blocking.md) adds browser-level Mac website blocking, but not system-wide network filtering. Should Routina eventually add a Network Extension or browser-extension path for stronger Mac website coverage?

## Records

| ID | Title | Status | Date |
| --- | --- | --- | --- |
| [0001](0001-maintain-project-decision-log.md) | Maintain a Project Decision Log | Accepted | 2026-05-08 |
| [0002](0002-exact-time-routines-miss-after-day.md) | Treat Exact-Time Routines as Missed After Their Scheduled Day | Accepted | 2026-05-08 |
| [0003](0003-resolve-exact-time-missed-assumptions.md) | Resolve Exact-Time Missed Assumptions as Done, Missed, or Canceled | Accepted | 2026-05-09 |
| [0004](0004-macos-task-list-keyboard-navigation.md) | Support Keyboard Navigation in the macOS Task List | Accepted | 2026-05-09 |
| [0005](0005-show-timeline-activity-in-day-planner.md) | Show Timeline Activity in the Day Planner | Accepted | 2026-05-09 |
| [0006](0006-make-planner-timeline-activity-configurable.md) | Make Planner Timeline Activity Configurable | Accepted | 2026-05-09 |
| [0007](superseded/0007-show-active-focus-timers-in-planner.md) | Show Active Focus Timers in the Planner | Superseded | 2026-05-09 |
| [0008](0008-confirm-timeline-activity-as-planner-block.md) | Confirm Timeline Activity as Planner Blocks | Accepted | 2026-05-09 |
| [0009](0009-support-routine-time-ranges.md) | Support Routine Time Ranges | Accepted | 2026-05-09 |
| [0010](0010-store-recurrence-rules-in-swiftdata-columns.md) | Store Recurrence Rules in SwiftData Columns | Accepted | 2026-05-09 |
| [0011](0011-open-planner-sidebar-tasks-with-double-click.md) | Open Planner Sidebar Tasks with Double Click | Accepted | 2026-05-09 |
| [0012](0012-model-sleep-as-app-level-session-mode.md) | Model Sleep as an App-Level Session Mode | Accepted | 2026-05-10 |
| [0013](0013-use-neutral-cancellation-styling.md) | Use Neutral Cancellation Styling | Accepted | 2026-05-10 |
| [0014](0014-model-place-check-ins-as-place-sessions.md) | Model Place Check-Ins as Place Sessions | Accepted | 2026-05-10 |
| [0015](0015-support-map-based-place-check-ins.md) | Support Map-Based Place Check-Ins | Accepted | 2026-05-10 |
| [0016](0016-show-place-check-ins-as-day-timeline.md) | Show Place Check-Ins as a Day Timeline | Accepted | 2026-05-10 |
| [0017](superseded/0017-show-mac-map-check-in-inline.md) | Show Mac Map Check-In Inline | Superseded | 2026-05-10 |
| [0018](superseded/0018-show-mac-map-check-in-in-detail-column.md) | Show Mac Map Check-In in the Detail Column | Superseded | 2026-05-10 |
| [0019](superseded/0019-show-mac-places-as-detail-mode.md) | Show Mac Places as a Detail Mode | Superseded | 2026-05-10 |
| [0020](superseded/0020-show-mac-places-as-workspace.md) | Show Mac Places as a Workspace | Superseded | 2026-05-10 |
| [0021](0021-keep-mac-places-in-home-split-shell.md) | Keep Mac Places in the Home Split Shell | Accepted | 2026-05-11 |
| [0022](0022-own-mac-home-toolbar-at-split-shell.md) | Own Mac Home Toolbar at the Split Shell | Accepted | 2026-05-11 |
| [0023](0023-edit-place-check-ins-from-day-timeline.md) | Edit Place Check-Ins from the Day Timeline | Accepted | 2026-05-11 |
| [0024](0024-adopt-liquid-glass-ui-surfaces.md) | Adopt Liquid Glass UI Surfaces | Accepted | 2026-05-12 |
| [0025](0025-show-place-check-in-history-markers-on-map.md) | Show Place Check-In History Markers on the Map | Accepted | 2026-05-12 |
| [0026](superseded/0026-require-explicit-saved-place-check-in-action.md) | Require an Explicit Saved-Place Check-In Action | Superseded | 2026-05-12 |
| [0027](0027-show-places-day-as-grouped-history.md) | Show Places Day as Grouped History | Accepted | 2026-05-12 |
| [0028](0028-default-places-to-check-ins-history.md) | Default Places to Check-Ins History | Accepted | 2026-05-12 |
| [0029](0029-create-saved-places-from-map.md) | Create Saved Places From the Map | Accepted | 2026-05-12 |
| [0030](0030-track-device-sessions-and-action-origins.md) | Track Device Sessions and Action Origins | Accepted | 2026-05-12 |
| [0031](0031-auto-check-in-at-saved-places.md) | Auto Check In at Saved Places | Accepted | 2026-05-12 |
| [0032](0032-sync-active-sleep-mode-across-devices.md) | Sync Active Sleep Mode Across Devices | Accepted | 2026-05-13 |
| [0033](0033-use-app-owned-ios-more-tab.md) | Use an App-Owned iOS More Tab | Accepted | 2026-05-13 |
| [0034](0034-target-current-apple-platforms-only.md) | Target Current Apple Platforms Only | Accepted | 2026-05-13 |
| [0035](0035-place-mac-done-counter-beside-sidebar-toggle.md) | Place Mac Done Counter Beside Sidebar Toggle | Accepted | 2026-05-13 |
| [0036](0036-treat-completion-times-as-planner-finish-times.md) | Treat Completion Times as Planner Finish Times | Accepted | 2026-05-13 |
| [0037](0037-support-mac-home-back-forward-history.md) | Support Mac Home Back and Forward History | Accepted | 2026-05-13 |
| [0038](0038-configure-home-task-row-fields.md) | Configure Home Task Row Fields | Accepted | 2026-05-14 |
| [0039](0039-move-mac-check-in-to-home-toolbar.md) | Move Mac Check-In to the Home Toolbar | Accepted | 2026-05-14 |
| [0040](0040-make-automatic-place-check-in-configurable.md) | Make Automatic Place Check-In Configurable | Accepted | 2026-05-14 |
| [0041](0041-filter-home-tasks-by-goal-presence.md) | Filter Home Tasks by Goal Presence | Accepted | 2026-05-14 |
| [0042](0042-link-goals-into-hierarchies.md) | Link Goals Into Hierarchies | Accepted | 2026-05-14 |
| [0043](0043-split-task-row-color-badge-visibility.md) | Split Task Row Color Badge Visibility | Accepted | 2026-05-14 |
| [0044](0044-edit-saved-places-from-places-list.md) | Edit Saved Places From the Places List | Accepted | 2026-05-14 |
| [0045](0045-split-routine-schedule-behavior-and-format.md) | Split Routine Schedule Behavior and Format | Accepted | 2026-05-14 |
| [0046](0046-label-routine-schedule-behavior-as-due-and-gentle.md) | Label Routine Schedule Behavior as Due and Gentle | Accepted | 2026-05-14 |
| [0047](0047-edit-goals-inline-in-goals-detail.md) | Edit Goals Inline in the Goals Detail Surface | Accepted | 2026-05-14 |
| [0048](0048-tag-goals.md) | Tag Goals | Accepted | 2026-05-14 |
| [0049](0049-filter-tasks-and-done-items-by-media.md) | Filter Tasks and Done Items by Media | Accepted | 2026-05-14 |
| [0050](0050-suggest-goal-task-links-from-tags.md) | Suggest Goal Task Links From Tags | Accepted | 2026-05-14 |
| [0051](0051-attach-images-to-place-check-ins.md) | Attach Images to Place Check-Ins | Accepted | 2026-05-25 |
| [0052](superseded/0052-use-compact-ios-home-actions.md) | Use Compact iOS Home Icon Actions | Superseded | 2026-05-25 |
| [0053](0053-record-task-voice-notes.md) | Record Task Voice Notes | Accepted | 2026-05-25 |
| [0054](superseded/0054-open-ios-home-top-actions-vertically.md) | Open iOS Home Top Actions Vertically | Superseded | 2026-05-25 |
| [0055](0055-move-ios-home-place-and-sleep-into-action-rail.md) | Move iOS Home Place and Sleep Into Action Rail | Accepted | 2026-05-25 |
| [0056](0056-hide-git-settings-until-enabled.md) | Hide Git Settings Until Enabled | Accepted | 2026-05-25 |
| [0057](0057-merge-support-and-about-settings.md) | Merge Support and About Settings | Accepted | 2026-05-25 |
| [0058](0058-use-progressive-task-forms.md) | Use Progressive Task Forms | Accepted | 2026-05-25 |
| [0059](superseded/0059-use-mac-home-sidebar-add-menu.md) | Use a Mac Home Sidebar Add Menu | Superseded | 2026-05-26 |
| [0060](0060-support-standalone-notes.md) | Support Standalone Notes | Accepted | 2026-05-26 |
| [0061](0061-share-stable-routina-deep-links.md) | Share Stable Routina Deep Links | Accepted | 2026-05-26 |
| [0062](0062-present-mac-note-creation-inline.md) | Present Mac Note Creation Inline | Accepted | 2026-05-26 |
| [0063](0063-tag-standalone-notes.md) | Tag Standalone Notes | Accepted | 2026-05-26 |
| [0064](0064-group-home-task-list-by-tags.md) | Group Home Task List by Tags | Accepted | 2026-05-26 |
| [0065](0065-open-timeline-notes-and-places-from-rows.md) | Open Timeline Notes and Places From Rows | Accepted | 2026-05-26 |
| [0066](superseded/0066-include-check-in-in-mac-add-menu.md) | Include Check In in the Mac Add Menu | Superseded | 2026-05-26 |
| [0067](0067-separate-prod-and-dev-deep-link-schemes.md) | Separate Prod and Dev Deep Link Schemes | Accepted | 2026-05-26 |
| [0068](0068-select-mac-sidebar-rows-for-deep-links.md) | Select Mac Sidebar Rows for Deep Links | Accepted | 2026-05-26 |
| [0069](0069-support-optional-task-checklists.md) | Support Optional Task Checklists | Accepted | 2026-05-26 |
| [0070](0070-include-sleep-in-mac-add-menu.md) | Include Sleep in the Mac Add Menu | Accepted | 2026-05-26 |
| [0071](0071-move-ios-task-add-to-tab-bar.md) | Move iOS Task Add to the Tab Bar | Accepted | 2026-05-26 |
| [0072](0072-unify-ios-task-add-and-quick-add.md) | Unify iOS Task Add and Quick Add | Accepted | 2026-05-26 |
| [0073](0073-open-ios-home-actions-horizontally.md) | Open iOS Home Actions Horizontally | Accepted | 2026-05-26 |
| [0074](0074-parse-mac-add-task-title.md) | Parse Mac Add Task Title | Accepted | 2026-05-26 |
| [0075](0075-treat-tags-as-case-insensitive-identities.md) | Treat Tags as Case-Insensitive Identities | Accepted | 2026-05-26 |
| [0076](0076-select-saved-home-items-after-creation.md) | Select Saved Home Items After Creation | Accepted | 2026-05-26 |
| [0077](0077-support-standalone-emotion-logs.md) | Support Standalone Emotion Logs | Accepted | 2026-05-26 |
| [0078](0078-present-mac-emotion-creation-inline.md) | Present Mac Emotion Creation Inline | Accepted | 2026-05-27 |
| [0079](0079-use-segmented-mood-input-for-emotions.md) | Use Segmented Mood Input for Emotions | Accepted | 2026-05-27 |
| [0080](0080-keep-emotion-family-suggestions-in-selected-mood-quadrant.md) | Keep Emotion Family Suggestions in the Selected Mood Quadrant | Accepted | 2026-05-27 |
| [0081](0081-store-multiple-emotion-selections.md) | Store Multiple Emotion Families and Feelings | Accepted | 2026-05-27 |
| [0082](0082-edit-emotion-logs-from-detail.md) | Edit Emotion Logs From Detail | Accepted | 2026-05-27 |
| [0083](0083-open-emotion-context-links.md) | Open Emotion Context Links | Accepted | 2026-05-27 |
| [0084](0084-include-personal-records-in-stats-summary.md) | Include Personal Records in Stats Summary | Accepted | 2026-05-27 |
| [0085](0085-shield-apps-and-websites-during-focus.md) | Shield Apps and Websites During Focus | Accepted | 2026-05-27 |
| [0086](superseded/0086-show-all-day-calendar-events-in-planner.md) | Show All-Day Calendar Events in the Planner | Superseded | 2026-05-27 |
| [0087](0087-hide-automatic-planner-suggestions.md) | Hide Automatic Planner Suggestions | Accepted | 2026-05-27 |
| [0088](0088-support-ungrouped-home-task-list.md) | Support an Ungrouped Home Task List | Accepted | 2026-05-27 |
| [0089](0089-prefer-native-apple-platform-patterns.md) | Prefer Native Apple Platform Patterns | Accepted | 2026-05-27 |
| [0090](superseded/0090-support-manual-all-day-tasks.md) | Support Manual All-Day Tasks in the Planner | Superseded | 2026-05-28 |
| [0091](0091-use-native-macos-undo-redo.md) | Use Native macOS Undo and Redo | Accepted | 2026-05-28 |
| [0092](0092-support-standalone-events.md) | Support Standalone Events | Accepted | 2026-05-28 |
| [0093](0093-support-all-day-routines.md) | Support All-Day Tasks Across Schedule Types | Accepted | 2026-05-28 |
| [0094](0094-suggest-only-completed-activity-in-planner-calendar.md) | Suggest Only Completed Activity in the Planner Calendar | Accepted | 2026-05-28 |
| [0095](0095-drag-tasks-to-planner-all-day-lane.md) | Drag Tasks to the Planner All Day Lane | Accepted | 2026-05-28 |
| [0096](0096-show-healthkit-movement-stats.md) | Show HealthKit Movement Stats in iOS Stats | Accepted | 2026-05-28 |
| [0097](0097-preserve-compact-more-destination.md) | Preserve Compact More Destination Across Tab Switches | Accepted | 2026-05-28 |
| [0098](0098-support-markdown-text-editing-controls.md) | Support Markdown Text Editing Controls | Accepted | 2026-05-29 |
| [0099](0099-block-selected-mac-apps-during-focus.md) | Block Selected Mac Apps During Focus | Accepted | 2026-05-29 |
| [0100](0100-reveal-task-form-details-by-section.md) | Reveal Task Form Details by Section | Accepted | 2026-05-29 |
| [0101](0101-treat-empty-checklists-as-optional-task-details.md) | Treat Empty Checklists as Optional Task Details | Accepted | 2026-05-29 |
| [0102](superseded/0102-create-planner-blocks-when-task-focus-starts.md) | Create Planner Blocks When Task Focus Starts | Superseded | 2026-05-30 |
| [0103](superseded/0103-record-count-up-focus-blocks-at-elapsed-duration.md) | Record Count-Up Focus Blocks at Elapsed Duration | Superseded | 2026-05-30 |
| [0104](0104-enable-mac-focus-app-blocking-by-default.md) | Enable Mac Focus App Blocking by Default | Accepted | 2026-05-30 |
| [0105](0105-remove-abandoned-focus-blocks-from-planner.md) | Remove Abandoned Focus Blocks from Planner | Accepted | 2026-05-30 |
| [0106](0106-support-unassigned-watch-focus-sessions.md) | Support Unassigned Watch Focus Sessions | Accepted | 2026-05-30 |
| [0107](0107-show-focus-weekday-averages.md) | Show Focus Weekday Averages | Accepted | 2026-05-31 |
| [0108](0108-show-stats-outcome-mix.md) | Show Stats Outcome Mix | Accepted | 2026-05-31 |
| [0109](0109-show-focus-work-comparison.md) | Show Focus Work Comparison | Accepted | 2026-05-31 |
| [0110](0110-show-goal-momentum-stats.md) | Show Goal Momentum Stats | Accepted | 2026-05-31 |
| [0111](0111-show-emotion-trends-in-stats.md) | Show Emotion Trends in Stats | Accepted | 2026-05-31 |
| [0112](0112-show-estimated-actual-time-stats.md) | Show Estimated Actual Time Stats | Accepted | 2026-05-31 |
| [0113](0113-allow-stats-dashboard-reordering.md) | Allow Stats Dashboard Reordering | Accepted | 2026-05-31 |
| [0114](0114-clarify-emotion-trend-chart.md) | Clarify Emotion Trend Chart | Accepted | 2026-05-31 |
| [0115](0115-support-compact-stats-summary-cards.md) | Support Compact Stats Summary Cards | Accepted | 2026-05-31 |
| [0116](0116-show-focus-blocks.md) | Show Focus Blocks | Accepted | 2026-05-31 |
| [0117](0117-show-hourly-stats-rhythm.md) | Show Hourly Stats Rhythm | Accepted | 2026-05-31 |
| [0118](0118-show-focus-chart-details-and-grouping.md) | Show Focus Chart Details and Grouping | Accepted | 2026-05-31 |
| [0119](0119-show-cumulative-focus-chart.md) | Show Cumulative Focus Chart | Accepted | 2026-05-31 |
| [0120](0120-show-focus-2048-board.md) | Show Focus 2048 Board | Accepted | 2026-05-31 |
| [0121](0121-show-focus-2048-earned-tiles.md) | Show Focus 2048 Earned Tiles | Accepted | 2026-05-31 |
| [0122](superseded/0122-show-focus-achievement-badges.md) | Show Focus Achievement Badges | Superseded | 2026-05-31 |
| [0123](0123-pause-focus-timers.md) | Pause Focus Timers | Accepted | 2026-05-31 |
| [0124](0124-support-multiple-task-links.md) | Support Multiple Task Links | Accepted | 2026-06-01 |
| [0125](0125-support-away-sessions.md) | Support Away Sessions | Accepted | 2026-06-01 |
| [0126](superseded/0126-show-focus-sessions-in-timeline.md) | Show Focus Sessions in Timeline | Superseded | 2026-06-01 |
| [0127](0127-pause-board-focus-timers.md) | Pause Board Focus Timers | Accepted | 2026-06-01 |
| [0128](0128-show-board-focus-in-planner.md) | Show Board Focus in Planner | Accepted | 2026-06-01 |
| [0129](0129-hide-abandoned-focus-sessions-from-timeline.md) | Hide Abandoned Focus Sessions from Timeline | Accepted | 2026-06-01 |
| [0130](0130-block-manual-completion-until-optional-checklists-done.md) | Block Manual Completion Until Optional Checklists Are Done | Accepted | 2026-06-01 |
| [0131](0131-show-general-achievement-badges.md) | Show General Achievement Badges | Accepted | 2026-06-02 |
| [0132](superseded/0132-categorize-achievement-badges.md) | Categorize Achievement Badges | Superseded | 2026-06-02 |
| [0133](0133-extend-done-achievement-ladder.md) | Extend the Done Achievement Ladder | Accepted | 2026-06-02 |
| [0134](0134-add-personal-record-achievement-domains.md) | Add Personal Record Achievement Domains | Accepted | 2026-06-02 |
| [0135](0135-show-today-focus-widget.md) | Show Today Focus Widget | Accepted | 2026-06-02 |
| [0136](0136-refactor-large-files-judiciously.md) | Refactor Large Files Judiciously | Accepted | 2026-06-02 |
| [0137](0137-show-active-focus-in-stats-today.md) | Show Active Focus in Stats Today | Accepted | 2026-06-02 |
| [0138](0138-support-tired-emotion-quick-log.md) | Support a Tired Emotion Quick Log | Accepted | 2026-06-03 |
| [0139](0139-search-emotion-context-links.md) | Search Emotion Context Links | Accepted | 2026-06-03 |
| [0140](0140-open-sleep-links-in-planner.md) | Open Sleep Links in Planner | Accepted | 2026-06-03 |
| [0141](superseded/0141-show-achievement-period-celebrations.md) | Show Achievement Period Celebrations | Superseded | 2026-06-03 |
| [0142](0142-edit-standalone-notes.md) | Edit Standalone Notes | Accepted | 2026-06-03 |
| [0143](0143-present-mac-note-editing-inline.md) | Present Mac Note Editing Inline | Accepted | 2026-06-03 |
| [0144](0144-expose-sleep-as-stats-dashboard-scope.md) | Expose Sleep as a Stats Dashboard Scope | Accepted | 2026-06-03 |
| [0145](0145-separate-recent-wins-from-achievements.md) | Separate Recent Wins From Achievements | Accepted | 2026-06-03 |
| [0146](0146-tab-achievement-status-and-periods.md) | Tab Achievement Status and Achieved Periods | Accepted | 2026-06-03 |
| [0147](0147-use-adaptive-stats-dashboard-width.md) | Use Adaptive Stats Dashboard Width | Accepted | 2026-06-03 |
| [0148](0148-support-count-up-away-sessions.md) | Support Count-Up Away Sessions | Accepted | 2026-06-03 |
| [0149](0149-use-rolling-achievement-period-windows.md) | Use Rolling Achievement Period Windows | Accepted | 2026-06-03 |
| [0150](0150-add-mac-adventure-progression-mvp.md) | Add Mac Adventure Progression MVP | Accepted | 2026-06-03 |
| [0151](0151-combine-mac-stats-and-adventure-tab.md) | Combine Mac Stats and Adventure in One Tab | Accepted | 2026-06-03 |
| [0152](0152-support-choice-based-mac-adventure-unlocks.md) | Support Choice-Based Mac Adventure Unlocks | Accepted | 2026-06-04 |
| [0153](0153-make-mac-adventure-worlds-and-creatures-explicit-unlocks.md) | Make Mac Adventure Worlds and Creatures Explicit Unlocks | Accepted | 2026-06-04 |
| [0154](0154-present-mac-away-start-inline.md) | Present Mac Away Start Inline | Accepted | 2026-06-04 |
| [0155](0155-link-away-activity-in-planner.md) | Link Away Activity in the Planner | Accepted | 2026-06-04 |
| [0156](0156-reward-board-focus-in-adventure.md) | Reward Board Focus in Adventure | Accepted | 2026-06-05 |
| [0157](0157-reward-planner-work-in-adventure.md) | Reward Planner Work in Adventure | Accepted | 2026-06-05 |
| [0158](0158-generalize-protected-mode-blocking-settings.md) | Generalize Protected Mode Blocking Settings | Accepted | 2026-06-05 |
| [0159](0159-support-entered-website-blocking-on-ios.md) | Support Entered Website Blocking on iOS | Accepted | 2026-06-05 |
| [0160](0160-support-mac-browser-website-blocking.md) | Support Mac Browser Website Blocking | Accepted | 2026-06-05 |
| [0163](0163-name-raw-current-location-check-ins-opportunistically.md) | Name Raw Current-Location Check-Ins Opportunistically | Accepted | 2026-06-06 |
| [0164](superseded/0164-require-password-for-cloud-data-reset.md) | Require a Password for Cloud Data Reset | Superseded | 2026-06-06 |
| [0165](0165-suggest-backup-before-cloud-data-reset.md) | Suggest Backup Before Cloud Data Reset | Accepted | 2026-06-06 |
| [0166](0166-use-app-lock-for-cloud-data-reset.md) | Use App Lock for Cloud Data Reset | Accepted | 2026-06-06 |
| [0167](0167-merge-icloud-and-backup-settings.md) | Merge iCloud and Backup Settings | Accepted | 2026-06-06 |
| [0168](0168-require-recent-backup-for-cloud-data-reset.md) | Require Recent Backup for Cloud Data Reset | Accepted | 2026-06-06 |
| [0170](0170-treat-backup-reset-as-complete-user-data-operations.md) | Treat Backup and Reset as Complete User Data Operations | Accepted | 2026-06-06 |
| [0171](0171-remove-default-check-in-activity-tags.md) | Remove Default Check-In Activity Tags | Accepted | 2026-06-06 |
| [0172](0172-hide-battery-routines-until-enabled.md) | Hide Battery Routines Until Enabled | Accepted | 2026-06-07 |
| [0173](0173-use-ios-new-tab-sheet.md) | Use iOS New Tab Sheet | Accepted | 2026-06-07 |
| [0174](0174-do-not-restore-mac-add-task-composer.md) | Do Not Restore Mac Add Task Composer | Accepted | 2026-06-07 |
| [0175](0175-use-routine-finish-mode-for-checklist-creation.md) | Use Routine Finish Mode for Checklist Creation | Accepted | 2026-06-07 |
| [0176](0176-nest-runout-under-checklist-cadence.md) | Nest Runout Under Checklist Cadence | Accepted | 2026-06-07 |
| [0177](0177-separate-interval-and-calendar-repeat-controls.md) | Separate Interval and Calendar Repeat Controls | Accepted | 2026-06-07 |
| [0178](0178-make-recurrence-availability-independent.md) | Make Recurrence Availability Independent | Accepted | 2026-06-07 |
| [0179](0179-make-all-day-an-availability-choice.md) | Make Routine All Day an Availability Choice | Accepted | 2026-06-07 |
| [0180](0180-clarify-schedule-behavior-summary.md) | Clarify Schedule Behavior Badge Preview | Accepted | 2026-06-07 |
| [0181](0181-allow-gentle-calendar-repeats.md) | Allow Gentle Calendar Repeats | Accepted | 2026-06-07 |
| [0182](0182-show-todo-all-day-as-availability.md) | Show Todo All Day as Availability | Accepted | 2026-06-07 |
| [0183](0183-support-todo-availability-time-windows.md) | Support Todo Availability Time and Windows | Accepted | 2026-06-07 |
