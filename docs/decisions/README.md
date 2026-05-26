# Project Decision Log

This directory contains Routina's project decision records. These records are the source of truth for important choices that should guide future work.

## How to Use This Log

- Read this index and relevant decision records before making meaningful project changes.
- Add a new decision record when a change introduces or revises a long-term project decision.
- Prefer creating a new record that supersedes an older one instead of rewriting history.
- Keep records focused on the reason for a decision, the choice made, and the consequences.

Use decision records for architecture, conventions, data model, dependencies, product behavior, build setup, and other choices future contributors should preserve or understand. Tiny fixes, copy edits, and purely mechanical cleanup usually do not need a decision record.

## Merged Active Decision State

When decision records overlap, follow explicit supersession first and then prefer the later accepted record.

- **Decision log:** Keep decisions in this directory. Add or supersede records for meaningful long-term architecture, data model, dependency, product behavior, build setup, or convention changes.
- **Timed routines:** Exact-time routine occurrences become missed assumptions after their scheduled day instead of staying overdue across later days. Unresolved assumptions stay visible until resolved as done, missed, or canceled. Time-range routines reuse the same missed-resolution model, with the range start stored as the occurrence timestamp.
- **Routine recurrence storage:** Recurrence metadata is stored in typed SwiftData columns. Legacy recurrence JSON remains only as a migration source and should not be used for new writes.
- **Outcome language and styling:** Timeline activity includes done, missed, and canceled outcomes. Canceled outcomes use neutral gray styling, missed stays distinct from red overdue styling, due/soon-due keeps orange, and overdue keeps red.
- **Planner timeline activity:** The planner can surface unplanned done, missed, and canceled timeline activity for a date. Automatic timeline blocks are derived, visually distinct from user-placed blocks, configurable from Settings > Calendar, and can be confirmed into persisted planner blocks without rewriting timeline history. Done timestamps are finish times for automatic planner placement, and rapid completed activities are arranged backwards from the latest completion while treating persisted planner blocks as occupied time.
- **Planner live sessions:** Active focus sessions render as live derived planner blocks while running. Finished focus sessions remain focus history rather than becoming planner blocks unless a future decision changes that. Sleep sessions render as protected planner blocks and prevent overlapping planner placements.
- **macOS task interactions:** The custom macOS task list owns explicit arrow-key navigation through visible task rows. In the planner sidebar, single click selects and double click opens task details.
- **Sleep:** Sleep is an app-level `SleepSession` mode rather than a routine completion. Sleep and focus timers do not overlap. Active sleep gates the app until ended or undone, and sleep history participates in timeline, planner, stats, widgets, backup, import, and reset flows as dedicated sleep data. iOS Home exposes sleep in the top action rail while preserving the focus-timer warning and Settings visibility toggle.
- **Cross-device sleep:** Active sleep mode is account-wide Routina state. Starting sleep from any supported surface creates or reuses the shared active `SleepSession`, Apple Watch relays sleep start/end through iPhone while preserving the watch as the source device, and waking ends all active sleep sessions to tolerate pre-sync duplicate starts.
- **Place check-ins:** Place check-ins are duration-based `PlaceCheckInSession` records. Starting a new place closes the prior active session, same-place check-ins update the active session, and sessions may store place snapshots, saved-place links, coordinates, and activity tags. Place sessions are timeline evidence distinct from planned blocks, sleep, and focus.
- **Map and place review:** iPhone and Mac expose map-based check-in from platform-owned Home controls. The map flow can request current location, use saved-place radii, record raw current-location sessions, show grouped history markers for coordinate-backed check-ins, and default to a grouped Check-ins history where place sessions can be reviewed, edited, deleted, and used to focus the map. Saved-place list rows select and focus places, with explicit row actions for editing and deleting saved places; devices can automatically start saved-place check-ins from authorized current location when Settings > Places auto check-in is enabled, and automatic rows stay labeled and confirmable.
- **Map place creation:** The Places map can create saved places in context. Clicking or tapping an empty map location drops a draft marker; the user must name and save it before it becomes a `RoutinePlace`. Existing map feature taps continue to select those features instead of creating overlapping drafts.
- **Device activity:** Routina records per-installation device sessions and lightweight action-origin logs for user-initiated database mutations. Watch-originated actions preserve Apple Watch as the source device even when relayed through iPhone. Settings exposes active devices as an informational section.
- **Mac Places:** The active Mac Places architecture is [0021](0021-keep-mac-places-in-home-split-shell.md), superseding the 0017-0020 presentation chain. Places stays inside the shared Home split-view shell: the sidebar keeps the shared mode strip and swaps task filters/list for place controls, check-in history, and saved places; the detail column renders the map.
- **Mac Home toolbar:** Global Home toolbar content generally belongs to the root split-view shell, not the sidebar column. The Done counter is the explicit exception: it belongs to the sidebar toolbar beside the system collapse control while the sidebar is expanded. Detail-specific controls may still be attached by detail views. The Home window uses full-size transparent titlebar with unified toolbar styling.
- **Mac Home check-in:** Mac place check-in is a compact Home toolbar menu instead of a large bottom sidebar dock. The menu keeps map, activity, suggested-place, active-place, and end-check-in actions.
- **iOS Home actions:** iOS Home exposes place check-in and sleep in the expanded top-right action rail instead of floating bottom controls. The check-in action opens the map/check-in sheet, and detailed place, activity, active-session, and history controls stay inside that sheet instead of a persistent Home banner.
- **Mac Home navigation history:** Mac Home keeps per-window Back/Forward history snapshots across sidebar mode, sidebar selection, selected task, settings section, board scope, and detail mode. `Command-Left Arrow` goes back, `Command-Right Arrow` goes forward, and choosing a new destination after going back clears the forward stack.
- **Home task row visibility:** Users can choose which Home task row fields are visible from Settings > Appearance > Task Row, including separate controls for the task-specific row tint/background and the row-edge color badge. The default is the full row, and the preference stores hidden fields so newly added row fields appear by default.
- **Home goal filtering:** Home task filters include goal presence as a shared, per-tab filter with All, Has Goal, and No Goal options. The filter applies to visible and archived task lists and persists with the rest of the Home task filters.
- **Task and timeline media filtering:** Home task filters and Timeline/Done filters share a media filter with All, Any Media, Image, and File options. Home task lists apply it to task image/file presence. Timeline applies it to media-bearing timeline evidence: task image/file/voice, standalone note image/file/voice, and place check-in images. Sleep entries remain excluded when a media filter is active.
- **Task voice notes:** Tasks can store one optional M4A voice note directly on `RoutineTask` using external SwiftData storage plus duration and creation metadata. Add/edit task forms record, replace, remove, and preview the note; task details play it back. Backup/import, CloudKit direct pull repair, task sharing, and iCloud usage estimates preserve voice notes. Timeline media filters include task voice notes as media evidence; Home task filters remain image/file focused.
- **Place check-in images:** Place check-ins can store one optional compressed image as external SwiftData storage on the session. The Places history editor adds, replaces, and removes that image, and backup packages preserve it as a session-linked attachment file.
- **iOS Home top actions:** The compact iOS Home top-right actions expand horizontally inside the navigation bar, mirroring the left task-list mode control. Quick Add is not part of this action group because task creation lives on the iOS Task tab action. The group keeps icon-first Filters, Add Note, Check In, and Going to sleep controls, and chosen actions collapse the group before opening their flow.
- **iOS task creation tab:** iOS exposes task creation as a tab bar Task `+` action between Search and Timeline. Selecting it switches to Home and opens the unified smart task add flow rather than persisting Add Task as a real app tab. The smart flow accepts quick natural-language text, previews parsed fields, saves directly when possible, and keeps Details available for the full progressive task form.
- **Mac smart task title:** macOS keeps Add Task in the full task form, but the title field accepts the same quick-add syntax as iOS. When the typed title contains detected metadata, the form shows a readable preview with an Apply action, and Save applies uncommitted parsed metadata before creating the task.
- **Goal hierarchy:** Goals can link to one parent goal, giving each goal a derived set of sub-goals. The hierarchy is stored as an optional parent goal ID, prevents self/descendant cycles, and is included in backup, import, CloudKit pull repair, and goal detail UI.
- **Goal editing:** Goal add and edit flows render inline in the Goals main/detail surface instead of a sheet or popover. The shared goal editor draft remains the source of truth, and saving selects the saved goal before reloading the Goals list.
- **Goal tags:** Goals store tags with the shared `RoutineTag` normalization and newline-backed storage model. Goal tags appear in goal editing/detail/search, participate in backup/import and CloudKit direct pull, and are included in Settings tag management.
- **Goal task suggestions:** Goal details suggest unlinked tasks that share one or more goal tags. Accepting a suggestion links the task to the goal; rejecting one stores a dismissed task ID on that goal so it stays hidden across reloads, backup/import, and CloudKit direct pull repair.
- **Routine schedule and format:** Routine forms separate schedule behavior (Due or Gentle) from routine format (Standard, Checklist, or Runout). Due routines can become due or overdue; Gentle routines stay visible and resurface without overdue pressure. The persisted schedule mode remains the combined value, including soft checklist and soft runout modes, and code should branch through helper properties rather than matching individual enum cases when it means behavior or format.
- **Platform baseline:** Routina targets the current Apple platform SDK baseline only. App, extension, test, and package targets should move together with the installed verified toolchain, use Swift 6, and avoid older-OS compatibility paths.
- **Liquid Glass UI:** Custom app cards, panels, chips, and floating controls use shared Liquid Glass surface modifiers with semantic tinting. Standard system structures stay system-native, and custom opaque backgrounds behind macOS split-view chrome should be avoided.
- **iOS More navigation:** Compact iOS uses an app-owned More tab for Goals, Stats, and Settings instead of UIKit's automatic overflow More controller. The More flow owns the compact secondary destinations, and compact/regular presentation is chosen from SwiftUI size classes.
- **Git settings visibility:** Git contribution settings are opt-in from Settings > General > Advanced. When Git features are disabled, the standalone Git settings section is hidden from Settings navigation.
- **Support and About settings:** Support contact actions and About/version diagnostics share one Settings section named Support & About. Legacy Support navigation state should route to the combined section instead of showing a separate destination.
- **Progressive task forms:** Task creation and editing show identity and scheduling first, keep populated optional sections visible, and tuck empty optional fields behind More Details. Task detail hides empty optional sections and exposes compact Add More actions for comments, linked tasks, and richer details.
- **Optional task checklists:** Checklist items can attach to any task type. Checklist and runout routine formats keep their schedule/completion semantics, while checklists on standard routines and one-off todos are optional progress items that do not complete the task by themselves or change scheduling. Standard routine optional checklist progress resets when the routine completes; todo checklist state stays with the todo.
- **Standalone notes:** Standalone notes are SwiftData `RoutineNote` records with optional title, body, image, voice data, shared normalized tags, and linked `RoutineNoteAttachment` file records. Home add controls can create notes, and Timeline shows notes as first-class entries under a Notes filter. Timeline tag filtering, Settings tag management, related-tag learning, backup/import, reset, duplicate cleanup, and iCloud usage estimates include note data, note media, and note tags.
- **Emotion logs:** Emotion logs are standalone SwiftData `EmotionLog` records with pleasantness and energy values, one or more emotion families/details, intensity, optional body areas/reflection, and optional links to notes, goals, tasks, places, and sleep sessions. Emotion capture uses explicit Pleasantness and Energy segmented pickers instead of a chart-based mood map, and suggested emotion families stay inside the selected pleasant/unpleasant and low/high energy quadrant. iOS Home actions and the macOS Home add menu can create emotion logs. On macOS, Add Emotion opens in the Home detail area and saving routes to the saved Timeline emotion entry. Emotion detail views can edit the existing log in place without creating a replacement record and can open linked notes, goals, and tasks through app deep-link routing. Timeline shows emotions under an Emotions filter and does not generate insight summaries.
- **Tag identity:** Tags compare case-insensitively and accent-insensitively across tasks, goals, notes, quick add, filters, and settings. When typed input matches an existing tag with different capitalization, the app keeps the existing display spelling instead of creating a visual case variant.
- **Routina deep links:** Routina uses stable app-owned URLs for shareable entity links. Production builds register and emit `routina://task/<uuid>`, `routina://goal/<uuid>`, `routina://note/<uuid>`, and `routina://sprint/<uuid>`; development builds register and emit `routina-dev://...` equivalents so installed dev apps do not steal production links. Opening one shows that entity when it exists locally. On macOS, task, goal, and note links open Home and synchronize the visible Home sidebar row with the linked entity.
- **Mac Home add menu:** The Mac Home sidebar `+` opens a menu with Emotion, Note, Goal, Task, Check In, and Sleep actions. Emotion opens the standalone emotion logger in the main detail area; Note opens the standalone note editor; Goal switches to Goals and opens the inline goal editor; Task opens the existing add-task form; Check In opens the existing Places/check-in workspace; Sleep starts the existing sleep-mode flow. Goals mode does not add a separate toolbar `+`.
- **Mac note creation:** Mac Home presents Add Note in the main detail area instead of a sheet, matching the main-surface creation model used by Add Goal and Add Task.
- **Mac emotion creation:** Mac Home presents Add Emotion in the main detail area instead of a sheet, matching the main-surface creation model used by Add Task, Add Goal, and Add Note. Saving routes to the saved emotion entry in Timeline with the Emotions filter active.
- **Home creation save routing:** After a task, goal, or standalone note is saved from Home, the app routes to that saved entity's detail and synchronizes the visible sidebar row. Creation save routing may clear sidebar search and visibility filters so the saved row is immediately visible.
- **Home tag grouping:** Home list grouping includes a Tags mode alongside Status and Deadline Date. Tags mode groups active unpinned routines and todos by their first normalized tag, puts untagged rows in `No Tags`, keeps Pinned and Archived as special sections, and persists each tag group's collapsed state locally.
- **Timeline row details:** Timeline note rows open note detail, and place check-in rows open a dedicated place check-in detail view across standalone Timeline screens and the macOS Home embedded Timeline. Place detail is read-oriented; correction/editing remains in the existing Places/check-in history surfaces.

## Open Questions

- `docs/routina-features-web.html` is older than the decision log entries for missed outcomes, sleep sessions, and place sessions. Should the public feature guide be updated to describe timeline activity as done, missed, canceled, sleep, and place/session history instead of only completed and canceled work?
- `docs/recurring-window-routines.md` proposes recurring-window and flexible-gap schedules, but no accepted decision record currently adopts that model. Should this be promoted into a numbered decision before implementation?
- [0021](0021-keep-mac-places-in-home-split-shell.md) says the `Details / Planner / Board / Places` picker stays in the detail-column header, while [0022](0022-own-mac-home-toolbar-at-split-shell.md) moves global Home toolbar content to the root split-view shell. Should the mode picker be treated as detail-header content or as global Home toolbar content?

## Records

| ID | Title | Status | Date |
| --- | --- | --- | --- |
| [0001](0001-maintain-project-decision-log.md) | Maintain a Project Decision Log | Accepted | 2026-05-08 |
| [0002](0002-exact-time-routines-miss-after-day.md) | Treat Exact-Time Routines as Missed After Their Scheduled Day | Accepted | 2026-05-08 |
| [0003](0003-resolve-exact-time-missed-assumptions.md) | Resolve Exact-Time Missed Assumptions as Done, Missed, or Canceled | Accepted | 2026-05-09 |
| [0004](0004-macos-task-list-keyboard-navigation.md) | Support Keyboard Navigation in the macOS Task List | Accepted | 2026-05-09 |
| [0005](0005-show-timeline-activity-in-day-planner.md) | Show Timeline Activity in the Day Planner | Accepted | 2026-05-09 |
| [0006](0006-make-planner-timeline-activity-configurable.md) | Make Planner Timeline Activity Configurable | Accepted | 2026-05-09 |
| [0007](0007-show-active-focus-timers-in-planner.md) | Show Active Focus Timers in the Planner | Accepted | 2026-05-09 |
| [0008](0008-confirm-timeline-activity-as-planner-block.md) | Confirm Timeline Activity as Planner Blocks | Accepted | 2026-05-09 |
| [0009](0009-support-routine-time-ranges.md) | Support Routine Time Ranges | Accepted | 2026-05-09 |
| [0010](0010-store-recurrence-rules-in-swiftdata-columns.md) | Store Recurrence Rules in SwiftData Columns | Accepted | 2026-05-09 |
| [0011](0011-open-planner-sidebar-tasks-with-double-click.md) | Open Planner Sidebar Tasks with Double Click | Accepted | 2026-05-09 |
| [0012](0012-model-sleep-as-app-level-session-mode.md) | Model Sleep as an App-Level Session Mode | Accepted | 2026-05-10 |
| [0013](0013-use-neutral-cancellation-styling.md) | Use Neutral Cancellation Styling | Accepted | 2026-05-10 |
| [0014](0014-model-place-check-ins-as-place-sessions.md) | Model Place Check-Ins as Place Sessions | Accepted | 2026-05-10 |
| [0015](0015-support-map-based-place-check-ins.md) | Support Map-Based Place Check-Ins | Accepted | 2026-05-10 |
| [0016](0016-show-place-check-ins-as-day-timeline.md) | Show Place Check-Ins as a Day Timeline | Accepted | 2026-05-10 |
| [0017](0017-show-mac-map-check-in-inline.md) | Show Mac Map Check-In Inline | Superseded | 2026-05-10 |
| [0018](0018-show-mac-map-check-in-in-detail-column.md) | Show Mac Map Check-In in the Detail Column | Superseded | 2026-05-10 |
| [0019](0019-show-mac-places-as-detail-mode.md) | Show Mac Places as a Detail Mode | Superseded | 2026-05-10 |
| [0020](0020-show-mac-places-as-workspace.md) | Show Mac Places as a Workspace | Superseded | 2026-05-10 |
| [0021](0021-keep-mac-places-in-home-split-shell.md) | Keep Mac Places in the Home Split Shell | Accepted | 2026-05-11 |
| [0022](0022-own-mac-home-toolbar-at-split-shell.md) | Own Mac Home Toolbar at the Split Shell | Accepted | 2026-05-11 |
| [0023](0023-edit-place-check-ins-from-day-timeline.md) | Edit Place Check-Ins from the Day Timeline | Accepted | 2026-05-11 |
| [0024](0024-adopt-liquid-glass-ui-surfaces.md) | Adopt Liquid Glass UI Surfaces | Accepted | 2026-05-12 |
| [0025](0025-show-place-check-in-history-markers-on-map.md) | Show Place Check-In History Markers on the Map | Accepted | 2026-05-12 |
| [0026](0026-require-explicit-saved-place-check-in-action.md) | Require an Explicit Saved-Place Check-In Action | Superseded | 2026-05-12 |
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
| [0052](0052-use-compact-ios-home-actions.md) | Use Compact iOS Home Icon Actions | Superseded | 2026-05-25 |
| [0053](0053-record-task-voice-notes.md) | Record Task Voice Notes | Accepted | 2026-05-25 |
| [0054](0054-open-ios-home-top-actions-vertically.md) | Open iOS Home Top Actions Vertically | Accepted | 2026-05-25 |
| [0055](0055-move-ios-home-place-and-sleep-into-action-rail.md) | Move iOS Home Place and Sleep Into Action Rail | Accepted | 2026-05-25 |
| [0056](0056-hide-git-settings-until-enabled.md) | Hide Git Settings Until Enabled | Accepted | 2026-05-25 |
| [0057](0057-merge-support-and-about-settings.md) | Merge Support and About Settings | Accepted | 2026-05-25 |
| [0058](0058-use-progressive-task-forms.md) | Use Progressive Task Forms | Accepted | 2026-05-25 |
| [0059](0059-use-mac-home-sidebar-add-menu.md) | Use a Mac Home Sidebar Add Menu | Superseded | 2026-05-26 |
| [0060](0060-support-standalone-notes.md) | Support Standalone Notes | Accepted | 2026-05-26 |
| [0061](0061-share-stable-routina-deep-links.md) | Share Stable Routina Deep Links | Accepted | 2026-05-26 |
| [0062](0062-present-mac-note-creation-inline.md) | Present Mac Note Creation Inline | Accepted | 2026-05-26 |
| [0063](0063-tag-standalone-notes.md) | Tag Standalone Notes | Accepted | 2026-05-26 |
| [0064](0064-group-home-task-list-by-tags.md) | Group Home Task List by Tags | Accepted | 2026-05-26 |
| [0065](0065-open-timeline-notes-and-places-from-rows.md) | Open Timeline Notes and Places From Rows | Accepted | 2026-05-26 |
| [0066](0066-include-check-in-in-mac-add-menu.md) | Include Check In in the Mac Add Menu | Superseded | 2026-05-26 |
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
