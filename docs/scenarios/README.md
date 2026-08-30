# Regression Scenarios

This directory records app behaviors that must not quietly break again.

Use decision records for why a durable choice exists. Use current-behavior pages for what the app should currently do. Use scenarios here for concrete Given/When/Then expectations that should be protected by tests.

## Rule

A recurring bug fix is not complete until the expected behavior is captured as a scenario and covered by at least one automated test.

## Scenario Format

```md
## Scenario Name

Area: Tasks / Planner / Stats / Settings / Places / Other
Decision links: 0249
Current behavior: ../current-behavior/tasks.md
Coverage:
- Tests/Shared/ExampleTests.swift
- Tests/macOS/ExampleFeatureTests.swift

Given ...
When ...
Then ...
```

If coverage does not exist yet, write `Coverage needed:` instead of `Coverage:` and add the test in the same change whenever practical.

## Initial High-Value Scenarios

### Backup Audit Never Uses A Live Store

Area: Settings / Backup / Developer tooling
Decision links: [0170](../decisions/0170-treat-backup-reset-as-complete-user-data-operations.md), [0693](../decisions/0693-audit-backups-through-isolated-semantic-round-trips.md)
Current behavior: [Settings](../current-behavior/settings.md)
Coverage:
- `Tests/Shared/RoutinaBackupAuditTests.swift`

Given a current `.routinabackup` contains records, relationships, generated media, and file attachments
When the project-local audit runs
Then it validates every declared attachment and restores through the production mappings into an in-memory local-only store
And the source semantic snapshot equals the first isolated restore
And a second isolated restore and export remains semantically identical
And generated media identifiers and export time do not create false mismatches
And live CloudKit pull tokens remain unchanged

Given an attachment is missing, duplicated, unsafe, dangling, symbolic, or not a regular file
When the audit validates the package
Then it fails before starting the isolated restore and identifies the structural problem without printing personal record content

Given the package uses an older supported schema
When the audit imports it
Then the audit labels the operation as migration verification
And requires the migrated result to remain stable across a second round trip without claiming raw source equality

Given the package uses a future unsupported schema
Then the audit refuses it before restore and reports the supported schema range

### Verified Backup And Reversible Restore

Area: Settings / Backup / Restore
Decision links: [0170](../decisions/0170-treat-backup-reset-as-complete-user-data-operations.md), [0694](../decisions/0694-verify-portable-backups-and-preserve-restore-recovery.md)
Current behavior: [Settings](../current-behavior/settings.md)
Coverage:
- `Tests/Shared/SettingsRoutineDataBackupSafetyTests.swift`
- `Tests/Shared/SettingsFeatureTests.swift`

Given Routina exports a current `.routinabackup`
When the isolated restored snapshot exactly matches the source store
Then the package receives a portable source receipt containing its semantic fingerprint, manifest digest, record counts, and attachment digests
And Settings reports the export successful only after that receipt is written

Given a verified package is copied to an empty new device
When the manifest, an attachment, the receipt, or restored semantics changed in transit
Then restore rejects it before changing live data
And an unchanged package can be verified from its receipt without comparing against nonexistent destination data

Given the person selects `Verify Backup` on a device with current local data
Then Routina also compares the package's canonical contents with that local store
And reports match or the first difference without changing either source

Given restore has a structurally valid candidate and existing destination data
When replacement begins
Then Routina first creates a verified recovery point of the destination
And stages all deletion and insertion before one save
And an import failure rolls back to the original saved data without clearing CloudKit pull tokens or applying restored defaults

Given more than ten verified pre-restore recovery points exist
Then Routina retains the ten newest points
And a selected recovery point restores through the same preflight, preservation, and transaction flow
And Settings explains that internal recovery points do not survive app deletion

### Task Effort Fields Stay Independent And Disclosures Stay Honest

Area: Tasks / Focus / iOS and macOS Task Details
Decision links: [0188](../decisions/0188-prefer-self-explanatory-ui-over-instructional-copy.md), [0625](../decisions/0625-group-task-detail-add-detail-with-edit.md), [0652](../decisions/0652-keep-effort-fields-independent-and-disclosures-honest.md)
Current behavior: [Tasks](../current-behavior/tasks.md), [UI](../current-behavior/ui.md)
Coverage:
- `Tests/Shared/TaskDetailSharedViewSupportTests.swift`
- `Tests/Shared/TaskDetailTimeSpentPresentationTests.swift`

Given a task has no duration estimate
When Actual time, Story points, Focus, or any combination of them is configured
Then iOS and full Mac Task Details still offer `Estimate` in `Add a detail`

Given a task already has a duration estimate
Then the field-specific `Estimate` add action is absent

Given active task Focus forces Effort or Focus content open
Then its header has no disclosure chevron or clickable collapse action
When the active session ends
Then the ordinary disclosure control is available again

### Task Effort Editing Distinguishes Values From Capabilities

Area: Tasks / Add and Edit / iOS and macOS
Decision links: [0188](../decisions/0188-prefer-self-explanatory-ui-over-instructional-copy.md), [0652](../decisions/0652-keep-effort-fields-independent-and-disclosures-honest.md), [0653](../decisions/0653-present-effort-values-as-values-not-feature-switches.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskFormPresentationTests.swift`
- `Tests/Shared/TaskFormIOSLayoutRegressionTests.swift`
- `Tests/Shared/TaskFormMacLayoutRegressionTests.swift`

Given a person opens Add Task or Edit Task
When the Effort group is visible
Then Time estimate, Actual time, and Story points use field-specific value actions rather than switches
And each field explains whether it represents planned duration, recorded duration, or relative size
And Focus timer is the only switch because it enables attention-session tracking

Given the task has a 90-minute Estimate and no Actual time
When the person chooses Log for Actual time
Then Actual time starts from its independent 30-minute default
And Estimate remains 90 minutes

Given any one Effort value is added or cleared
Then the other Effort values remain unchanged

### Task Focus Remains Separate From Actual Time

Area: Tasks / Focus / iOS and macOS Task Details
Decision links: [0112](../decisions/0112-show-estimated-actual-time-stats.md), [0651](../decisions/0651-keep-task-focus-separate-from-actual-time.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailSharedViewSupportTests.swift`

Given a todo or routine has task Focus enabled
When the person finishes, edits, or deletes a task Focus session
Then Routina changes only the Focus session evidence
And it does not change the todo's task-level Actual time
And it does not change any routine completion log's Actual time
And iOS and macOS follow the same rule

### Focus Appears On Every Actually Occupied Day

Area: Focus / Planner / Timeline / Stats
Decision links: [0005](../decisions/0005-show-timeline-activity-in-day-planner.md), [0129](../decisions/0129-hide-abandoned-focus-sessions-from-timeline.md), [0691](../decisions/0691-split-focus-activity-across-local-days.md)
Current behavior: [Planner](../current-behavior/planner.md), [Stats](../current-behavior/stats.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`
- `Tests/Shared/RoutineCompletionStatsTests.swift`
- `Tests/Shared/TimelineLogicTests.swift`

Given a task or tag count-up Focus session starts before local midnight
And the person finishes it after midnight
When Routina derives Timeline, Stats, or Planner evidence
Then Timeline shows one row on every occupied local date
And each Stats day and Timeline row includes only its intersecting active duration
And a continuous interval from 23:00 to 03:00 contributes one hour yesterday and three hours today
And Calendar Schedule shows a day-bounded Focus block on every occupied date
And an older stored block that stopped at the first midnight gains its missing continuation without duplicate writes on repeated reconciliation

Given a Focus session was paused yesterday and remained paused overnight
When the person presses Finish today
Then the active time before yesterday's pause remains on yesterday
And Timeline and Stats show no Focus today because Finish itself is not active time

### Mac Task Detail Effort Stays Compact And Reports Focus History

Area: Tasks / Focus / macOS Task Details
Decision links: [0651](../decisions/0651-keep-task-focus-separate-from-actual-time.md), [0653](../decisions/0653-present-effort-values-as-values-not-feature-switches.md), [0657](../decisions/0657-make-mac-task-detail-effort-a-compact-summary-and-action-surface.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailTimeSpentPresentationTests.swift`
- `Tests/Shared/TaskDetailSharedViewSupportTests.swift`

Given a one-off task has completed Focus history but no recorded Actual time
When its Mac Effort card is collapsed
Then the summary reports the Focus total and session count
And it does not make missing Actual time the primary value

Given the Effort card is expanded
Then Actual time and Focus each appear as one compact value-and-action row
And their duration and mode inputs are not permanently mounted

When the person chooses Log time or Add time
Then a focused popover starts from Actual time's remembered independent value
And adding time previews and saves the new total without changing Focus

When the person chooses Start focus
Then a focused popover offers Countdown or Count up
And Countdown starts from its remembered independent duration
And neither the Actual-time nor Focus popover shows a redundant Cancel action

When the person clicks outside either popover before confirming
Then the popover closes without logging time or starting Focus

When the person chooses Count up
Then no countdown duration control is shown

Given Focus is running or another session blocks it
Then running or blocking status replaces Focus start controls
And Actual-time logging remains available

Given completed Focus sessions exist
Then embedded history uses the Focus row for total and session count
And a bounded recent list keeps each duration and edit action together
And it does not repeat Total, Sessions, Latest, accumulated blocks, and Recent count

Given a task has an active or completed Focus session
When the person opens Add/Edit Effort
Then Focus shows its retained session count instead of an off switch
And Task Details keeps Focus visible and available even if legacy enablement is off
When every retained Focus session is deleted
Then the optional Focus switch becomes available again

Given the person uses Planner Plan Focus allocation instead
When they explicitly save a split across selected planned tasks
Then that deliberate attribution may add task time under the separate Planner allocation contract

### Task Creation Remains Unlimited

Area: Tasks / Capture
Decision links: [0583](../decisions/0583-keep-task-creation-unlimited.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/UnlimitedTaskCreationTests.swift`

Given a person already has more than the former free active-task allowance
When they create another task from a detailed or quick creation path
Then Routina saves the task without counting existing tasks
And no purchase paywall, entitlement check, or development override participates

### Task Details Hide Empty Linked Tasks

Area: Tasks / iOS and macOS Task Details
Decision links: [0100](../decisions/0100-reveal-task-form-details-by-section.md), [0366](../decisions/0366-keep-mac-task-detail-add-more-inline.md), [0624](../decisions/0624-hide-empty-linked-tasks-by-default.md), [0625](../decisions/0625-group-task-detail-add-detail-with-edit.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailPlatformActionParityTests.swift`
- `Tests/iOS/TaskDetailFeatureTests.swift`
- `Tests/iOSUI/RoutinaUITests.swift`

Given a task has no resolved linked tasks
When the person opens its iOS or macOS Task Details
Then the Linked Tasks section is absent
And the header's `Add a detail` chooser offers `Linked Task` as the manual relationship entry point

When the task has a resolved relationship
Then Linked Tasks is visible in the normal detail content


### Task Details Group Rich Content Semantically

Area: Tasks / iOS and macOS Task Details
Decision links: [0124](../decisions/0124-support-multiple-task-links.md), [0211](../decisions/0211-support-titled-task-links.md), [0469](../decisions/0469-store-task-descriptions-separately-from-notes.md), [0629](../decisions/0629-consolidate-task-detail-rich-content.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailMacHeaderControlLayoutTests.swift`

Given a task has a titled link and an image
When the person opens Task Details
Then the shared content card identifies `LINKS` and `IMAGE` without a generic `Details` heading
And Mac does not repeat the link in a link-only `DETAILS` header box
And the full image remains in scrolling content instead of displacing the compact task overview


### Task Details Show A Saved One-Off Reminder

Area: Tasks / iOS and macOS Task Details
Decision links: [0185](../decisions/0185-limit-exact-reminders-to-todos.md), [0642](../decisions/0642-unify-task-configuration-and-retire-legacy-task-kind-storage.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailSharedViewSupportTests.swift`

Given a one-off todo has a saved reminder date and time
When the person opens Task Details
Then the status metadata includes a `Reminder` row with that saved date and time
And the person can verify the reminder without opening Edit Task


### iOS Task Details Join Completion And Routine Actions

Area: Tasks / iOS Task Details
Decision links: [0188](../decisions/0188-prefer-self-explanatory-ui-over-instructional-copy.md), [0507](../decisions/0507-clarify-ios-task-detail-action-hierarchy.md), [0643](../decisions/0643-join-ios-task-detail-completion-and-routine-actions.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailPlatformActionParityTests.swift`
- `Tests/Shared/TaskDetailFeatureCompletionTests.swift`

Given a routine has a primary completion action and related routine actions
When the person opens iOS Task Details
Then completion and the neutral chevron menu share one full-width lifecycle control
And each segment owns its full visual hit target and independent accessibility label
And the top-right task-maintenance overflow remains separate

Given the selected routine day is assumed done
Then a compact `Assumed done` pill replaces the visible instructional paragraph
And `Confirm done` remains the direct prominent action
And the menu lists `Not today — hide until tomorrow` before a divider and the pause actions

### iOS Task Detail History Stays Compact And Correctable

Area: Tasks / iOS Task Details
Decision links: [0645](../decisions/0645-make-ios-task-history-compact-and-actionable.md), [0425](../decisions/0425-make-task-detail-history-optional.md), [0264](../decisions/0264-match-button-hit-areas-to-visual-surfaces.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailPlatformActionParityTests.swift`
- `Tests/Shared/TaskDetailSharedViewSupportTests.swift`

Given History is visible in iOS Task Details
When the person reviews completion activity
Then the History container and rows use neutral surfaces without task-colored glow
And each row shows its outcome once with one semantic icon
And the normal date/time and optional Persian date use separate lines
And time spent appears inline only when a duration was recorded

When the person needs to add time or correct an activity
Then each row exposes a 44-point actions menu with Add/Edit Time and Undo/Remove
And swiping reveals the correction without performing it automatically
And Undo uses orange while destructive removal uses red

Given the same task is open in macOS Task Details
Then its existing desktop History presentation remains unchanged

### Task Destinations Stay Separate From Saved Places

Area: Tasks / iOS and macOS Task Forms and Details
Decision links: [0618](../decisions/0618-keep-task-destinations-independent-from-saved-places.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDestinationTests.swift`

Given a person enters a task destination address and confirms a map result
When the task is saved and later opened in Task Details
Then the address and map coordinate are still present
And the task does not acquire a saved Place link or Places beta dependency

When the person edits the resolved address
Then the map pin is cleared until the new address is looked up

When the person taps Apple Maps or Google Maps on iPhone
Then Routina opens the matching provider URL for the stored address and coordinates


### Home And Task Detail Use The Latest Recorded Completion

Area: Tasks / Home
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/HomeRoutineDisplayFactoryTests.swift`
- `Tests/Shared/HomeTaskListFilteringTests.swift`
- `Tests/Shared/TaskDetailFeatureCompletionTests.swift`

Given a repeating task's legacy `lastDone` summary is older than a recorded
completion log
When Home and Task Detail present the elapsed time since the task was last done
Then both use the newest recorded completion
And Home's elapsed text uses its presentation snapshot's reference date
And the stale summary remains unchanged as the recurrence cursor

### Debug Performance Profiles Survive The Next Launch

Area: Other / Diagnostics
Decision links: [0555](../decisions/0555-preserve-the-previous-debug-performance-run.md), [0554](../decisions/0554-correlate-debug-stalls-with-safe-interaction-trails.md)
Current behavior: [Settings](../current-behavior/settings.md)
Coverage:
- `Tests/Shared/RoutinaPerformanceProfilerTests.swift`

Given a Debug performance profile was flushed before the app stopped
When Routina launches again and begins a new current profile
Then the prior file remains available as the single previous run
And Support & About offers a separate action to share that previous run
And no UI claims the previous run was definitely a crash

### Debug Performance Profiles Correlate Stalls With Safe Interactions

Area: Other / Diagnostics
Decision links: [0554](../decisions/0554-correlate-debug-stalls-with-safe-interaction-trails.md), [0553](../decisions/0553-record-debug-performance-symptoms-for-support.md)
Current behavior: [Settings](../current-behavior/settings.md)
Coverage:
- `Tests/Shared/RoutinaPerformanceProfilerTests.swift`

Given a Debug profile records a high-level interaction before a main-thread stall
When the profile is shared
Then the stall includes the recent fixed interaction category
And the JSON includes no local path or user-provided task or search content

### Mac Backlog Coalesces Update Refreshes

Area: Tasks / Mac Backlog
Decision links: [0546](../decisions/0546-separate-mac-backlog-from-the-radar-sidebar.md), [0418](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/macOS/PerformanceRegressionTests.swift`

Given the Mac Backlog window is open
When CloudKit or another Routina surface produces a burst of persistence changes
Then Backlog does not rebuild its task snapshot for every raw SwiftData save
And it waits for the semantic update burst to settle before performing one refresh
And an automatic refresh does not enter the user-visible loading state
And the manual Refresh Backlog control remains immediately available when no refresh is in progress

### Mac Backlog Keeps Its Hierarchy Reachable and Searchable

Area: Tasks / Mac Backlog
Decision links: [0690](../decisions/0690-place-mac-filters-beside-planner-and-backlog-workspaces.md), [0641](../decisions/0641-create-backlog-sections-from-context.md), [0634](../decisions/0634-unify-mac-workspace-search-and-creation.md), [0633](../decisions/0633-make-mac-backlog-hierarchical-and-searchable.md), [0546](../decisions/0546-separate-mac-backlog-from-the-radar-sidebar.md), [0419](../decisions/0419-nest-custom-subsections-under-super-sections.md), [0418](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/BacklogTaskListPresentationTests.swift`
- `Tests/macOS/BacklogFeatureTests.swift`
- `Tests/macOS/HomeFeatureAddRoutinePresentationTests.swift`

Given a person creates an empty Backlog super section with no active search or filter
When its cached task presentation contains no assigned task
Then the super section remains visible and can immediately create one level of subsection
And either hierarchy level can be collapsed across its full visible header surface

Given a person collapses any Backlog super sections or subsections
When they switch to Planner, Task Ladder, or another main-window workspace and return to Backlog
Then those same hierarchy levels remain collapsed

Given Backlog contains tasks in direct sections, nested subsections, and `Hidden by flag`
When the person enters a query in the persistent top search/create field
Then only matching tasks and their hierarchy are shown
And title, description, notes, destination, tags, Flags, and section path can match
And matching hierarchy is revealed without changing stored disclosure choices
And the Backlog sidebar does not duplicate the top search field

Given a task is visible in the Main task list
When the person opens its `Move to > Backlog` menu
Then Backlog destinations appear beneath one `Backlog` submenu
And a section with subsections opens one additional level
And `New Backlog Super Section…` creates a Backlog section and assigns the selected task
And the Backlog workspace does not show a permanent section-name composer

Given `Read mail` exists on `Radar › Future` and is not in Backlog
When the person searches Backlog for `Read mail`
Then the task appears under `Found outside Backlog` with its real location
And it is not counted as a Backlog result
And clicking its summary opens Task Details
And the person can show it in Planner with the query preserved or move it to an explicit Backlog destination
And task creation is not offered for the existing match

Given a completed one-off task matches a Backlog search
When it appears under `Found outside Backlog`
Then its contextual reveal action says `Show in Timeline` instead of `Show in Planner`
And choosing it opens filtered Timeline activity for the same query

Given Backlog is showing an embedded Task Detail
When the person changes the main workspace to Planner
Then the embedded detail contributes no second native principal title above the shared toolbar
And Routina clears that detail before replacing the Backlog split hierarchy
And the main window reaches Planner without an AppKit split-view constraint crash

Given no task matches a Backlog query
When the person chooses to create it
Then Routina asks for an explicit Backlog section or a deliberate Radar destination

Given Backlog is the active Mac workspace
When the person opens Add Task from New and cancels without saving
Then Routina returns to Backlog instead of showing Planner
And Backlog remains the relaunch destination while the transient Add Task workspace is open

Given Backlog contains Repeating and One-time tasks with different status, creation dates, current Task Ladder values, estimates, media, Tags, and Flags
When the person opens the top-toolbar filter beside the Backlog workspace menu and composes those choices
Then only matching Backlog-owned rows remain in the cached hierarchy
And subsections with no matching rows are omitted
And super sections with neither a direct match nor a matching subsection are omitted
And Planner layers, Timeline outcomes, main-task-list visibility and appearance, grouping, and sorting are absent
And the unfiltered Backlog-owned catalog remains available for Tag and Flag selection
And changing filters never moves tasks or rewrites their Backlog paths
When the person clears the filters
Then deliberately empty Backlog sections and subsections return

Given an active Backlog filter hides a task that matches the current search query
When Routina evaluates search creation and outside-Backlog results
Then the hidden Backlog task still prevents duplicate creation
And it is not mislabeled as `Found outside Backlog`

### Mac Backlog Applies Surface-Scoped Tag Rules to Hidden Tasks

Area: Tasks / Mac Backlog / Sections
Decision links: [0647](../decisions/0647-scope-automatic-section-rules-to-their-surface.md), [0640](../decisions/0640-route-unassigned-backlog-candidates-by-tags.md), [0546](../decisions/0546-separate-mac-backlog-from-the-radar-sidebar.md), [0460](../decisions/0460-match-custom-section-tags-by-any-or-all.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/BacklogTaskListPresentationTests.swift`
- `Tests/macOS/BacklogFeatureTests.swift`

Given an active unfinished task is hidden from normal task lists by a configured Flag
When a Backlog super section has an `Any` or `All` tag rule matching that task
Then the cached Backlog presentation shows the task in the first matching super section
And the task is removed from `Hidden by flag`
And creating the Backlog rule after the task already exists produces the same result

Given the matching hidden task retains an explicit Main task list assignment
When Backlog applies its independent automatic rule
Then the task appears in the matching Backlog super section for presentation
And the stored Main task list assignment remains unchanged for when the hiding Flag is removed

Given a task already has an explicit Backlog section assignment
When another Backlog super section's tag rule matches its tags
Then the explicit Backlog assignment remains authoritative

Given an ordinary Main task list task matches a Backlog tag rule but has no hiding Flag
When Backlog rebuilds its presentation
Then the task is not pulled into Backlog

### Mac Task Ladder Search Preserves Ranking Context

Area: Tasks / Mac Task Ladder
Decision links: [0634](../decisions/0634-unify-mac-workspace-search-and-creation.md), [0632](../decisions/0632-integrate-mac-workspaces-in-the-main-window.md), [0561](../decisions/0561-add-separate-mac-task-ranking-ladder.md), [0418](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskRankingPresentationTests.swift`
- `Tests/Shared/MacWorkspaceNavigationSourceTests.swift`

Given a matching task is nested inside a Task Ladder group
When the person searches from the persistent top field
Then the result reports its group path and current metric value
And choosing `Locate` enters the owning scope, reveals and highlights the ranked row, and does not reorder the Ladder

Given a matching task is excluded by lifecycle, Blocked state, a Flag, its configured entry window, or an unfinished prerequisite
Then the task appears separately under `Outside Task Ladder` with the reason
And an existing global match suppresses creation even when it is outside the active Ladder

### Mac Planner Restores Its Header Choices

Area: Planner / macOS UI
Decision links: [0665](../decisions/0665-persist-mac-planner-header-choices-locally.md), [0654](../decisions/0654-progressively-reveal-mac-planner-header-choices.md), [0609](../decisions/0609-keep-planner-range-choices-actionable-in-compact-headers.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given a person selects Timeline, or selects List while Calendar is active
And they explicitly select Day, 3 Days, or Week
When they switch to another main-window workspace and return to Planner, or relaunch Routina
Then Planner restores the selected Planner view, Calendar task view, and preferred range

Given the saved preferred range is Week
When a narrow Planner width temporarily renders 3 Days or Day
Then the adaptive fallback does not replace the saved Week preference
And Week returns when the Planner becomes wide enough again

### Mac Task Detail Closes Without Historical Refresh Work

Area: Tasks / Planner / Performance
Decision links: [0608](../decisions/0608-keep-mac-task-detail-close-transition-free-of-history-work.md), [0418](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md), [0296](../decisions/0296-present-mac-task-details-as-planner-inspector.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`
- `Tests/macOS/PerformanceRegressionTests.swift`

Given Mac Planner shows a right-side task-detail companion pane and has count-up Focus history
When the person closes Task Details and Planner widens from Day to 3 Days or Week
Then the adaptive range change reloads visible Planner blocks without reconciling all Focus history
And any Focus reconciliation caused by a real data revision saves each changed day at most once
And an identical repeated reconciliation performs no Planner-block save
And a deferred Home routine update waits until the pane transition quiet window has elapsed

### Flag Rules Can Keep Tasks Out Of The Mac Task Ladder

Area: Tasks / Settings / Mac Task Ladder
Decision links: [0570](../decisions/0570-exclude-flagged-tasks-from-mac-task-ladder.md), [0497](../decisions/0497-use-flags-for-task-behavior-rules.md), [0561](../decisions/0561-add-separate-mac-task-ranking-ladder.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/RoutineTagTests.swift`
- `Tests/Shared/TaskRankingPresentationTests.swift`

Given a Flag has the `Hide tasks from Task Ladder` rule
And a task carries that Flag
When any Task Ladder metric builds its presentation
Then the task does not appear or contribute to the ladder count
And the task remains unchanged in Home, Backlog, Planner, Timeline, and Stats
And a Flag that only hides tasks from normal task lists does not hide them from Task Ladder

### Tag Counters Require a Saved Tag

Area: Settings / Tags
Decision links: [0702](../decisions/0702-hide-tag-counter-settings-without-tags.md)
Current behavior: [Settings](../current-behavior/settings.md)
Coverage:
- `Tests/Shared/SettingsTagPresentationTests.swift`

Given the saved-tag catalog is empty
When Tags Settings loads on iOS or macOS
Then Tag Counters is absent
And the empty Saved Tags or All Tags guidance remains visible

Given the first saved Tag becomes available
When Tags Settings refreshes
Then Tag Counters appears with the stored display preference

Given the final saved Tag is removed
When Tags Settings refreshes
Then Tag Counters disappears without resetting that preference

### Built-In Flags Replace Configurable Rules

Area: Settings / Flags
Decision links: [0703](../decisions/0703-keep-ios-settings-platform-relevant-and-adaptive.md), [0701](../decisions/0701-retire-pre-release-flag-migration-guidance.md), [0636](../decisions/0636-replace-configurable-flags-with-built-in-behaviors.md), [0497](../decisions/0497-use-flags-for-task-behavior-rules.md)
Current behavior: [Settings](../current-behavior/settings.md)
Coverage:
- `Tests/Shared/SettingsFlagRulePresentationTests.swift`
- `Tests/Shared/SettingsIOSRelevanceTests.swift`

Given Settings is opened on macOS
When the Flags destination loads
Then it shows exactly the five canonical built-in behavior Flags
And one of them is Hide from Calendar List
And it does not offer custom Flag creation or custom rule editing
And it does not show migration guidance or status for configurable pre-release Flags

Given Settings, Add/Edit Task, Task Details, or a Flag filter is opened on iOS
When Flag choices or assignments are presented
Then Hide from Calendar List is absent
And the other four built-in behavior Flags remain available

Given a task received Hide from Calendar List through Mac synchronization
When that task is edited and saved on iOS
Then the hidden Mac-only assignment remains stored
And it returns unchanged when the task is viewed again on Mac

Given the persisted settings catalog is empty or contains non-canonical entries
When the app launches
Then the catalog is repaired to the five canonical built-in values
And task assignments are not scanned or rewritten

### A Flag Can Keep Tasks Out Of Mac Calendar List

Area: Tasks / Planner / Calendar List
Decision links: [0677](../decisions/0677-centralize-mac-flag-filters-under-shared.md), [0674](../decisions/0674-hide-flagged-tasks-from-calendar-list.md), [0636](../decisions/0636-replace-configurable-flags-with-built-in-behaviors.md), [0369](../decisions/0369-show-day-task-list-columns-in-planner-calendar.md), [0418](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
Current behavior: [Planner](../current-behavior/planner.md), [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/RoutineTagTests.swift`
- `Tests/Shared/DayPlanPlannerStateTests.swift`
- `Tests/Shared/SettingsFlagRulePresentationTests.swift`

Given a task carries the built-in Hide from Calendar List Flag
And that task otherwise belongs in Planned tasks, Assumed done, Confirmed assumed done, or Done for a visible day
When Mac Planner shows Calendar List
Then the task is absent from that section and its count
And the task remains visible in Calendar Schedule and the focused day-task sidebar when their ordinary conditions match
And its assumptions, completions, Timeline, Stats, and stored Planner evidence remain unchanged

Given the Flag is removed from that task
When Calendar List refreshes
Then the task returns whenever its normal date, search, layer, and shared-filter conditions match
And the refresh reuses cached exclusion membership instead of scanning all tasks from scrolling row builders

Given that same Flag remains assigned
When the person selects Hide from Calendar List under Shared Include flags
Then matching tasks deliberately return to Calendar List for temporary review
And selecting an overlapping Shared exclusion hides them because Exclude wins

### Settings Search Opens a Matching Destination

Area: Settings / Navigation
Decision links: [0703](../decisions/0703-keep-ios-settings-platform-relevant-and-adaptive.md), [0637](../decisions/0637-search-settings-by-destination.md)
Current behavior: [Settings](../current-behavior/settings.md)
Coverage:
- `Tests/Shared/SettingsSectionViewSupportTests.swift`

Given Settings is open on iOS or macOS
When the person searches for `backlog` or `sync`
Then Sections or iCloud & Backup remains in the visible destination list
And selecting the result opens the existing Settings detail form
And task content is not searched

Given Settings is open on macOS
When the person searches for `hide`
Then Flags remains in the visible destination list
And its result explains the matching inner behaviors: Hide from Task Lists, Hide from Calendar List, Hide from Timeline, and Hide from Task Ladder
And selecting the result opens Flags without changing its controls

Given Settings is open on iOS
When the person searches for `hide`
Then Flags remains in the visible destination list
And its result explains Hide from Task Lists, Hide from Timeline, and Hide from Task Ladder
And it does not advertise Hide from Calendar List

Given Settings is open on iOS
When the person searches for Planner Calendar, Calendar List, or keyboard shortcuts
Then those Mac-only concepts do not create a false Settings result

### iOS Settings Follows Platform And First-Task Availability

Area: Settings / iOS / First Task
Decision links: [0703](../decisions/0703-keep-ios-settings-platform-relevant-and-adaptive.md), [0698](../decisions/0698-focus-first-ios-home-on-the-first-task.md), [0279](../decisions/0279-hide-sleep-stats-and-blocking-with-away-toggle.md)
Current behavior: [Settings](../current-behavior/settings.md)
Coverage:
- `Tests/Shared/SettingsIOSRelevanceTests.swift`
- `Tests/Shared/SettingsSectionViewSupportTests.swift`

Given iOS Settings Calendar is open
Then Calendar task review/import and Persian-date display remain available
And the Mac Planner Calendar section is absent

Given a new iOS installation has not yet observed a task
When General or Shortcuts Settings opens
Then Home task-type configuration and Mark Done are absent
And Quick Add, Start Focus, Today, Calendar task import, and other task-creation or global controls remain available

Given the installation later observes a task through creation, import, restore, or synchronization
Then Home task-type configuration and Mark Done appear
And deleting every task later does not hide them again

Given Away or Sleep is disabled
When iOS Shortcuts Settings opens
Then Shake to start sleep mode, Sleep, and Wake Up are absent
And they return only when both parent features are available

Given charge repeating tasks are disabled
When General Settings opens
Then the disabled low-battery threshold is absent
And enabling charge repeating tasks reveals the threshold control

### Mac Task Ladder Rows Show Task Identity Metadata

Area: Tasks / Mac Task Ladder
Decision links: [0571](../decisions/0571-show-task-identity-metadata-in-mac-task-ladder.md), [0561](../decisions/0561-add-separate-mac-task-ranking-ladder.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskRankingPresentationTests.swift`

Given tagged one-off and repeating tasks appear in a Task Ladder value section
When the person compares their rows in any ladder metric
Then each row shows its assigned tags instead of repeating the section's metric value
And each non-one-off row shows a visible `Repeating` label with the repeat symbol
And a one-off task without tags does not reserve an empty metadata line

### Repeating Due Tasks Gain Temporary Task Ladder Weight

Area: Tasks / Mac Task Ladder / Recurrence
Decision links: [0649](../decisions/0649-give-each-task-ladder-metric-an-independent-time-rule.md), [0592](../decisions/0592-derive-time-based-task-ladder-values-from-repeating-due-dates.md), [0575](../decisions/0575-inherit-task-ladder-group-values-from-actionable-tasks.md), [0561](../decisions/0561-add-separate-mac-task-ranking-ladder.md), [0418](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskRankingPresentationTests.swift`

Given a repeating Due routine has stable After done values and independent higher targets
When one metric is `Only on due date`
Then Task Ladder Now keeps its After done value before due and uses its target on the due date and while overdue
And the stored After done value remains unchanged

Given one metric has its own gradual before-due window
When calendar days advance through that window
Then Now advances through categorical values toward that metric's target
And it reaches the target on the due date

Given one metric changes gradually while overdue
When the task reaches its due date
Then that metric still has its After done value
And it advances one categorical level after every configured number of full overdue days

Given a task repeats two days after completion
When a before-due policy requests seven days
Then the effective window is capped to two days
And the next occurrence starts at its After done value

Given the current occurrence has an adjusted Now value
When the occurrence is completed and the next due date advances beyond its lead window
Then Now returns to Base without a cleanup mutation

Given Task Ladder is showing Now
Then effective value sections are read-only
And an adjusted task row explains its due timing
And an inherited container group uses its actionable direct children's Now values

Given a task is Gentle, cadence-free, or one-off
When Task Ladder resolves its values
Then no Changes over time rule changes its Base value

### Due Tasks Enter Task Ladder At Their Chosen Time

Area: Tasks / Task Ladder / Recurrence
Decision links: [0692](../decisions/0692-control-when-due-tasks-enter-task-ladder.md), [0649](../decisions/0649-give-each-task-ladder-metric-an-independent-time-rule.md), [0634](../decisions/0634-unify-mac-workspace-search-and-creation.md), [0438](../decisions/0438-allow-early-completion-of-untimed-scheduled-routines.md), [0418](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskRankingPresentationTests.swift`
- `Tests/Shared/AddRoutineFeatureTests.swift`
- `Tests/Shared/TaskDetailEditSaveTests.swift`
- `Tests/Shared/TaskFormMacLayoutRegressionTests.swift`
- `Tests/Shared/TaskFormIOSLayoutRegressionTests.swift`

Given a repeating Due task keeps the default `Throughout` choice
When any Task Ladder metric builds its presentation
Then a future due date alone does not exclude the task

Given a repeating Due task is configured to enter a chosen number of days before due
When it is one day outside that boundary
Then every Task Ladder metric and count omits the task
And explicit Task Ladder search reports when it will enter
When the next local day reaches the boundary
Then the cached Ladder presentation includes the task without a manual refresh

Given a repeating Due task is configured to enter `On due date`
When its due date is still in the future
Then Task Ladder omits it even when it has the shortest Estimated time
When the due date arrives or becomes overdue
Then Task Ladder includes it

Given a one-time task has a deadline and a before-due entry window
When its deadline is outside or inside that window
Then Task Ladder applies the same exclusion or inclusion boundary without capping the window to a recurrence interval

Given a one-time task has no deadline, or a routine is Gentle or cadence-free
Then Add Task and Edit Task omit the entry-window control
And saving normalizes any stale entry-window value to `Throughout`

Given a task is outside its Task Ladder entry window
Then Home, Backlog, Planner, Calendar, Timeline, Stats, notifications, and completion behavior remain unchanged
And an untimed scheduled occurrence can still be completed early

Given an existing task stores the former direct Changes over time JSON
When the person saves a Task Ladder entry window
Then both the legacy temporal rule and the new entry choice remain readable and synchronized

### Mac Task Ladder Header States Each Concept Once

Area: Tasks / Mac Task Ladder / UI
Decision links: [0666](../decisions/0666-keep-mac-task-ladder-chrome-context-specific.md), [0634](../decisions/0634-unify-mac-workspace-search-and-creation.md), [0632](../decisions/0632-integrate-mac-workspaces-in-the-main-window.md), [0188](../decisions/0188-prefer-self-explanatory-ui-over-instructional-copy.md)
Current behavior: [Tasks](../current-behavior/tasks.md), [UI](../current-behavior/ui.md)
Coverage:
- `Tests/Shared/TaskRankingPresentationTests.swift`

Given the person opens the root Mac Task Ladder
Then the global workspace menu is its only visible `Task Ladder` title
And the compact Ladder control bar shows metric, direction, item count, `Add Group`, and refresh
And the root list starts with value sections instead of another title and sort-description block
And read-only section meaning remains available to accessibility without visible `Read only` or `Separate` captions

Given Estimated time is selected
Then the sort control states `Shortest first` or `Longest first` once
And its value sections are named `Has estimate` and `No estimate`

Given the person enters a nested group
Then one local back-and-group-title row identifies that scope
And the global controls continue to own direction and count

Given a container group's details are visible
Then its subtitle states only its actionable task count
And one concise sentence explains that its tasks complete independently

### Mac Task Ladder Separates Placement From Completion

Area: Tasks / Mac Task Ladder / Relationships
Decision links: [0587](../decisions/0587-keep-task-ladder-activation-in-deliberate-editing-flows.md), [0578](../decisions/0578-separate-task-ladder-details-from-inner-navigation.md), [0576](../decisions/0576-offer-direct-repeating-task-ladder-grouping.md), [0574](../decisions/0574-separate-task-ladder-placement-from-completion.md), [0409](../decisions/0409-add-manual-can-complete-task-links.md), [0561](../decisions/0561-add-separate-mac-task-ranking-ladder.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskLadderOrganizationTests.swift`
- `Tests/Shared/TaskRankingPresentationTests.swift`
- `Tests/Shared/TaskDetailFeatureCompletionTests.swift`
- `Tests/Shared/AddRoutineFeatureTests.swift`
- `Tests/Shared/TaskLadderGroupActivationFeatureTests.swift`
- `Tests/Shared/TaskDetailSharedViewSupportTests.swift`

Given Walk and Gym are placed inside the task Exercise
When the root Task Ladder builds any metric presentation
Then Exercise appears once and Walk and Gym do not appear as root rows
And the Exercise row reports its actionable nested-task count

Given Exercise is an existing repeating task with no nested tasks
When the person chooses `Use Repeating Task as Group…` from the group-add control or Exercise row
And adds Walk with a separately chosen completion behavior
Then Exercise keeps its repeating-task schedule and history
And Walk is placed inside Exercise without creating a container-only group
And the Task Ladder opens Exercise's nested ladder

Given Exercise is being created or edited as a repeating task
When the person turns on `Use as Task Ladder group`
Then Exercise keeps its repeating-task schedule, completion behavior, and history
And its empty nested ladder can be opened before any task is placed inside it
And the activation is synchronized with the rest of the Task Ladder organization

Given Exercise is open in macOS Task Details
When the person reviews its available information and actions
Then `Use as Task Ladder group` is not shown
And the person can use Edit Task when they deliberately want to change that role

Given Exercise already has nested tasks
When the person edits the task and views the Task Ladder group switch
Then it remains on and cannot be turned off until those tasks are moved elsewhere

Given Exercise is a task-backed group and Company is a container-only group
When the person single-clicks either row in Task Ladder
Then the right side shows Exercise's normal task details or Company's group details
And the current ladder scope does not change
And exactly the clicked row shows the selection tint
Given `Read about testosterone` and `Tax declaration` are ordinary rows
And `Read about testosterone` was previously selected
When the person selects `Tax declaration`
Then the right side shows `Tax declaration` details
And `Read about testosterone` loses its selection tint
And only `Tax declaration` remains tinted
When the person selects another task or group after scrolling through lazy rows
Then the previous row loses its tint
And only the newly selected row remains visibly selected
Given `Read about testosterone` is selected while Pressure is visible
When the person switches to Urgency and then selects `Tax declaration`
Then Task Details shows `Tax declaration`
And `Read about testosterone` loses its selection tint
And exactly one Urgency row, `Tax declaration`, remains tinted

Given `Buy airpods` is blocked by `Plan and think about USA trip`
And the prerequisite is paused without ever completing or fulfilling its chain step
When Task Ladder publishes a replacement cached presentation
Then `Buy airpods` is absent from every visible metric section and the item count
And the Mac split view replaces the old row membership and count together
And it does not reset the scrolling container to apply that snapshot

When the person double-clicks either group row
Then Task Ladder opens that group's inner ladder
And the context menu also offers explicit details and inner-ladder commands

Given Exercise is a task-backed Task Ladder group
And Walk is an actionable task linked to Exercise in either relationship direction
And Walk is not already a direct child and can be placed there without a cycle
When the person opens Exercise's nested ladder
Then Walk appears as a linked-task child suggestion with its existing relationship type
When the person accepts the suggestion
Then Walk is placed inside Exercise without changing or removing its task relationship
And the suggestion row is replaced by an ordinary Ladder row without stale Accept or Reject controls
When the person instead rejects the suggestion
Then the synchronized parent/task dismissal hides it without unlinking either task
And manually placing Walk inside Exercise clears that dismissal

When the person opens Exercise
Then the nested ladder contains only its actionable placed tasks
And its manual tie-break order is independent of the root and another parent
And Walk may independently use no completion rule, `Can complete`, or `Completes`

Given Company is a container-only Task Ladder group
And several independent obligations are placed inside it
When one obligation is completed
Then Company records no completion
And the other obligations remain nested inside Company

Given a task only has a `Can complete` relationship and no placement
When the root Task Ladder builds
Then that source task remains a standalone root row

Given a Task Ladder group is deleted
When it contains placed tasks
Then those tasks return to the root
And no task data or history is deleted

Given Learning is an existing container-only Task Ladder group
When the person opens Edit Group for the first time
Then Learning's name, emoji, and current metric choices appear together
When the person changes only one metric
Then Save is enabled
And saving preserves Learning's name and emoji while applying that metric change

### Mac Task Ladder Groups Can Inherit Categorical Values

Area: Tasks / Mac Task Ladder / Groups
Decision links: [0575](../decisions/0575-inherit-task-ladder-group-values-from-actionable-tasks.md), [0574](../decisions/0574-separate-task-ladder-placement-from-completion.md), [0418](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskLadderOrganizationTests.swift`
- `Tests/Shared/TaskRankingPresentationTests.swift`

Given Company inherits Pressure, Urgency, Importance, or Thinking needed
And its actionable direct tasks have different explicit values
When the root Task Ladder presentation is rebuilt
Then Company uses the highest explicit child value for that metric
And excluded or missing-value tasks do not determine the inherited value
And Company appears under `No value` when no actionable direct child has an explicit value
And the cached row metadata explains that the displayed group value is inherited

Given an inherited Company group is reordered inside its current value section
When its tie-break rank changes
Then inheritance remains enabled

Given the inherited Company group is moved across a value-section boundary
When the move is saved
Then the destination becomes Company's explicit value
And inheritance turns off only for that metric

### Mac Task Ladder Lazily Lays Out Individual Rows

Area: Tasks / Mac Task Ladder / Performance
Decision links: [0418](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md), [0561](../decisions/0561-add-separate-mac-task-ranking-ladder.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskRankingPresentationTests.swift`

Given a Task Ladder has enough tasks to extend well beyond the visible window
When the person scrolls to its final rows
Then each task row remains an independently lazy section child
And a metric section does not force SwiftUI to repeatedly measure all of its rows as one tall eager child

### iOS Search Keeps Typing Ahead Of Home Results

Area: Tasks / UI
Decision links: [0541](../decisions/0541-keep-ios-search-input-ahead-of-home-presentations.md), [0557](../decisions/0557-build-ios-search-presentations-off-main-actor.md), [0558](../decisions/0558-activate-ios-search-on-tab-selection.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/IOSScrollingPerformanceRegressionTests.swift`
- `Tests/Shared/HomeTaskListFilteringTests.swift`
- `Tests/iOSUI/RoutinaUIPerformanceTests.swift`

Given a large iOS Home task list
When the person opens Search and types several characters without pausing
Then keyboard input remains immediate
And Home result snapshots update only after a short idle debounce
And full-catalog filtering, sorting, and section construction do not block the main actor

Given 12,000 tasks and a long query that matches none of them
When the person repeatedly opens the keyboard, types the query rapidly, clears it, and closes the keyboard
Then superseded presentation work is cancellable
And the latest empty result keeps the native list host stable while only its empty overlay fades
And clearing does not rebuild full-catalog row-number lookup on the main actor
And Search still matches names, emoji, descriptions, notes, places, tags, Flags, and Goals

Given an active Search query
When the person clears it
Then the unfiltered Home presentation returns immediately

Given the person is on Home, Timeline, More, or another non-Search iOS tab
When that tab is shown
Then it does not display the task Search field

Given the person selects the dedicated bottom Search tab
When Search appears
Then its native Search field is available without replacing the tab host
And the field is focused and the keyboard opens from that single tab tap

### Inactive iOS Tabs Do Not Compete With Search And Home

Area: Tasks / UI
Decision links: [0543](../decisions/0543-defer-ios-sync-refresh-work-until-its-tab-is-active.md), [0418](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/IOSScrollingPerformanceRegressionTests.swift`

Given iOS retains Home, Search, and Timeline destinations in the tab host
When a semantic routine update arrives while one of those destinations is inactive
Then the inactive destination does not fetch SwiftData or rebuild its presentation
And the active destination alone handles the update

Given Home has already established its task snapshot
When an ordinary routine update triggers a Home reload
Then it skips full-history deduplication, backfill, and orphan cleanup


### TestFlight Archives Cannot Skip a CloudKit Production Schema Deployment

Area: Settings / Other
Decision links: [0525](../decisions/0525-gate-testflight-archives-on-cloudkit-schema-deployment.md)
Current behavior: [Settings](../current-behavior/settings.md)
Coverage:
- `Tests/Shared/AppStoreComplianceConfigurationTests.swift`
- `script/cloudkit_schema_guard.sh --check`

Given a stored property or its declared storage type changes in a Routina
`@Model` class after the Production schema was last acknowledged
When an iOS or macOS production build is archived for TestFlight
Then the archive fails before upload and explains how to deploy the Development
schema in CloudKit Dashboard and acknowledge that completed deployment

Given the Dashboard deployment has completed successfully
When the release owner explicitly acknowledges it and commits the updated
manifest
Then the matching production archive can proceed

### Paused Tasks Stay Out of Calendar Scheduling Until Their Expiry

Area: Tasks / Planner
Decision links: [0524](../decisions/0524-pause-tasks-until-a-date.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskPauseUntilTests.swift`
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given an active task is paused until a future date and time
When Calendar scheduling is shown before that timestamp
Then the task does not appear in the task picker or in its automatic, stored, all-day, or date-only task blocks

When that timestamp has passed
Then the task is active again and becomes eligible for its normal Calendar projections

Given a task is paused without an expiry
When Calendar scheduling is shown
Then the task remains absent until the person manually resumes it

### Active Focus Synchronizes During a Cross-Device Refresh

Area: Other
Decision links: [0032](../decisions/0032-sync-active-sleep-mode-across-devices.md), [0545](../decisions/0545-bound-ios-foreground-focus-reconciliation.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/CloudKitDirectPullFocusSessionTests.swift`

Given a Focus session begins on one device while another device has no local Focus session
When the receiving device opens or returns to the foreground
Then it performs a bounded CloudKit reconciliation and shows the active Focus session
And the foreground reconciliation does not replay the private CloudKit history zone

Given a Focus session began on one device and another device has already imported its active state
When the first device stops the session and the other device opens with that stale active record
Then the receiving device performs a bounded CloudKit reconciliation and records the terminal timestamp
And the Focus session no longer appears as active on the receiving device
And a delayed active record cannot reopen a session that is already completed

Given an explicit full sync receives multiple task-deletion tombstones
When it removes their task-backed history
Then it batches the tombstones and scans each related model family once for the pull

### iOS Home Active Focus Banner Opens Complete Controls

Area: Tasks / Focus / iOS Home
Decision links: [0123](../decisions/0123-pause-focus-timers.md), [0127](../decisions/0127-pause-board-focus-timers.md), [0264](../decisions/0264-match-button-hit-areas-to-visual-surfaces.md), [0545](../decisions/0545-bound-ios-foreground-focus-reconciliation.md), [0661](../decisions/0661-make-ios-active-focus-banner-actionable.md)
Current behavior: [Tasks](../current-behavior/tasks.md), [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/ActiveFocusControlSourceTests.swift`
- `Tests/Shared/FocusSessionSupportTests.swift`

Given iOS Home shows an active task, tag, unassigned, or sprint Focus timer
When the person taps anywhere on the visible timer banner
Then iOS opens the active-Focus control sheet for that exact session
And the sheet offers Pause or Resume, Finish, and Abandon
And task Focus also offers Open Task

Given the active Focus began on Mac and was imported to iPhone
When the person changes it from the iOS control sheet
Then the shared Focus mutation records the change for synchronization back to Mac
And Finish preserves completed Focus history
And Abandon removes the active session without completed history

Given another device ended the exact session before an iOS action is applied
When the person attempts an action from the stale sheet
Then iOS reports that the timer changed
And it does not mutate a different active Focus session

### iOS Task Detail Keeps Maintenance Actions Together

Area: Tasks / UI
Decision links: [0584](../decisions/0584-group-ios-task-maintenance-in-navigation-overflow.md), [0507](../decisions/0507-clarify-ios-task-detail-action-hierarchy.md), [0625](../decisions/0625-group-task-detail-add-detail-with-edit.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailPlatformActionParityTests.swift`

Given a task is open in iOS Task Details
When the person opens the top-trailing vertical-ellipsis menu
Then Share Link, Copy Link, and confirmed Delete Task are available there
And an unfinished one-off task also offers Cancel todo under its existing eligibility rules
And Cancel todo is absent from the primary action card
And Delete Task is absent from the iOS Edit Task form
And the grouped pencil remains a direct Edit action
And its adjacent chevron opens the `Add a detail` sheet instead of adding that command to the maintenance menu
And the vertical-dot trigger has a bold, comfortably legible size beside Edit

Given Task Details is hosted from Home or Timeline on iPhone or iPad
When the person taps the visible Add-a-detail chevron surface
Then the task-detail presentation route opens the `Add a detail` sheet
And SwiftUI toolbar rehosting cannot detach the control from its sheet state

### Mac Task Detail Progressively Reveals Task Ladder Value Options

Area: Tasks / macOS Task Details
Decision links: [0563](../decisions/0563-present-importance-and-urgency-as-independent-task-controls.md), [0642](../decisions/0642-unify-task-configuration-and-retire-legacy-task-kind-storage.md), [0644](../decisions/0644-progressively-reveal-mac-task-detail-value-options.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailMacHeaderControlLayoutTests.swift`

Given Mac Task Details shows Importance, Urgency, Pressure, and Thinking needed
Then every field name and current value is visible without showing every alternative
And the controls use intrinsic widths with small fixed gaps instead of equal-width columns
When the person selects a current value
Then that field's complete segmented picker reveals horizontally in place
And controls after it move right while the selected control keeps its leading position
And any previously expanded value picker collapses
When the person chooses an option
Then the new current value remains visible and the picker collapses
And opening another task resets the temporary expansion state
And Reduce Motion applies the same state changes without the transition

### iOS Task Detail Keeps Primary Context Easy To Scan

Area: Tasks / UI
Decision links: [0597](../decisions/0597-show-ios-task-detail-title-after-header-scrolls-away.md), [0595](../decisions/0595-keep-task-completion-colors-consistent-across-platforms.md), [0594](../decisions/0594-simplify-ios-task-detail-scan-and-action-hierarchy.md), [0586](../decisions/0586-group-ios-task-detail-priority-context-in-the-header.md), [0585](../decisions/0585-persist-ios-task-detail-calendar-expansion-per-task.md), [0507](../decisions/0507-clarify-ios-task-detail-action-hierarchy.md), [0625](../decisions/0625-group-task-detail-add-detail-with-edit.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailSharedViewSupportTests.swift`
- `Tests/Shared/TaskDetailDateMetadataPresentationTests.swift`
- `Tests/Shared/TaskDetailPlatformActionParityTests.swift`
- `Tests/Shared/TaskDetailPresentationRoutingSupportTests.swift`
- `Tests/iOSUI/RoutinaUITests.swift`

Given an active todo is open on today's date in iOS Task Details
Then its header shows Status without a redundant `Selected / Today` badge
And its completion action appears before notification context and Calendar
And a standalone completion action does not have an otherwise-empty outer card
And its completion-creating action is green on iOS and macOS

When the primary action would undo a completion or stop ongoing multi-day work
Then its semantic tint is orange on both platforms

When a cadence-free routine offers `Log another completion`
Then that positive completion action remains green

When the person selects another day in Calendar
Then the header adds `Viewing` with that date
And the selected date continues to control eligible completion, undo, checklist, and cancellation behavior

Given Task Details shows Importance, Urgency, Pressure, and Thinking needed for any task
Then the controls retain that order and adaptively wrap at ordinary text sizes
And accessibility text sizes stack the controls with explicit labels, values, strokes, and 44-point-high visible targets

Then the navigation principal remains empty while the full header title is visible
When the full header title scrolls above the detail viewport
Then a text-only task name appears in the navigation principal without an emoji or fixed width cap
When the person continues scrolling until Calendar and later detail sections reach the top of the viewport
Then that navigation title remains visible
And the collapsed-title state replaces the native Edit/Add-detail group with a labeled pencil menu that opens both Edit task and Add a detail
And that explicit compact trigger never becomes an empty, inert button
And scrolling the full title back into view hides that navigation title again
And no scrolling `Add more details` card appears after the visible task content
And the grouped Edit chevron presents the currently available actions in an `Add a detail` sheet

### Task Detail Flags Use Available Width

Area: Tasks / UI
Decision links: [0500](../decisions/0500-move-auto-assume-done-to-flag-rules.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- Tests/Shared/TaskDetailFlagPresentationTests.swift

Given iOS Add Task, Edit Task, or Task Detail shows one or more Flags
When the Flag chips are rendered
Then each chip retains its intrinsic label width and wraps to a later row before truncating

### Mac Task Forms Keep Flags Visible

Area: Tasks / macOS Task Forms
Decision links: [0497](../decisions/0497-use-flags-for-task-behavior-rules.md), [0500](../decisions/0500-move-auto-assume-done-to-flag-rules.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskFormFlagSuggestionPresentationTests.swift`
- `Tests/Shared/TaskFormMacLayoutRegressionTests.swift`

Given Mac Add Task or Edit Task has no organizational tags
And the task has an assigned Flag or Settings has at least one defined Flag
When the progressive form derives its visible sections
Then the combined Tags and Flags card remains visible
And the person can inspect and change the Flag assignment without first using Add More Details

### Task Detail Tags Use Their Intrinsic Width

Area: Tasks / UI
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailTagPresentationTests.swift`

Given a Task Detail has tags whose full labels fit within the header card
When the tag chips are rendered
Then each chip uses its intrinsic width instead of a narrow adaptive grid cell
And tags wrap onto a later row only when their combined widths exceed the card width

### Mac Task Detail Adaptively Groups Tags and Flags Without Mixing Their Meaning

Area: Tasks / macOS UI
Decision links: [0628](../decisions/0628-adapt-mac-task-detail-labels-to-available-width.md), [0627](../decisions/0627-group-mac-task-detail-tags-and-flags.md), [0497](../decisions/0497-use-flags-for-task-behavior-rules.md), [0499](../decisions/0499-explain-applied-flags-in-task-details.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailMacHeaderControlLayoutTests.swift`

Given a Mac Task Detail has at least one assigned Tag or Flag
When its supplementary metadata is shown
Then Tags and Flags appear inside one neutral card
And each present group keeps its own heading and chip treatment
When the complete unwrapped content fits the card
Then the groups share one horizontal row with a vertical divider
When that complete row does not fit
Then the card uses separate labeled rows with a horizontal divider
And each unusually large chip collection may wrap within its own row
And a divider appears only when both groups are present
And Flag chips retain their orange flag semantics without tinting the whole shared card

### iOS Tag Browser Preserves Task Editing

Area: Tasks / UI
Decision links: [0531](../decisions/0531-keep-ios-task-tag-selection-compact-and-searchable.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskFormIOSLayoutRegressionTests.swift`

Given a person is editing or adding a task on iOS
When they open `Browse all tags`
Then the searchable tag picker stays open above the task form
And dismissing the picker returns to the still-open task form with its draft intact

### iOS Filter Tags Reuse The Task Tag Selection Pattern

Area: Tasks / UI
Decision links: [0579](../decisions/0579-align-ios-filter-tag-picker-with-task-tag-picker.md), [0533](../decisions/0533-keep-active-ios-filter-tag-rules-visible.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskFormIOSLayoutRegressionTests.swift`
- `Tests/Shared/IOSScrollingPerformanceRegressionTests.swift`

Given a person opens Filter Tags on iOS
When they inspect, search, add, or remove tag rules
Then the picker uses the same large-title plus/check row pattern as Add Task
And each active tag appears once at the top with its Included or Hidden effect
And Show/Hide plus All/Any remain available without duplicating selected rows
And searching keeps active rules visible while narrowing unselected tags
And returning to Filters shows every selected Hidden and Included tag in a wrapping tag-only summary

### Mac Shared Filters Use Current Task Ladder Values And Searchable Tags

Area: Tasks / Timeline / Planner / macOS UI
Decision links: [0418](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md), [0649](../decisions/0649-give-each-task-ladder-metric-an-independent-time-rule.md), [0656](../decisions/0656-make-mac-all-filters-task-ladder-complete-and-searchable.md), [0660](../decisions/0660-make-mac-planner-filters-explicit-composable-and-bounded.md), [0673](../decisions/0673-use-compact-pickers-for-narrow-mac-filters.md), [0680](../decisions/0680-align-compact-filter-titles-with-equal-width-pickers.md)
Current behavior: [Tasks](../current-behavior/tasks.md), [UI](../current-behavior/ui.md)
Coverage:
- `Tests/Shared/HomeTaskListFilteringTests.swift`
- `Tests/Shared/HomeFilterEditorTests.swift`
- `Tests/Shared/TimelineLogicTests.swift`
- `Tests/Shared/HomeMacAllFiltersSourceTests.swift`

Given a repeating task has lower stored After-done values and higher current
Now values because of Changes over time
When the person selects Task Ladder value filters in Mac `Shared`
Then Task List, task-backed Timeline activity, and task-backed Calendar items
use the current values with independent minimum Importance, Urgency, and
Pressure thresholds, exact Thinking needed, and estimate-presence matching
And standalone Timeline activity is excluded only while a Task Ladder value
filter is active

Given the saved tag catalog is large
When `Shared` Tags appears
Then it has no disclosure card or empty-state copy
And direct tinted Include and Exclude actions stay visible
When either rule has selected tags
Then its removable chips appear beneath the corresponding action
And All/Any appears only for multi-tag rules
When Include tags or Exclude tags opens
Then search, selected tags, bounded suggestions, counts, and a lazy Browse list
make the catalog deliberately available

Given filters are active in one or more Planner filter scopes
When the Mac filter companion pane opens
Then its picker reads `Shared` / `Task List` / `Timeline` / `Calendar`
And active dots expose filtered scopes while the selected scope explains its ownership

Given Timeline contains routine and todo outcome history
When Type `Todos` and Status `Done` are selected
Then both selections remain active and only completed todo history matches

Given the filter pane is expanded fullscreen on a wide Mac window
When its content renders
Then it stays centered within an 840-point maximum and minimizes to the 420-point pane
And segmented choices that fit use one equal-width row instead of compact wrapping
And Task List visibility switches precede Task type with left-aligned labels,
one trailing switch column, and a full-row toggle target
And Task List, Timeline, and Calendar Appearance rows keep left-aligned labels,
one trailing switch column, and a full-row toggle target

Given the same controls render in the 420-point companion pane
When their labels need more width
Then single-choice controls that would wrap use compact menu pickers
And Shared Task Ladder and Task List menu rows keep their titles leading and their pickers trailing on one line
And all of those picker controls have the same width
And controls that already fit one line remain segmented

Given Planner Calendar data and shared filters are unchanged
When SwiftUI reevaluates the Calendar during scrolling
Then cached task membership and ID sets are reused without rederiving current Task Ladder values

### Mac Stats Defers The Tag Catalog To Searchable Pickers

Area: Stats / macOS UI
Decision links: [0418](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md), [0579](../decisions/0579-align-ios-filter-tag-picker-with-task-tag-picker.md), [0656](../decisions/0656-make-mac-all-filters-task-ladder-complete-and-searchable.md), [0658](../decisions/0658-defer-mac-stats-tag-catalog-to-searchable-pickers.md)
Current behavior: [Stats](../current-behavior/stats.md)
Coverage:
- `Tests/Shared/HomeMacAllFiltersSourceTests.swift`

Given the saved tag catalog is large
When the person expands Tags in the Mac Stats sidebar
Then one card shows only active include and exclude chips or empty states
And matching mode appears only for a rule containing multiple tags
And the full include, suggestion, and exclude catalogs do not appear as chip clouds
When the person chooses Add tags or Add tags to exclude
Then the shared searchable picker presents selected, bounded Suggested, and lazy Browse rows as applicable
And existing Stats filter matching and persistence remain unchanged

### Mac Stats Uses Inline Menu Pickers For Single-Choice Filters

Area: Stats / macOS UI
Decision links: [0415](../decisions/0415-support-custom-stats-date-ranges.md), [0599](../decisions/0599-separate-mac-stats-priority-filters.md), [0669](../decisions/0669-use-inline-menu-pickers-for-mac-stats-single-choice-filters.md)
Current behavior: [Stats](../current-behavior/stats.md), [UI](../current-behavior/ui.md)
Coverage:
- `Tests/Shared/MacStatsPriorityFilterPresentationTests.swift`

Given the Mac Stats sidebar is visible
When the person scans Scope, Show, Time Range, Importance, and Urgency
Then each passive card shows a native menu-style picker inline with its title
And every picker keeps its current value visible without expansion state or segmented option surfaces
When the person chooses an ordinary option
Then the filter applies without changing the card height or moving later filters
And Importance and Urgency continue to update independently

Given Time Range is visible
When the person selects Custom
Then inclusive From and Through date fields appear beneath only that row
When the person selects Today, Week, Month, or Year
Then those custom fields disappear and all five single-choice cards remain compact

Given a person uses accessibility navigation
When they reach an inline picker
Then its hidden picker label still names the filter while the adjacent visible card title is not duplicated

### Stats Separates Current Inventory From Selected-Range Activity

Area: Stats / UI
Decision links: [0415](../decisions/0415-support-custom-stats-date-ranges.md), [0668](../decisions/0668-separate-general-stats-and-standardize-task-type-language.md)
Current behavior: [Stats](../current-behavior/stats.md)
Coverage:
- `Tests/macOS/StatsMacDashboardItemAvailabilityTests.swift`
- `Tests/iOS/StatsDashboardItemAvailabilityTests.swift`
- `Tests/Shared/StatsFeatureDerivedStateSupportTests.swift`

Given Stats has both current task inventory and selected-period activity
When the dashboard is presented
Then current Repeating-task, open One-time-task, active-item, archived-item, and goal totals appear under `General Stats`
And activity, focus, wellbeing, and outcome evidence appears under `Date Range Stats`
And Missed stays with Done and Canceled in Date Range Stats
And changing only the selected range does not change General Stats totals

Given Today or a one-day custom range is selected
When created-task evidence exists
Then `Tasks created per day` is omitted because there is no multi-day trend to chart
And a multi-day range makes that chart available again

### iOS Priority Filters Keep Importance And Urgency Independent

Area: Tasks / UI
Decision links: [0581](../decisions/0581-separate-ios-priority-filter-controls.md), [0563](../decisions/0563-present-importance-and-urgency-as-independent-task-controls.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskFormIOSLayoutRegressionTests.swift`

Given iOS Add Task or Edit Task is open
When the person changes Importance or Urgency
Then each field has its own control
And changing one does not implicitly change or mark the other explicit

Given an iOS Home, Stats, or Timeline filter screen is open
When the person scans Priority or opens either threshold
Then Importance and Urgency appear as separate compact rows with dedicated sheets
And changing one minimum threshold preserves the other threshold
And the stored combined threshold retains its existing matching and persistence behavior

Given iOS Home Filters is open
When the person scans Priority
Then Pressure and Thinking needed appear in the same section as Importance and Urgency

### iOS Home Filter Detail Pickers Keep The Main Sheet Compact

Area: Tasks / UI
Decision links: [0537](../decisions/0537-keep-all-ios-home-filter-options-in-persistent-sheets.md), [0535](../decisions/0535-keep-ios-home-filter-details-in-dedicated-sheets.md), [0498](../decisions/0498-filter-task-lists-by-flags.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskFormIOSLayoutRegressionTests.swift`

Given iOS Home Filters is open
When the person needs to change any available filter, including task type,
visibility, status, tags, flags, Importance, Urgency, Pressure, or Thinking needed
Then each control first shows its active value as a compact row
And tapping it opens its dedicated picker sheet without closing Home Filters

Given a Home filter detail picker is open
When the person changes a picker, segmented control, chip, or toggle
Then the change applies immediately
And the detail picker remains open until the person taps Done or dismisses it

Given one or more Flags are selected
When the person opens Filter flags
Then every selected Flag is visible at the top with direct removal
And the remaining cached Flag options are searchable without filtering them from scrolling rows

### Mac Shared Flag Filters Apply Across Task-Backed Surfaces

Area: Tasks / Planner / Timeline / UI
Decision links: [0677](../decisions/0677-centralize-mac-flag-filters-under-shared.md), [0672](../decisions/0672-align-mac-task-and-timeline-flag-filters-with-tags.md), [0660](../decisions/0660-make-mac-planner-filters-explicit-composable-and-bounded.md)
Current behavior: [Tasks](../current-behavior/tasks.md), [Planner](../current-behavior/planner.md), [UI](../current-behavior/ui.md)
Coverage:
- `Tests/Shared/HomeMacAllFiltersSourceTests.swift`
- `Tests/Shared/HomeTaskListFilteringTests.swift`
- `Tests/Shared/TimelineLogicTests.swift`
- `Tests/Shared/DayPlanPlannerStateTests.swift`
- `Tests/Shared/TabFilterStateManagerTests.swift`

Given Mac Shared Filters has available Flags
When no Flag filter is selected
Then direct tinted Include flags and Exclude flags actions are visible without an All Flags chip or inline catalog
And Task List, Timeline, and Calendar do not repeat Flag controls in their own scopes

When the person opens either action
Then a searchable picker keeps selected Flags pinned and remaining Flags in Browse
And selected Flags return as removable chips beneath the owning action
And each side shows All/Any only when it contains multiple Flags

When the person selects Shared Flag rules
Then they apply to Task List, task-backed Timeline activity, Calendar Schedule tasks, and all Calendar List task sections
And standalone Timeline records remain unaffected
And Include deliberately recovers normally hidden matches
And Exclude is evaluated last and wins overlaps
And Stats keeps its independent Flag filters
And Calendar keeps its separate Assumed done layer toggle

### iOS Goal Gate Hides Goal Surfaces

Area: Tasks / UI
Decision links: [0212](../decisions/0212-hide-goals-tab-by-default.md), [0227](../decisions/0227-gate-stats-goal-event-reports.md), [0538](../decisions/0538-gate-ios-goals-and-places-appearance-controls.md)
Current behavior: [Settings](../current-behavior/settings.md), [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskFormIOSLayoutRegressionTests.swift`

Given a task retains one or more linked Goals
And the saved Task Row Appearance choice includes Goals
And `Show Goals tab` is off in iOS Settings
When the person opens Home Filters, views the task on Home, or opens Task Details
Then the Goal filter, row labels, and detail summary are absent
And the linked Goal data and saved Task Row Appearance choice remain unchanged
And enabling the setting restores the Goal filter and linked Goal presentation

### iOS Task Form Tags Preserve Full Labels

Area: Tasks / UI
Decision links: [0531](../decisions/0531-keep-ios-task-tag-selection-compact-and-searchable.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskFormIOSLayoutRegressionTests.swift`

Given an iOS Add Task or Edit Task form shows selected, related, or suggested tags
When a tag label fits in the available Tags section width
Then the chip shows its full label instead of an ellipsis
And chips wrap to a later row only when their combined intrinsic widths require it

### Production Experiment Lockdown Matches Signed Capabilities

Area: Settings / Other
Decision links: [0470](../decisions/0470-keep-beta-experiments-out-of-production.md), [0513](../decisions/0513-defer-ios-screen-time-blocking-until-distribution-approval.md), [0514](../decisions/0514-defer-ios-location-services-until-places-release.md)
Current behavior: [Settings](../current-behavior/settings.md)
Coverage:
- `Tests/Shared/AppStoreComplianceConfigurationTests.swift`

Given an experimental preference was enabled in a previous build or restored from durable preferences
When Routina runs as an iOS or macOS production app
Then the preference resolves to disabled and cannot be written back as enabled
And Support & About does not expose the Beta Experiments panel
And existing experimental user content remains stored for compatibility

Given the Mac production app does not expose Places, voice notes, or browser automation
When its Debug or Release production configuration is signed
Then the bundle omits location, audio-input, and Apple Events entitlements
And development builds retain those capabilities for experiment testing

Given the Family Controls distribution entitlement has not yet been approved
When an iOS production configuration is signed
Then it omits the Family Controls entitlement and the Blocking Settings entry
And the Family Controls implementation remains available only in iOS development configurations

Given Places remains an iOS development experiment
When an iOS production configuration is compiled
Then it has no location usage description or `CLLocationManager` implementation
And its location client returns a no-op snapshot
And iOS development configurations retain the actual location implementation for Places testing

### Embedded macOS MCP Helper Inherits App Sandbox

Area: Other
Decision links: [0517](../decisions/0517-sandbox-embedded-mcp-helper.md)
Current behavior: [Settings](../current-behavior/settings.md)
Coverage:
- `Tests/Shared/AppStoreComplianceConfigurationTests.swift`

Given a macOS Routina archive embeds `RoutinaAIMCPServer`
When the helper is re-signed for App Store distribution
Then it has exactly the App Sandbox and sandbox-inheritance entitlements
And the helper has no independent sandbox capability that would break inheritance

### Embedded macOS MCP Helper Includes Matching Archive Symbols

Area: Other
Decision links: [0520](../decisions/0520-archive-embedded-helper-dsym.md), [0517](../decisions/0517-sandbox-embedded-mcp-helper.md)
Coverage:
- `Tests/Shared/AppStoreComplianceConfigurationTests.swift`

Given a Release macOS archive embeds `RoutinaAIMCPServer` from the Swift Package build
When the embedding phase runs with `dwarf-with-dsym` enabled
Then it generates `RoutinaAIMCPServer.dSYM` in Xcode's dSYM output folder from that helper executable
And the archive contains a dSYM whose UUID matches the embedded helper

### Local AI Product Help Does Not Require Personal Task Access

Area: Settings / Other
Decision links: [0610](../decisions/0610-expose-product-help-through-local-ai-connections.md), [0472](../decisions/0472-broker-local-ai-access-through-an-app-owned-snapshot.md)
Current behavior: [Settings](../current-behavior/settings.md)
Coverage:
- `Tests/Shared/RoutinaHelpCatalogTests.swift`
- `Tests/Shared/RoutinaAIReadOnlySnapshotStoreTests.swift`

Given the Mac MCP connection is configured and Allow read-only task access is off
When an AI client searches Routina help for Task Ladder or the numbers above Planner day columns
Then the helper returns the matching bundled user-facing topic
And it does not load the exported personal task snapshot
And the answer states relevant platform, availability, and behavior limits

Given a person opens Settings > AI Connections
When they review the connection guide
Then it explains setup, product-help and personal-task question examples, read-only limitations, privacy, and recovery
And every copyable example-question surface is clickable across its full visible area

### Settings Groups and Controls Every Actually Pending Notification

Area: Settings / Notifications
Decision links: [0615](../decisions/0615-group-and-control-pending-notification-occurrences.md), [0611](../decisions/0611-list-actual-pending-notifications-in-settings.md), [0412](../decisions/0412-add-advanced-recurrence-beside-simple.md)
Current behavior: [Settings](../current-behavior/settings.md)
Coverage:
- `Tests/Shared/NotificationCoordinatorTests.swift`
- `Tests/Shared/SettingsFeatureDependencyTests.swift`

Given the system has pending Routina notification requests with different trigger times
When the person opens Notifications settings on iOS or macOS
Then Settings groups every request by its originating task or event and orders groups by their earliest request
And expanding a group shows its requests chronologically with title, trigger time, and available explanatory text
And a routine with several rolling Advanced occurrences appears as several rows in one group
And the count represents queued occurrences rather than distinct tasks

Given a task group has several queued occurrences
When the person removes one occurrence
Then only that system request disappears on this device
And later notification reconciliation does not recreate it
And the task, recurrence, sibling occurrences, and other devices are unchanged

Given a queued occurrence has not fired
When the person pauses it with a preset or chosen later time
Then only that request moves to the later time and shows its original time
And later notification reconciliation preserves the replacement time
And the task or event schedule is unchanged

Given no pending request exists
When the list finishes loading
Then Settings explains whether notifications are off in Routina, disabled in system settings, or simply have nothing scheduled
And Planner entries, delivered alerts, and future occurrences not registered with the system are not invented as list rows

### Support Diagnostics Report the Signed CloudKit Environment

Area: Settings / Other
Decision links: [0515](../decisions/0515-report-signed-cloudkit-environment-in-diagnostics.md)
Current behavior: [Settings](../current-behavior/settings.md)
Coverage:
- `Tests/Shared/AppEnvironmentTests.swift`
- `Tests/Shared/SettingsFeatureDependencyTests.swift`

Given a Routina executable is signed with a CloudKit environment entitlement
When Support & About diagnostics are revealed on macOS
Then the signed environment is displayed separately from the configured Data Mode and iCloud Container
And the displayed signed environment is derived from `com.apple.developer.icloud-container-environment`, not inferred from configured values

Given a Routina installation runs on iOS
When Support & About diagnostics are revealed
Then the signed CloudKit Environment explicitly reports that verification is unavailable on iOS
And the app does not infer Development or Production from configured Data Mode or iCloud Container

Given a macOS executable has no readable CloudKit environment entitlement
When Support & About diagnostics are revealed
Then it explicitly reports the entitlement as unavailable or not present

### Support Diagnostics Identify the Exact Build and Are Copyable

Area: Settings / Other
Decision links: [0516](../decisions/0516-make-support-diagnostics-copyable.md), [0526](../decisions/0526-identify-exact-builds-in-support.md)
Current behavior: [Settings](../current-behavior/settings.md)
Coverage:
- `Tests/Shared/AppEnvironmentTests.swift`
- `Tests/Shared/SettingsFeatureDependencyTests.swift`

Given a user reveals Support & About diagnostics on iOS or macOS
When they select `Copy Diagnostics`
Then their clipboard receives one labelled report containing the app version, build number, operating system, CloudKit configuration/signing values, last CloudKit event, and push status
And the report does not contain task content, account identifiers, credentials, or device tokens

Given several TestFlight builds share the same public app version
When a person opens Support & About
Then the Version and Build Number appear as separate values, identifying the installed binary without revealing Diagnostics

Given a CloudKit export or import completes with `partialFailure`
When Support & About diagnostics are copied
Then the CloudKit detail includes the child error code and an anonymized fingerprint for each actionable failed item, up to three items
And it omits record names, record contents, account identifiers, credentials, and device tokens

### Manual iCloud Refresh Does Not Claim Background Upload Success

Area: Settings
Decision links: [0523](../decisions/0523-report-manual-icloud-refresh-honestly.md)
Current behavior: [Settings](../current-behavior/settings.md)
Coverage:
- `Tests/Shared/SettingsFeatureTests.swift`

Given a user selects `Sync Now`
When Routina's direct CloudKit download completes
Then the status confirms that the latest iCloud data was received
And it explains that changes from this device continue syncing in the background
And it does not claim a full sync completed before CloudKit reports an export outcome

### Manual iCloud Refresh Distinguishes Progress From a Stall

Area: Settings / Home
Decision links: [0590](../decisions/0590-use-progress-aware-incremental-manual-refresh.md), [0523](../decisions/0523-report-manual-icloud-refresh-honestly.md)
Current behavior: [Settings](../current-behavior/settings.md), [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/CloudKitSyncDiagnosticsTests.swift`
- `Tests/Shared/SettingsFeatureTests.swift`
- `Tests/Shared/HomeFeatureLifecycleEffectSupportTests.swift`

Given a person selects Settings `Sync Now`, pulls to refresh iOS Home, or selects the Mac Home sync action
When CloudKit continues delivering records beyond 60 seconds
Then Routina keeps the refresh active and Settings or Home shows a linear activity bar plus the exact received-item count
And neither surface invents a completion percentage because CloudKit has not supplied a total item count
But when no CloudKit activity arrives for 60 seconds, Routina cancels the operation and ends visible progress
And a separate three-minute limit ends even a continuously active manual request
And no partial fetch result is merged into the local store
And Settings or Home explains that the existing local data is safe
And the message tells the person to check the connection or iCloud account and try again
And Home reloads the existing local snapshot and presents a `Try Again` action
And after a complete response merges successfully, Routina saves its change token so the next manual refresh requests only newer changes
And a record failure, merge failure, cancellation, timeout, token expiry, cloud reset, or backup import cannot leave a token that skips unmerged data

### Estimated iCloud Usage Respects Feature Availability

Area: Settings
Decision links: [0470](../decisions/0470-keep-beta-experiments-out-of-production.md)
Current behavior: [Settings](../current-behavior/settings.md)
Coverage:
- `Tests/Shared/SettingsSectionViewSupportTests.swift`

Given a Routina feature such as Places, Goals, Events, Emotions, Notes, or Voice Notes is unavailable to the user
When they view Estimated iCloud Usage
Then that feature's category is not listed
And Tasks, Logs, and Images remain visible as released data categories

### Production Uploads Carry Export-Compliance Metadata

Area: Other
Decision links: [0467](../decisions/0467-declare-exempt-encryption-in-production-bundles.md)
Current behavior: [Settings](../current-behavior/settings.md)
Coverage:
- `Tests/Shared/AppStoreComplianceConfigurationTests.swift`

Given the current release uses only exempt Apple platform encryption and SHA-256 for OAuth PKCE
When an iOS or macOS production bundle is built and uploaded
Then its Info.plist declares `ITSAppUsesNonExemptEncryption` as false
And App Store Connect can reuse that answer instead of marking each new build `Missing Compliance`

Given Routina adds custom or third-party cryptography, encrypted communications, or VPN functionality
When the next production release is prepared
Then the export classification must be reassessed before relying on the existing declaration

### Task-Detail Linked-Task Composer Keeps Direction and Actions Clear

Area: Tasks
Decision links: [0631](../decisions/0631-remove-apple-intelligence-task-relationship-suggestions.md), [0630](../decisions/0630-compose-task-relationships-with-grouped-sentence-fragments.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailSharedViewSupportTests.swift`
- `Tests/Shared/TaskDetailEditSaveTests.swift`
- `Tests/Shared/HomeFeatureTaskDetailActionRouterTests.swift`
- `Tests/Shared/HomeFeatureSelectionRouterTests.swift`
- `Tests/macOS/HomeFeatureAddRoutinePresentationTests.swift`
- `Tests/iOS/HomeFeatureAddRoutinePresentationTests.swift`

Given a task with existing relationships is open in iOS or Mac Task Details
When the Linked Tasks card is shown
Then its header shows the resolved relationship count and one `Add` action
And existing relationships are grouped under sentence fragments from the current task's perspective
And the card does not retain a permanent relationship picker or duplicate create/link actions

Given a task with existing relationships is open in iOS or Mac Task Details
When the user clicks the visible section's `Add` button once
Then the Link Task composer opens directly
And no second Linked Tasks editor or duplicate action row is inserted below the section
And the picker lists every other task in Home's loaded catalog except tasks already linked to the open task
And `Create and Link New Task` remains distinct from choosing an existing task

Given a task with no existing relationships is open in iOS Task Details
When the person chooses `Linked Task` from `Add a detail`
Then the same Link Task composer opens
And the person can search for an existing task or create and link a new task

Given the Link Task composer is open
When the person chooses a relationship and an existing task
Then all seven relationship meanings remain available in grouped General, Dependency, Automatic Completion, and Optional Completion menu sections
And the candidate row does not repeat the globally selected relationship
And choosing the candidate does not mutate either task
And Routina explains the directional consequence using both task names
And `Add Relationship` persists the relationship without requiring a separate full Edit save

### Home and Task Detail State Reflect Unresolved Prerequisites

Area: Tasks / Relationships
Decision links: [0596](../decisions/0596-advance-repeating-blocked-by-chains-by-completion-order.md), [0593](../decisions/0593-show-relationship-blocking-in-home-task-rows.md), [0486](../decisions/0486-suggest-confirmed-task-relationships-on-device.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/HomeBlockedStatusBadgeSourceTests.swift`
- `Tests/Shared/HomeActionableFilterTests.swift`
- `Tests/Shared/HomeTaskListFilteringTests.swift`
- `Tests/Shared/CloudKitDirectPullTaskRelationshipTests.swift`
- `Tests/iOS/HomeFeatureTests.swift`
- `Tests/macOS/HomeFeatureTests.swift`
- `Tests/Shared/TaskDetailTodoStateTests.swift`
- `Tests/Shared/TaskDetailSharedViewSupportTests.swift`
- `Tests/Shared/TaskChoiceFeatureTests.swift`

Given a one-off task has a stored State of Ready or In Progress
And it has a confirmed `Blocked by` relationship whose prerequisite is unresolved
When Home presents the task on iOS or macOS
Then its visible Home Status Badge is Blocked rather than To Do or In Progress
And the row reads relationship status from its cached display snapshot instead of resolving the graph while rendering
And an ongoing or step-progress row shortcut cannot override the Blocked badge

Given the same blocked one-off task opens in Task Details
When Task Details presents its State on iOS or macOS
Then the visible State is Blocked
And State is visible even when the person did not reveal that optional control earlier
And Ready and In Progress are not offered while the prerequisite remains unresolved
And relationship-derived blocking does not inherit the stored State's elapsed-time claim
And the stored workflow State and state history remain unchanged

Given every blocking prerequisite becomes done or canceled
When Home and Task Details refresh the relationship status
Then Task Details returns to its previously stored Ready or In Progress State
And the Home Status Badge returns to To Do or In Progress accordingly

Given a task relationship was created on one device
When another device applies that task through direct CloudKit refresh
Then the relationship is restored with the task
And iOS and macOS derive the same Linked Tasks content and Blocked state
And a partial legacy record without relationship storage does not erase a local relationship
And an explicit empty relationship payload removes relationships that were deleted remotely

Given the dependent task is Paused or Done while an unresolved prerequisite exists
When Task Details derives its effective State
Then that stronger lifecycle State remains authoritative

Given repeating task A is Blocked by repeating task B
And B has no completion newer than A's latest completion
When Home, Task Details, or Help me choose derives A's availability
Then A remains Blocked

When B records a newer completion or fulfillment
Then A becomes available for the current chain pass
And A's Home Status Badge no longer says Blocked
And B becoming immediately available again does not re-block A
And pausing B after that completion does not re-block A

When A records a completion newer than B's latest completion
Then that B completion is consumed for the chain
And A's next pass is Blocked until B completes again

Given B is paused before it has completed the current chain step
Then A remains Blocked

### Task Relationship Creation Remains Manual

Area: Tasks / Trust
Decision links: [0631](../decisions/0631-remove-apple-intelligence-task-relationship-suggestions.md), [0630](../decisions/0630-compose-task-relationships-with-grouped-sentence-fragments.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskRelationshipSuggestionRemovalTests.swift`
- `Tests/Shared/TaskDetailEditSaveTests.swift`

Given a person wants to connect two tasks on iOS or macOS
When they open the linked-task composer
Then Routina offers manual relationship selection and task search
And it does not offer Apple Intelligence relationship suggestions
And the Mac application menu has no relationship-review window

When the person selects an existing task
Then Routina explains the directional effect using both task names
And it waits for `Add Relationship` before changing either task

### Cadence-Free Repeating Tasks Stay Reusable

Area: Tasks
Decision links: [0421](../decisions/0421-support-cadence-free-repeating-routines.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskFormPresentationTests.swift`
- `Tests/Shared/RoutineDateMathTests.swift`
- `Tests/Shared/TaskDetailSharedViewSupportTests.swift`
- `Tests/Shared/NotificationCoordinatorTests.swift`

Given a routine is reusable but has no known schedule
When the user chooses `Repeating` and `No schedule`
Then the task saves without an effective cadence and remains available immediately after every completion
And every completion remains in its history
And multiple completions on the same day remain separate history entries
And the task is not classified as a cadence-derived daily routine
And it has no due date, overdue state, cadence badge, or cadence-only form controls
And changing other routine behavior preserves `No schedule`
And Task Detail shows no frequency and no cadence-derived notification is scheduled

### Repeating Behavior Is Composable On Routines

Area: Tasks
Decision links: [0642](../decisions/0642-unify-task-configuration-and-retire-legacy-task-kind-storage.md), [0668](../decisions/0668-separate-general-stats-and-standardize-task-type-language.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskFormPresentationTests.swift`
- `Tests/Shared/RoutineAssumedCompletionTests.swift`
- `Tests/Shared/RoutineDateMathTests.swift`
- `Tests/Shared/AddRoutineFeatureTests.swift`
- `Tests/Shared/TaskDetailEditSaveTests.swift`

Given a user creates or edits a repeating task
When the user selects Gentle behavior
Then Nudges can be turned off independently without removing cadence or history
And an eligible daily Gentle routine can opt into Auto-assume done
And an eligible daily Due routine can also opt into Auto-assume done
And Due makes Gentle-only Nudges unavailable, while `No schedule` makes both behaviors unavailable
And creating the behavior does not require or create a separate task purpose

### Task-Kind Surfaces Match the Domain

Area: Tasks / Stats / Settings
Decision links: [0642](../decisions/0642-unify-task-configuration-and-retire-legacy-task-kind-storage.md), [0668](../decisions/0668-separate-general-stats-and-standardize-task-type-language.md)
Current behavior: [Tasks](../current-behavior/tasks.md), [Stats](../current-behavior/stats.md)
Coverage:
- `Tests/Shared/TaskFormPresentationTests.swift`
- `Tests/Shared/HomeFilterPresentationTests.swift`
- `Tests/Shared/HomeTaskListFilteringTests.swift`
- `Tests/Shared/HomeCustomTaskSectionStorageTests.swift`
- `Tests/Shared/StatsFilterPresentationTests.swift`
- `Tests/Shared/TimelineLogicTests.swift`
- `Tests/iOS/StatsDashboardItemAvailabilityTests.swift`

Given the user opens task creation, Home or Timeline filters, Stats, or Settings
When task-type choices and reports are presented
Then only Repeating and One-time are exposed as task types
And persisted Routine and Todo raw values remain compatible without appearing as task-type labels
And the persisted task-kind and schedule-mode enums contain no third compatibility case
And schema, import, backup, sharing, filters, sections, badges, counts, and dashboard items preserve the same two-kind contract

### Compact And Structured Recurrence Stay Compatible

Area: Tasks
Decision links: [0412](../decisions/0412-add-advanced-recurrence-beside-simple.md), [0430](../decisions/0430-unify-recurrence-editing-behind-lossless-draft.md), [0431](../decisions/0431-present-one-progressive-recurrence-composer.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/RoutineAdvancedRecurrenceTests.swift`
- `Tests/Shared/RoutinaQuickAddParserTests.swift`
- `Tests/Shared/NotificationCoordinatorTests.swift`
- `Tests/Shared/CloudKitDirectPullRecurrenceTests.swift`

Given a routine has compact compatibility values and a structured recurrence payload
When the unified composer edits and saves that routine
Then the lossless draft keeps the authoritative schedule while compatibility projection preserves older readers

Given a structured hourly routine repeats every six hours during a daily window
When two occurrences become due and are completed on the same day
Then each completion is stored at its scheduled occurrence timestamp, log deduplication preserves both, and the routine becomes actionable again at the next due occurrence

Given an existing routine has no structured recurrence payload
When it is decoded or edited
Then it remains compact recurrence with its prior behavior

Given a CloudKit task record contains structured recurrence and simplified compatibility columns
When direct pull merges the task on another device
Then the structured Advanced rule remains authoritative instead of being downgraded to the compatibility cadence

### Untimed Scheduled Routines Can Be Completed Early From Task Detail

Area: Tasks
Decision links: [0438](../decisions/0438-allow-early-completion-of-untimed-scheduled-routines.md), [0445](../decisions/0445-keep-satisfied-occurrences-out-of-day-planning.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailFeatureCompletionTests.swift`
- `Tests/Shared/RoutineAdvancedRecurrenceTests.swift`
- `Tests/Shared/HomeRoutineDisplayFactoryTests.swift`
- `Tests/Shared/HomeTaskListFilteringTests.swift`

Given an untimed monthly routine is scheduled for the 27th
When the user opens Task Detail and marks it done on the 26th
Then the completion is recorded on the 26th
And the satisfied occurrence is recorded as the 27th
And the next due date remains the 27th of the following month

Given that early-completed monthly occurrence reaches the 27th
When Home builds its planning and ordinary task sections
Then the task does not appear in `Today`
And it remains in its ordinary section with the following month's due status

Given the same routine is completed from an entry point that has not opted into early completion
When its scheduled occurrence is still in the future
Then the action remains blocked

Given a routine uses an exact time, a time window, multiple daily occurrences, checklist completion or runout, or a multi-day lifecycle
When its next occurrence is still in the future
Then Task Detail does not apply the untimed early-completion behavior

### Unified Recurrence Draft Preserves Existing Models

Area: Tasks
Decision links: [0178](../decisions/0178-make-recurrence-availability-independent.md), [0412](../decisions/0412-add-advanced-recurrence-beside-simple.md), [0430](../decisions/0430-unify-recurrence-editing-behind-lossless-draft.md), [0431](../decisions/0431-present-one-progressive-recurrence-composer.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/RoutineRecurrenceDraftTests.swift`

Given an existing compact rolling, daily, weekly, or monthly recurrence uses any-time, exact-time, or time-window availability
When the rule enters and exits the unified recurrence draft
Then the recurrence rule and time-window role remain unchanged

Given an existing structured recurrence uses any supported frequency, selector, occurrence time/window, fixed start, time zone, or end condition
When the rule enters and exits the unified recurrence draft
Then every structured field remains unchanged

Given Add Task or Edit Task changes recurrence through the unified draft
When the task is saved
Then persistence resolves the authoritative draft without reconstructing recurrence from narrower legacy fields

Given Add Task or Edit Task displays recurrence
When the user describes an ordinary or fixed-anchor schedule
Then one progressive composer writes the lossless draft without asking the user to choose Simple or Advanced

Given a fixed schedule needs an anchor, time zone, occurrence times, hourly window, or ending condition
When the user builds or reopens it
Then `More schedule options` exposes every active structured field and expands automatically when required

Given a yearly schedule uses several months and several dates
When the user creates or edits it on iOS or macOS
Then every stored month and date remains visibly selected and save preserves their cross-product

### iOS Task Forms Stay Compact and Targeted

Area: UI, Tasks
Decision links: [0058](../decisions/0058-use-progressive-task-forms.md), [0100](../decisions/0100-reveal-task-form-details-by-section.md), [0462](../decisions/0462-use-a-compact-progressive-ios-task-editor.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskFormIOSLayoutRegressionTests.swift`

Given Add Task or Edit Task is open on iOS
When task type, duration, and availability are visible
Then each logical group has its own section without blank divider rows
And every date or time availability option remains readable at phone width

Given an empty optional detail is hidden in the compact form
When the user selects that detail from `Add details`
Then only the chosen section appears and the form scrolls it into view

Given Add Task or Edit Task shows its primary configuration
Then Behavior & Schedule owns timing and completion behavior
And Task Ladder values owns Importance, Urgency, Pressure, and Thinking
And Organization owns Path, Tags, Flags, and repeating-task Task Ladder grouping

Given the task is one-time
Then Changes over time is absent
And the four Task Ladder values remain available

Given the task is repeating but Changes over time is not yet eligible
Then the Task Ladder values section remains visible
And it names the concrete Behavior & Schedule choice required to enable the rule

Given an eligible repeating task is edited on iOS or macOS
Then Importance, Urgency, and Pressure each appear as one sentence
And each sentence selects its After done value, whether it changes, its own timing, its target, and its own days when applicable
And every choice uses a menu picker
And no shared timing control, segmented control, toggle, checkbox, or stepper is shown
When every metric returns to `does not change`
Then the rule is removed

Given the person chooses gradual overdue behavior
Then the sentence says the value rises one level per selected overdue interval
And supporting text says the due-date value is still the After done value

### Wide Mac Task Forms Keep Scheduling Controls Grouped

Area: UI, Tasks
Decision links: [0188](../decisions/0188-prefer-self-explanatory-ui-over-instructional-copy.md), [0429](../decisions/0429-keep-task-list-visible-beside-mac-task-forms.md), [0431](../decisions/0431-present-one-progressive-recurrence-composer.md), [0437](../decisions/0437-compact-wide-mac-task-forms.md), [0439](../decisions/0439-keep-cadence-dependent-controls-after-repeat.md)
Current behavior: [UI](../current-behavior/ui.md), [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/macOS/FormSectionTests.swift`
- `Tests/Shared/TaskFormPresentationTests.swift`
- `Tests/Shared/RoutineRecurrenceDraftTests.swift`

Given Add Task or Edit Task is open in a wide Mac window
When the full form and Behavior section are laid out
Then the cards stay inside a readable maximum width and scheduling controls are not distributed across the complete desktop canvas

Given a routine exposes Due/Gentle behavior
When the Behavior section is displayed
Then its task-list badge preview follows the schedule behavior and completion controls in the main configuration flow

Given the unified recurrence composer is displayed on macOS
When cadence or frequency choices fit horizontally
Then their segments use natural label widths without forced partial rows, while the compact iOS layout may continue to wrap fill-width segments

Given `After done` is selected in the unified recurrence composer
When the interval stepper already states the complete rolling rule
Then the composer does not repeat the same rule in a summary line below it

Given a checklist routine changes Repeat from `No schedule` to `Item runout`
When cadence-dependent settings become relevant
Then Completion and Repeat remain in place and one collapsed `Schedule details` row appears after Repeat
And the Checklist composer places the item title, `Every N days` interval, and Add action together when space permits

Given a daily routine is eligible to switch from `One day` to `Multi-day`
When Multi-day makes the routine non-daily and eligible for Planning
Then Planning appears inside `Schedule details`
And the `Add More Details` palette does not gain or lose a Planning action
And no explanatory copy is added beside the Multi-day selector

Given a Mac user expands `More schedule options` for an optional fixed schedule
When fixed scheduling is off or on
Then one leading-aligned inset panel presents `Fixed schedule` with a mini switch
And the collapsed disclosure summarizes the default or active fixed schedule

Given a recurrence requires fixed schedule details
When `More schedule options` opens automatically
Then the mode row shows `Required` instead of a disabled switch
And only the domain-specific reason for that requirement is explained

Given a desktop weekly, monthly, or yearly schedule has one occurrence time
When its fixed schedule details are shown
Then Start date and At time appear once on the same row
And changing either keeps the hidden fixed-start threshold aligned to that occurrence

### Fixed Recurrence Composes With Time Availability

Area: Tasks
Decision links: [0178](../decisions/0178-make-recurrence-availability-independent.md), [0375](../decisions/0375-split-time-blocks-from-available-windows.md), [0432](../decisions/0432-compose-fixed-recurrence-with-availability-windows.md), [0433](../decisions/0433-identify-subdaily-history-by-scheduled-occurrence.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/RoutineRecurrenceDraftTests.swift`
- `Tests/Shared/RoutineDateMathTests.swift`
- `Tests/Shared/NotificationCoordinatorTests.swift`
- `Tests/Shared/DayPlanPlannerStateTests.swift`
- `Tests/Shared/RoutineAdvancedRecurrenceTests.swift`
- `Tests/Shared/CloudKitDirectPullRecurrenceTests.swift`

Given a fixed date-based recurrence repeats every two weeks on Monday and Wednesday
And its time availability is 18:00 through 21:00
When an occurrence date arrives
Then it becomes actionable at 18:00, closes and becomes missed at 21:00, and the next valid recurrence date keeps the same range
And reminders and Planner time blocks use the same effective start and end
And persistence keeps the complete structured recurrence, range, and range role

Given a fixed daily recurrence has occurrence times at 08:00 and 20:00
And it has one outer availability range from 07:00 through 22:00
When either occurrence is completed, missed, or canceled
Then its log keeps the scheduled occurrence timestamp as identity
And resolving one occurrence does not resolve, replace, or remove the other

Given an hourly recurrence has one outer availability range
When the user tries to save it
Then the form preserves both modules and explains that hourly generation already owns the daily window instead of dropping data

Given a cadence-free one-time task uses an exact time or time window
When its unified recurrence draft is saved
Then the one-day compatibility rule preserves that time availability

Given the draft describes a combination the current recurrence runtime cannot encode without losing information
When the form requests a persistence rule
Then the draft returns an explicit validation issue instead of a partial rule

Given a one-time task has a Date window or a routine has multi-day duration
When recurrence is edited through the unified draft
Then those independent availability and duration values remain outside recurrence and unchanged

### Mac Calendar List Edits The Clicked Done Occurrence From Task Detail

Area: Planner
Decision links: [0435](../decisions/0435-edit-calendar-list-done-times-from-mac-task-detail.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given Mac Planner Calendar is showing `List`
And a recorded Done task row belongs to a particular day column
When the user opens that row in the task-detail companion pane
Then Task Detail shows the exact clicked date with `When` and `Duration` controls
And Save updates that exact completion's timestamp and actual duration
And `When` is the work's start while the stored completion timestamp is start plus duration
And planned and assumed-done rows do not show the completion card
And Planner blocks, other completion occurrences, task recurrence, availability, reminders, estimates, and other days are unchanged
And correcting an existing Done row's time remains in Task Detail rather than becoming an inline List editor

Given that recorded Done task also retains a Planner block at a different time
When Calendar `List` presents the row and Task Detail presents `Done this day`
Then both surfaces derive the completed work's start and duration from the exact completion occurrence
And the separate Planner block keeps its original Schedule placement

### Task Detail Actual Time Can Be Corrected

Area: Tasks
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailEditSaveTests.swift`
- `Tests/Shared/TaskDetailSharedViewSupportTests.swift`

Given a task already has actual time spent recorded
When the person selects `Edit total` in Mac Task Details and saves a lower value
Then the stored actual-time total is replaced by that lower value rather than increased
And clearing the value removes the task-level actual time
And the separate `Add` action remains available for logging additional time

Given the person changes Actual in Edit Task
When the value differs from the saved value
Then Save becomes enabled and persists the correction

### Custom Buttons Use Full Visual Hit Areas

Area: Other
Decision links: [0264](../decisions/0264-match-button-hit-areas-to-visual-surfaces.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage needed:
- UI-level verification that custom/plain SwiftUI buttons respond across their full visible card, chip, row, or pill surface.

Given a custom or plain SwiftUI button has a visible padded card, chip, row, or pill surface
When the user taps or clicks inside that visible surface but outside the text, emoji, or icon glyphs
Then the button action still runs

### Glass Segmented Selections Stay Readable

Area: Other
Decision links: [0024](../decisions/0024-adopt-liquid-glass-ui-surfaces.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage:
- `Tests/Shared/RoutinaLiquidGlassContrastTests.swift`

Given a shared glass segmented control is shown in light or dark appearance
When one of its segments is selected and receives the bright selected glass surface
Then the selected text and symbol use an explicit dark foreground
And the selection does not inherit a dark-appearance primary foreground that disappears into the bright glass

### iOS Home Categorical Filter Sheets Use Grouped Rows

Area: Tasks
Decision links: [0696](../decisions/0696-use-grouped-rows-for-ios-home-filter-choices.md), [0537](../decisions/0537-keep-all-ios-home-filter-options-in-persistent-sheets.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage:
- `Tests/Shared/HomeIOSTaskTypeSegmentLayoutTests.swift`

Given the iOS Home Filters sheet opens Task Type or One-time State
When the person reviews its available choices
Then every option appears as a full-width native grouped row
And the selected row has the native picker checkmark
And Task Type and One-time State rows retain recognizable symbols

Given the iOS Home Filters sheet opens Importance, Urgency, Pressure, or Thinking needed
When the person reviews its available choices
Then every option appears as a full-width native grouped row
And Importance and Urgency spell out their minimum-threshold meaning
And Pressure and Thinking needed distinguish unfiltered `All` from exact-value `None`
And changing one Priority filter preserves the other three filters

### iOS Home Tag Filtering Defers Catalog Work

Area: Tasks / Performance
Decision links: [0418](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md), [0532](../decisions/0532-defer-ios-home-filter-tag-catalog.md), [0533](../decisions/0533-keep-active-ios-filter-tag-rules-visible.md)
Coverage:
- `Tests/Shared/IOSScrollingPerformanceRegressionTests.swift`

Given the iOS Home Filters sheet is open with a large saved-tag catalog
When the person scrolls its ordinary filter controls without opening Tags
Then the sheet renders only the compact Tags entry and does not build the full catalog
And an active hidden tag is named in that compact entry
When the person opens Tags
Then a searchable List-based picker prepares the catalog and lets them edit Show or Hide tag rules
And every selected Show or Hide tag remains visible without changing tabs or searching

### iOS Collapsible Section Counts Stay Readable

Area: Tasks
Decision links: [0200](../decisions/0200-support-task-planned-dates.md), [0202](../decisions/0202-nest-daily-routines-under-mac-plan-today.md)
Current behavior: [UI](../current-behavior/ui.md), [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/HomeIOSSectionHeaderContrastTests.swift`

Given iOS Home shows a collapsible task section such as `Daily Routines`
When its task count is rendered in light or dark appearance
Then the count uses secondary semantic contrast within the already-subdued List section header
And it does not compound that header treatment with a tertiary foreground

### Mac Toolbar Search Does Not Steal Editor Focus

Area: Other
Decision links: [0310](../decisions/0310-show-mac-home-toolbar-search.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage:
- `Tests/macOS/PerformanceRegressionTests.swift`

Given Mac Home search has triggered a toolbar search update
When the user moves focus into a task comment, note, or other text editor before the delayed search-focus repair completes
Then typing stays in that editor instead of jumping back to the toolbar search field

### Mac Task Forms and Search Keep Input Frame-Safe

Area: Tasks / Other
Decision links: [0502](../decisions/0502-keep-mac-task-forms-and-search-input-frame-safe.md)
Current behavior: [Tasks](../current-behavior/tasks.md), [UI](../current-behavior/ui.md)
Coverage:
- `Tests/macOS/PerformanceRegressionTests.swift`

Given Mac Add Task, Edit Task, or inline Add More has several revealed sections
When the person scrolls through the form
Then the form creates off-screen section cards lazily
And form cards, segmented controls, and schedule preview badges use lightweight fills rather than independently composited glass backdrops

Given the Mac toolbar search field is focused
When the person types several characters quickly
Then the native field keeps accepting text without scheduling a first-responder repair after each character
And the global task and timeline presentation catches up after a short idle debounce
And Return still checks the current query before it creates a task

### Development Screenshot Preparation Is Safe and Cross-Platform

Area: Settings / Home / Backlog / Task Ladder / Planner / Timeline / Stats

Decision links: [0465](../decisions/0465-prepare-mac-development-app-for-screenshots.md), [0705](../decisions/0705-refresh-cross-platform-development-screenshot-fixtures.md), [0706](../decisions/0706-gate-disabled-emotions-at-release-presentation-boundaries.md)

Automated coverage:

- `Tests/Shared/RoutinaScreenshotDataSeederTests.swift`
- `Tests/Shared/AppEnvironmentTests.swift`
- `Tests/Shared/SettingsFeatureTests.swift`

Given either development app is launched with the screenshot-data request
When Routina prepares its local development store
Then it inserts or refreshes one coherent date-relative release fixture
And the fixture represents repeating and one-time behavior, Home and Backlog hierarchy, Task Ladder timing, relationships, Flags, destinations, Planner, Focus, Timeline, and Stats activity
And rerunning preparation refreshes only Routina-owned deterministic records and sections without duplicating them or deleting unrelated development data
And the fixture contains no Emotion records
And rerunning preparation removes only its retired reserved Emotion rows while preserving unrelated Emotion history

Given the Mac development app is running
When the user opens Settings -> Appearance
Then `Show development badge` is available and defaults on
And turning it off hides only the orange Home toolbar development badge
And `Generate Screenshot Data` prepares the same managed fixture

Given a production app is launched with the screenshot-data request
Then it rejects the request
And production does not expose a screenshot-data preparation control

### Mac Toolbar Search Expands as One Visible Pill

Area: Other
Decision links: [0321](../decisions/0321-use-focus-expanded-mac-home-toolbar-search.md), [0323](../decisions/0323-draw-mac-toolbar-search-shell-in-swiftui.md), [0329](../decisions/0329-hide-mac-toolbar-actions-during-search-focus.md), [0365](../decisions/0365-refine-mac-toolbar-search-outlook-states.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage:
- `Tests/macOS/PerformanceRegressionTests.swift`

Given the Mac Home toolbar search field is compact and idle
When the user focuses the field and it expands to the focused width
Then the default toolbar shows the compact search pill and normal toolbar actions without a full-width host behind it
And the idle empty pill centers the icon and placeholder with the closed-state color treatment
And clicking the search icon or any empty area inside the visible pill keeps the field expanded and focuses the editor
And the expanded pill uses the active color treatment, wider focused width, and an I-beam cursor across the visible search surface
And non-search toolbar actions hide while the search field is expanded/focused
And the focused search state survives the toolbar rebuild caused by hiding those actions
And no separate focused-width toolbar reservation appears before or behind the animated pill
And the SwiftUI search shell, icon, typed text, placeholder, clear button, create hint, and `Esc` keycap animate as one visible search surface
And pressing the clear button clears the query from the button's expanded hit target before focus expansion can move the pill under the pointer
And clicking outside the visible search pill dismisses focus and collapses search without clearing the query
And task-detail toolbar actions return after the search pill has collapsed to compact width
And the field remains clickable and editable throughout the animation

### Mac Fullscreen Traffic Lights Stay Above Home Content

Area: Other
Decision links: [0022](../decisions/0022-own-mac-home-toolbar-at-split-shell.md), [0340](../decisions/0340-use-swiftui-outlook-style-mac-home-top-toolbar.md), [0341](../decisions/0341-consolidate-mac-home-toolbar-row.md), [0357](../decisions/0357-integrate-mac-fullscreen-titlebar-reserve-into-toolbar.md), [0362](../decisions/0362-place-mac-sidebar-toggle-below-traffic-lights.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage:
- `Tests/macOS/PerformanceRegressionTests.swift`

Given Mac Home is in fullscreen
When the macOS menu/titlebar controls are revealed at the top edge
Then the Home shell keeps the same custom toolbar position instead of moving the layout up or down
And the Home toolbar owns the fullscreen-safe chrome row without a separate blank strip above it
And the sidebar toggle sits below the traffic lights while the other Home toolbar controls start after the leading native traffic-light region
And the sidebar and main content remain below the custom toolbar row
And the traffic lights sit over native titlebar space, not a rounded sidebar or split-view surface
And normal non-fullscreen windows keep the same custom toolbar alignment

### Mac Toolbar Search Creates Only When Search Has No Result

Area: Other
Decision links: [0315](../decisions/0315-merge-mac-quick-add-into-toolbar-search.md), [0378](../decisions/0378-open-mac-add-task-from-toolbar-search-command-return.md), [0389](../decisions/0389-create-task-from-mac-search-empty-state.md), [0619](../decisions/0619-pin-mac-quick-add-details-through-transient-reparses.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage:
- `Tests/macOS/PerformanceRegressionTests.swift`

Given the configurable Mac Quick Add shortcut has focused the Home toolbar search field
When the user enters a non-empty query and presses Return
Then Routina creates a task through Quick Add only if that query has no matching task or Timeline-style result
And the toolbar shows a visible Return-to-create hint for that no-result query
And when that no-result query leaves the task-list sidebar empty, the sidebar uses the Planner Timeline no-results subtext and shows a `Create task` button that opens the full Add Task form with the query in the Identity task-name field
And if the query includes quick-add syntax such as `today`, `every day`, or `#home`, the toolbar shows a flat same-width parser preview below the field before creation without duplicating the Return-to-create hint

Given that Detected details preview has appeared for a confirmed no-result create candidate
When live search refreshes or the current non-empty parser input becomes temporarily incomplete
Then the existing rectangle remains mounted in the same position
And its newest valid content updates in place
And an unparsable intermediate value shows `Updating details…` without stale interactive controls
And a confirmed existing task or Timeline-style result dismisses the rectangle

### Quick Add Recognizes Explicit Day-Month Dates and Bare 24-Hour Times

Area: Tasks
Decision links: [0072](../decisions/0072-unify-ios-task-add-and-quick-add.md), [0074](../decisions/0074-parse-mac-add-task-title.md), [0315](../decisions/0315-merge-mac-quick-add-into-toolbar-search.md), [0616](../decisions/0616-interpret-unqualified-quick-add-dates-as-availability.md)
Current behavior: [Tasks](../current-behavior/tasks.md), [UI](../current-behavior/ui.md)
Coverage:
- `Tests/Shared/RoutinaQuickAddParserTests.swift`
- `Tests/macOS/HomeMacToolbarQuickAddSubmissionTests.swift`
- `Tests/iOS/IOSSmartAddDetectedChipsTests.swift`

Given the reference date is Thursday, 20 August 2026
When the person enters `Physiotherapist Tuesday, 25 August 15:00` through a shared Smart Add or Quick Add surface
Then the parser returns the task name `Physiotherapist`
And it sets one-off `At date` availability to Tuesday, 25 August 2026
And it sets `At time` availability to 15:00
And it does not infer a deadline or reminder
And the parser preview recognizes scheduling metadata before the task is saved
And Mac toolbar Quick Add offers no reminder, one hour, two hours, one day, and custom date/time choices before creation

When the person selects two hours before and presses Enter from the attached Quick Add preview
Then the created task stores a reminder two hours before its exact availability time
And reopening Edit Task shows that reminder enabled with the saved time
And clicking the Reminder control or choosing one of its menu items keeps the search pill and parser preview open
And interacting with the custom date picker also keeps the parser preview open

When the person selects two hours before and then appends `#health` or another character to the same Quick Add composition
Then the reparsed preview keeps the two-hours-before choice
And replacing or clearing the task starts with no reminder

When the person clicks elsewhere in the same Home window or presses Escape
Then the search pill and parser preview dismiss together

When the person instead enters `Submit claim by 25 August 15:00`
Then Quick Add creates a deadline at that date and time
And it still does not infer a separate reminder

When the same input is entered through iOS Smart Add
Then the Detected section includes an `Available` row with the parsed date and time
And the Add action remains enabled for the parsed task

### Editing Exact Availability Into A Time Range Inherits The Start

Area: Tasks / Task Forms
Decision links: [0197](../decisions/0197-separate-todo-date-and-time-availability.md), [0375](../decisions/0375-split-time-blocks-from-available-windows.md), [0185](../decisions/0185-limit-exact-reminders-to-todos.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskFormPresentationTests.swift`
- `Tests/Shared/RoutineRecurrenceDraftTests.swift`

Given a one-off task has `At date` availability on 25 August and `At time` availability at 15:00
And its reminder is set to two hours before that availability
When the person changes Time availability to `Time block` or `Available window`
Then the new range starts at 15:00 and uses the standard three-hour initial range
And the reminder remains two hours before 15:00
And switching the mode does not replace the saved reminder with a new custom time

### Quick Add Turns a Pasted Link Into an Editable Named Task

Area: Tasks
Decision links: [0074](../decisions/0074-parse-mac-add-task-title.md), [0211](../decisions/0211-support-titled-task-links.md), [0315](../decisions/0315-merge-mac-quick-add-into-toolbar-search.md), [0617](../decisions/0617-generate-editable-quick-add-titles-from-pasted-links.md)
Current behavior: [Tasks](../current-behavior/tasks.md), [UI](../current-behavior/ui.md)
Coverage:
- `Tests/Shared/RoutinaQuickAddParserTests.swift`
- `Tests/Shared/AddRoutineFeatureTests.swift`
- `Tests/macOS/HomeMacToolbarQuickAddSubmissionTests.swift`
- `Tests/macOS/PerformanceRegressionTests.swift`

Given the person pastes only a public YouTube URL into Quick Add
When the shared parser runs
Then it removes the whole URL before interpreting tags, places, dates, and times
And it attaches the URL as a task link
And it immediately proposes `Watch YouTube video` as an editable fallback title

When Mac toolbar metadata resolves before creation and the person has not edited the title
Then the preview replaces the fallback with a task-friendly page-specific title such as `Watch: Better Mobility`
And it preserves the resolved page title on the task link

When the person edits the proposed task title
Then a later metadata result does not replace that edit
And appending `#watch` or another character keeps that edited title
And the unchanged URL does not start another metadata request
And Return creates the task with the title currently displayed
And the submitted title comes from the same immutable preview snapshot as any selected reminder

When metadata is unavailable, unsafe to fetch, still loading, or fails
Then Return remains available without waiting
And the task keeps its editable deterministic fallback and attached link
And Routina never renames the task after creation

Given text appears beside the URL
When Quick Add parses the input
Then that text remains the task title rather than being replaced by webpage metadata

### Mac Toolbar Search Shows Every Eligible Suppressed Task Match

Area: Tasks / Planner
Decision links: [0591](../decisions/0591-include-suppressed-mac-search-matches-beside-ordinary-results.md), [0310](../decisions/0310-show-mac-home-toolbar-search.md), [0387](../decisions/0387-keep-completed-scheduled-blocks-visible.md), [0405](../decisions/0405-show-hidden-scheduled-task-search-results.md)
Current behavior: [Tasks](../current-behavior/tasks.md), [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/HomeTaskListFilteringTests.swift`

Given Mac Home toolbar search is non-empty
And Planner Calendar can show a matching task-backed scheduled block
And the normal left task-list sections hide that task because it is already done or otherwise suppressed from active placement
When the task-list sidebar renders no rows or also renders other ordinary matches
Then the sidebar shows a search-only `Search Results` section with the suppressed matching task row
And it does not duplicate a task already shown in an ordinary or `Hidden by flag` section
And normal task-list section membership remains unchanged when search is cleared

### Mac Home Sidebar Toggle Keeps Detail Panes Stable

Area: Other
Decision links: [0343](../decisions/0343-add-mac-home-sidebar-collapse-control.md), [0344](../decisions/0344-clamp-mac-home-sidebar-width.md), [0345](../decisions/0345-raise-mac-home-minimum-width-for-sidebar-restore.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage:
- `Tests/macOS/PerformanceRegressionTests.swift`

Given Mac Home is showing Planner beside a right-side companion pane at its minimum window width
When the user expands the collapsed left sidebar from the top toolbar control
Then the Home split view restores the clamped left sidebar with the normal sidebar animation
And clicking anywhere inside the toolbar control's fixed target triggers the sidebar action
And the Home window frame does not grow or jump during that animated restore
And the detail area does not animate off the right edge
And the right-side companion pane remains inside the window while the sidebar visibility changes
And the right-side companion pane keeps a stable background brightness while the sidebar visibility changes
And task-detail surfaces do not brighten, duplicate, or ghost while the pane expands to Full Details or minimizes back

### Daily Checklist Progress Resets

Area: Tasks
Decision links: [0249](../decisions/0249-reset-daily-checklist-progress.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/iOS/HomeFeatureTests.swift`
- `Tests/Shared/TaskDetailFeatureCompletionTests.swift`

Given a daily checklist-completion routine has partially checked items today
When the app derives routine state tomorrow
Then stale partial checklist progress is ignored and the next day starts unchecked

### Completed Daily Checklist Ignores Stale Partial Progress

Area: Tasks
Decision links: [0249](../decisions/0249-reset-daily-checklist-progress.md), [0253](../decisions/0253-guard-checklist-detail-mutations-through-reloads.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/HomeRoutineDisplayFactoryTests.swift`
- `Tests/Shared/HomeTaskHelperTests.swift`
- `Tests/Shared/SwiftDataModelTests.swift`
- `Tests/Shared/TaskDetailFeatureCompletionTests.swift`

Given a daily checklist-completion routine has a completed log for today and stale partial checklist-progress IDs
When the app derives Home or Task Detail checklist state for today, receives the final checklist item tap followed by a stale Home task reload, receives a duplicate checklist item toggle, or receives stale completed task/log evidence after Undo
Then stale or cleared in-progress IDs are ignored, completed-day checklist rows stay checked/read-only without blinking unchecked first, and Undo keeps rows unchecked without flashing back to completed

### Checklist Runout Past-Day Updates

Area: Tasks
Decision links: [0240](../decisions/0240-keep-checklist-runout-item-actions-item-scoped.md), [0328](../decisions/0328-allow-past-day-checklist-runout-updates.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/HomeTaskHelperTests.swift`
- `Tests/Shared/TaskDetailFeatureCompletionTests.swift`
- `Tests/Shared/TaskDetailSharedViewSupportTests.swift`

Given a checklist runout routine has an item due yesterday
When the user selects yesterday in Task Details and checks that item
Then the item is reset using yesterday as the done date, the selected-day row appears checked, and future selected dates remain unavailable for runout updates

### Task Detail Checklist Removal Appears Immediately After Save

Area: Tasks
Decision links: [0069](../decisions/0069-support-optional-task-checklists.md), [0253](../decisions/0253-guard-checklist-detail-mutations-through-reloads.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailEditSaveTests.swift`
- `Tests/Shared/HomeFeatureTaskDetailActionRouterTests.swift`

Given Task Details is editing a routine or task with checklist items
When the user removes every checklist item and saves the edit
Then the selected detail state and Home selected row drop the checklist immediately while persistence and reloads catch up

### Repeating Task Auto-Assume Uses Day-Level Completion

Area: Tasks
Decision links: [0259](../decisions/0259-allow-daily-checklist-auto-assumed-completion.md), [0428](../decisions/0428-compose-tracking-behaviors-on-gentle-routines.md), [0489](../decisions/0489-expand-auto-assume-done-to-scheduled-repeats.md), [0492](../decisions/0492-allow-auto-assume-done-for-one-off-scheduled-blocks.md), [0494](../decisions/0494-allow-auto-assume-done-for-rolling-after-completion-routines.md), [0510](../decisions/0510-confirm-auto-assumed-one-off-time-blocks-as-planned-intervals.md), [0528](../decisions/0528-suppress-notifications-for-auto-assumed-tasks.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/RoutineAssumedCompletionTests.swift`
- `Tests/Shared/HomeRoutineDisplayFactoryTests.swift`
- `Tests/iOS/HomeFeatureTests.swift`
- `Tests/macOS/HomeFeatureTests.swift`
- `Tests/Shared/TaskDetailFeatureCompletionTests.swift`
- `Tests/Shared/DayPlanPlannerStateTests.swift`
- `Tests/Shared/TaskFormMacLayoutRegressionTests.swift`
- `Tests/Shared/TaskDetailFlagSuggestionTests.swift`
- `Tests/Shared/NotificationCoordinatorTests.swift`

Given a daily Gentle checklist-completion routine has auto-assume done enabled
When today's availability starts and no checklist item progress exists
Then Home and Task Detail present the routine as assumed done without pretending individual checklist items are checked
And the Home task-row status badge says `Assumed`, even when the shared display also treats the assumed occurrence as done for list placement
And on Mac the hover confirm and missed buttons overlay the trailing row content without reserving permanent horizontal space

Given a daily Gentle routine is created today with auto-assume done enabled
When today's availability has already started
Then Home treats the current occurrence as assumed done while dates before creation remain unassumed

Given the user starts checking checklist items for that daily occurrence
When the app derives assumed completion state
Then manual partial checklist progress suppresses assumed-done presentation until the routine is fully completed or progress is cleared

Given a weekly time-block task has Auto-assume done enabled
When its scheduled weekday and start time have passed
Then that occurrence is presented as assumed done
And days without a scheduled occurrence are not assumed done

Given a Standard `On schedule` routine repeats every two weeks on Tuesday
When the user assigns an Auto Assumed Done Flag
Then Routina accepts the Flag because the schedule has one occurrence per day

Given a Standard one-off task has one exact availability date and a scheduled Time block
When the user enables Auto-assume done and the block's start time passes
Then only that one date is presented as assumed done
And a date window, Available window, all-day task, exact time, steps, or checklist items keeps the toggle unavailable

Given that assumed one-off Time block runs from 12:00 to 15:00
When the user confirms it
Then Task Detail keeps its scheduled date and 12:00–15:00 range visible as Schedule metadata
And its recorded Done is specific-time work ending at 15:00 with a 180-minute actual duration
And the Mac Calendar List `Done this day` editor initializes to a 12:00 start, 180-minute duration, and 15:00 end

Given a Standard `After done` routine has Auto-assume done enabled with a two-day interval
When the user confirms completion on day 3
Then day 5 is the first assumed offer, and each later day remains assumed done until one is confirmed
And a manual completion on day 4 instead makes day 6 the next assumed offer
And the user can confirm only one assumed day at a time, never all prior offers in bulk

Given an eligible `After done` routine becomes assumed done while Home remains open
When the user enables `Hide assumed-done tasks`
Then Home refreshes the current assumed-completion state and omits that task from the Task List

Given an auto-assume behavior is active for a task
When Routina reconciles that task's notifications
Then it schedules neither a due alert nor a direct reminder for the task

### Planner Can Show Assumed Done Routines

Area: Planner
Decision links: [0268](../decisions/0268-show-assumed-done-routines-in-planner.md), [0368](../decisions/0368-hide-assumed-done-calendar-layer-by-default.md), [0372](../decisions/0372-hide-completed-tasks-from-calendar-schedule.md), [0489](../decisions/0489-expand-auto-assume-done-to-scheduled-repeats.md), [0642](../decisions/0642-unify-task-configuration-and-retire-legacy-task-kind-storage.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanCalendarFilterStateTests.swift`
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given an eligible daily Gentle routine has auto-assume done enabled
When Planner derives automatic activity for an assumed-done day
Then the routine is available as synthetic completed planner activity without creating a completion log

Given Planner Calendar filters are at their defaults
When Calendar filters automatic activity for display
Then synthetic assumed-done activity and automatic recorded-completion activity are hidden from the editable Schedule grid

Given an assumed-done task has a task-backed time or all-day Calendar block
When its Calendar visibility preference remains at the default
Then the task-backed block stays visible in Calendar

Given that same task enables `Hide assumed-done blocks from Calendar`
When Calendar renders an assumed occurrence
Then its task-backed block is hidden while its assumed-done review activity remains available

Given Planner Calendar filters are at their defaults
When the user opens the right-side day task list for an assumed-done day
Then the sidebar can show the synthetic activity in its `Assumed done` section

Given the user enables the Calendar `Assumed done` layer
When Calendar filters automatic activity for display
Then synthetic assumed-done activity can appear in day agenda and Calendar `List` review without creating Schedule or Needs Time blocks

Given the user hides that assumed-done planner activity
When Planner derives automatic activity again
Then the synthetic assumed-done activity stays hidden for that task and day

### Completed Scheduled Blocks Stay Visible

Area: Planner
Decision links: [0387](../decisions/0387-keep-completed-scheduled-blocks-visible.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given a task-backed timed Schedule block exists for a day
When that task day is completed or fulfilled
Then the Schedule block remains visible for that day

Given a task-backed all-day Schedule block exists for a day
When that task day is completed
Then the all-day block remains visible for that day

### Planner Time Blocks and Available Windows Stay Distinct

Area: Planner
Decision links: [0009](../decisions/0009-support-routine-time-ranges.md), [0199](../decisions/0199-support-multiday-routine-start-flow.md), [0373](../decisions/0373-treat-window-availability-as-non-schedule-placement.md), [0375](../decisions/0375-split-time-blocks-from-available-windows.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given a routine is scheduled with a 10:00-10:15 available window and no duration estimate
When Planner refreshes exact timed calendar blocks
Then Planner does not create a default timed Schedule block for that window

Given the same routine has an explicit duration estimate
When Planner refreshes exact timed calendar blocks
Then Planner still does not create a default timed Schedule block for that window

Given a routine is scheduled with an 18:30-20:00 time block
When Planner refreshes exact timed calendar blocks
Then Planner creates a default timed Schedule block from 18:30 to 20:00

Given Planner previously created a matching scheduled block for an available-window routine
When Planner refreshes that later day
Then the stale scheduled block is removed while manually moved or resized blocks for that routine remain

### Dense Planner Hours Preserve Exact Short Durations

Area: Planner
Decision links: [0454](../decisions/0454-adapt-planner-hour-heights-to-visible-density.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`
- `Tests/macOS/PerformanceRegressionTests.swift`

Given twelve sequential Planner blocks each have an exact five-minute duration within one clock hour
When Calendar `Schedule` renders that visible range
Then that hour expands enough for every block to keep the minimum interactive visual height without overlapping its sequential neighbor
And the other hours retain their normal base height
And every block remains five minutes in storage, labels, conflict checks, drag/drop duration, and completion data

Given a dense hour is expanded in any visible day column
When the Planner shows Day, 3 Days, or Week
Then every visible column uses the same expanded height for that clock hour
And grid lines, cards, scroll anchors, current time, slot selection, drop targets, and resize calculations share one time axis

Given the user drags or resizes a short block
When visible density changes during that interaction
Then the active time axis stays frozen until the interaction ends so the pointer target does not shift

Given Planner rebuilds adaptive geometry
When the visible block snapshot and base spacing are unchanged
Then it reuses the cached axis without fetching or regrouping whole history

### Planner Block Cards Prioritize Visibility Without Reordering

Area: Planner

Decision links: [0622](../decisions/0622-preserve-planner-card-positions-while-prioritizing-visibility.md), [0454](../decisions/0454-adapt-planner-hour-heights-to-visible-density.md)

Current behavior: [Planner](../current-behavior/planner.md)

Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given Mac Planner Calendar `Schedule` shows a timed block in a narrow day column
When the card cannot comfortably fit its title, time or range, and emoji or status icon
Then the original title, time or range, and leading emoji or status icon positions are used whenever all fields fit
And the leading emoji or status icon is omitted before the time or range
And the time or range is omitted before the title
And the title remains visible as the final fallback
And fields that remain visible do not change their original positions
And the block's stored timing, selection, and interaction behavior remain unchanged

### Task Detail Comment Editors Keep Their Insertion Point

Area: Tasks
Decision links: [0098](../decisions/0098-support-markdown-text-editing-controls.md), [0366](../decisions/0366-keep-mac-task-detail-add-more-inline.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage:
- `Tests/Shared/TaskDetailCommentsTests.swift`

Given a person is adding or editing a task comment
When they place the insertion point in the middle of the comment and type multiple characters
Then every character is inserted at that moving insertion point
And a task-detail draft refresh does not move the insertion point to the end of the comment

### Task Detail Metadata Controls Share Their Adaptive Layout

Area: Tasks
Decision links: [0366](../decisions/0366-keep-mac-task-detail-add-more-inline.md), [0468](../decisions/0468-model-task-thinking-needed-separately.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailMacHeaderControlLayoutTests.swift`

Given a macOS Task Detail displays Pressure or Thinking needed
When the task is a one-off task or a routine
Then the controls use the same adaptive layout
And Pressure and Thinking needed sit side by side when the available detail width permits
And the controls stack only when the available detail width is too narrow
And Task Details does not hide the four Task Ladder values behind a disclosure or show a fifth aggregate Priority value

### New Routine Checklists Use Checklist Completion

Area: Tasks
Decision links: [0263](../decisions/0263-promote-new-routine-checklists-to-checklist-completion.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailEditSaveTests.swift`
- `Tests/Shared/TaskDetailCommentsTests.swift`

Given a Standard routine has no checklist items
When the user adds checklist items in Task Details
Then the editor and save path promote it to Checklist completion so checklist completion owns the finish behavior

Given an existing Standard routine already has checklist items from legacy optional data
When the user saves it from Task Details
Then the app preserves the Standard completion mode unless the user explicitly changes it

### Late Completion Stops Overdue Calendar Markers

Area: Tasks
Decision links: [0200](../decisions/0200-support-task-planned-dates.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailCalendarGridSupportTests.swift`

Given a todo was due on June 25 and is logged done on June 26 after the fact
When Task Detail renders the June calendar on June 29
Then June 25 can remain overdue, June 26 shows done, and June 27 through June 29 do not stay overdue

### Selected Timed Occurrence Can Be Resolved After Prior Occurrence

Area: Tasks
Decision links: [0003](../decisions/0003-resolve-exact-time-missed-assumptions.md), [0009](../decisions/0009-support-routine-time-ranges.md), [0447](../decisions/0447-resolve-selected-timed-occurrences-in-task-detail.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailFeatureCompletionTests.swift`
- `Tests/Shared/RoutineDateMathTests.swift`

Given a weekly time-window routine has an earlier occurrence already resolved as canceled
When the user selects a later missed occurrence in Task Detail and presses Done
Then Routina records a completed log for the selected occurrence without treating the earlier resolved occurrence as a blocker

Given a weekly time-window routine has unresolved missed occurrences on June 18 and June 25, 2026
When the user selects the later July 2, 2026 occurrence and presses Done
Then Routina keeps June 18 and June 25 visible as unresolved missed days and still lets either selected missed day be resolved directly

Given today's single scheduled time window has ended without a recorded outcome
When the user selects today in Mac Task Detail
Then the top primary action remains an enabled Done action for today's scheduled occurrence
And the calendar card shows eligible Missed and Canceled actions for that same occurrence

### Editing Calendar Routines Preserves All Selected Days

Area: Tasks
Decision links: [0009](../decisions/0009-support-routine-time-ranges.md), [0177](../decisions/0177-separate-interval-and-calendar-repeat-controls.md), [0184](../decisions/0184-label-month-day-fallbacks.md), [0223](../decisions/0223-support-multi-day-calendar-repeats.md), [0412](../decisions/0412-add-advanced-recurrence-beside-simple.md), [0431](../decisions/0431-present-one-progressive-recurrence-composer.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/RecurrenceSelectionPolicyTests.swift`
- `Tests/Shared/RoutineAdvancedRecurrenceTests.swift`
- `Tests/macOS/TaskDetailFeatureTests.swift`
- `Tests/Shared/TaskDetailEditSaveTests.swift`

Given the user creates or edits an On schedule calendar routine on iOS or macOS
When they select several weekdays or several monthly dates
Then the shared selector keeps every selected value and prevents an empty selection

Given a routine repeats on multiple weekdays such as Monday through Friday
When the user reopens the edit form
Then every saved weekday remains selected instead of only the first weekday

Given the user saves that routine from Task Details
When Routina persists the recurrence rule
Then the full weekday set remains on the saved weekly calendar recurrence

Given a routine repeats on multiple monthly dates such as the 1st, 15th, and 31st
When the user reopens the edit form and saves an unrelated change
Then the form is not falsely dirty before that change
And the complete monthly-date set remains on the persisted recurrence rule

Given the user edits a fixed monthly day-of-month rule
When they select several monthly dates
Then every selected date remains editable instead of only the first date

Given the month-day selector shows dates 29, 30, and 31
When the user reviews those choices
Then those adaptive dates have a distinct indicator and nearby explanation that shorter months use their last valid day

Given several selected adaptive dates resolve to the same last day in a shorter month
When Advanced recurrence generates occurrences
Then that timestamp appears once rather than producing duplicate occurrences

### Multi-Day Routine Lifecycle

Area: Tasks
Decision links: [0199](../decisions/0199-support-multiday-routine-start-flow.md), [0246](../decisions/0246-show-multiday-ongoing-range.md), [0463](../decisions/0463-limit-ongoing-entry-to-multiday-routines.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailFeatureCompletionTests.swift`
- `Tests/Shared/TaskDetailCalendarGridSupportTests.swift`
- `Tests/Shared/TaskDetailPlatformActionParityTests.swift`

Given a multi-day routine has not started
When the user starts it, views it while active, stops it, and undoes completion
Then the primary action, active range, completed span, and undo behavior stay consistent

Given a one-day Gentle or checklist-driven routine is open in Task Detail
When lifecycle actions are presented on iOS or macOS
Then neither platform shows a separate `Start ongoing` action

### Today Routines Stay In Today Section

Area: Tasks
Decision links: [0202](../decisions/0202-nest-daily-routines-under-mac-plan-today.md), [0247](../decisions/0247-make-mac-daily-routine-grouping-optional.md), [0266](../decisions/0266-show-calendar-routines-in-plan-today.md), [0406](../decisions/0406-auto-plan-exact-date-todos.md), [0411](../decisions/0411-manage-custom-task-sections-in-settings.md), [0440](../decisions/0440-treat-day-planning-sections-as-additive.md), [0449](../decisions/0449-keep-custom-section-rules-tag-based.md), [0452](../decisions/0452-label-date-planned-tasks-in-their-ordinary-section.md), [0453](../decisions/0453-use-context-menu-actions-to-reorder-mac-home-sections.md), [0456](../decisions/0456-show-resolved-automatic-paths-in-edit-task.md), [0642](../decisions/0642-unify-task-configuration-and-retire-legacy-task-kind-storage.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/macOS/HomeFeatureTaskListModeTests.swift`
- `Tests/iOS/HomeFeatureTaskListModeTests.swift`
- `Tests/Shared/HomeCustomTaskSectionStorageTests.swift`
- `Tests/Shared/HomeMacTaskListSectionOrderTests.swift`
- `Tests/Shared/HomeTaskListFilteringTests.swift`
- `Tests/Shared/TaskFormPresentationTests.swift`

Given Mac Home shows `Today`
When daily routines are loaded with the grouping setting off or on
Then daily routines remain in the today area, visually merged by default and nested only when the setting is enabled

Given Mac Home shows expanded `Today`
When planned rows are visible
Then the header and rows share one full-bleed section surface with square horizontal edges, no colored side borders, and spacing between task cards

Given a Todo has exact `At date` availability
When the user creates or edits it
Then `Plan to do` is active and set to the same date

Given a non-daily routine has an explicit plan date for today or tomorrow
When Mac Home derives the sidebar sections
Then the row appears in `Today` or enabled `Tomorrow` and also remains in its normal Pinned, custom, tag, deadline, or `Future` placement

Given a task belongs to a custom section and also has a planned date
When the user changes either its plan or its custom assignment
Then both values persist and Home shows the task in the matching planning and custom sections

Given a task has an effective date-only plan for today and an ordinary Pinned, custom, or Future placement
When Mac Home renders both copies
Then the ordinary row shows `Planned today` alongside its other secondary labels while keeping its lifecycle status badge
And the row inside Today does not repeat the label

Given a daily or fixed-calendar routine enters Today only because of its cadence
When its ordinary row is also visible
Then the ordinary row is not labeled `Planned today`

Given a user edits a custom super section in Mac Settings -> Sections
When automatic rules are shown
Then only tag routing is available, planned-today and planned-tomorrow options are absent, and legacy saved planned-day rules do not affect placement

Given a custom super section has multiple automatic tags
When its match mode is Any
Then an unassigned task with at least one configured tag appears in that section
When its match mode is All
Then only an unassigned task with every configured tag appears in that section

Given a user types the beginning of a saved tag in a custom section's automatic-tag composer
When a matching suggestion appears
Then pressing Tab completes the tag, committing it renders an individually removable chip, and unsaved chip changes retain the existing Save and Revert workflow

Given several custom super sections exist in Mac Settings -> Sections
When the user scans and edits the catalog
Then compact color-and-summary headers keep one editor expanded at a time, the full header surface toggles disclosure, move and delete actions stay in More menus, and Save or revert controls appear only for unfinished fields
And expanding or collapsing an editor keeps its controls inside the card without a fade or directional slide transition

### Mac Settings Separates Task Section Surfaces

Area: Tasks / Settings / Mac Sections
Decision links: [0639](../decisions/0639-scope-custom-section-names-by-surface.md), [0635](../decisions/0635-separate-mac-settings-section-surfaces.md), [0285](../decisions/0285-clarify-mac-sidebar-section-surfaces.md), [0419](../decisions/0419-nest-custom-subsections-under-super-sections.md)
Current behavior: [Tasks](../current-behavior/tasks.md), [Settings](../current-behavior/settings.md)
Coverage:
- `Tests/Shared/MacWorkspaceNavigationSourceTests.swift`
- `Tests/Shared/HomeCustomTaskSectionStorageTests.swift`

Given the catalog contains custom sections for the Main task list and Backlog
When the user opens Mac Settings -> Sections
Then a segmented picker offers `Main task list` and `Backlog`
And only the selected surface's top-level section cards are shown
And the new-section composer creates a section in the selected surface

When the user reorders a top-level section
Then it moves only among sections in the selected surface
And its existing ID, subsection hierarchy, and surface assignment remain unchanged

When the user switches surfaces
Then an expanded section from the previous surface is no longer shown as expanded
And subsections remain available inside their parent section when that surface is selected

Given `Health` already exists as a top-level section in the Main task list
When the user creates `Health` from the Backlog segment
Then the Backlog section is created because top-level names are scoped to their surface
And attempting to create another `Health` in either surface reuses or rejects the existing same-surface section instead of creating a duplicate

Given a section name or automatic-tag draft is unfinished
When a color, order, neighboring section, or external catalog value is persisted
Then the unfinished local draft survives while untouched fields adopt the new persisted values

Given the Mac Settings window is open
When the user uses its native traffic-light controls
Then minimize, resize or zoom, and native full screen are available while the existing minimum content size remains enforced

Given the standalone Mac Settings window is closed
When the user chooses the app Settings command or presses Command-comma
Then one standard Settings window opens or returns to the front
And the Settings window remains suppressed during ordinary app launch

Given Mac Home shows expanded `Future`
When future task groups are visible
Then the header and groups share one full-bleed section surface while nested tag groups keep their own collapsible surfaces

Given Mac Home shows any collapsed or expanded task-list section or nested group
When the user toggles that disclosure, including a bulk subsection action
Then its contents open or close without an intermediate viewport jump, so the toggled header and the previously visible surrounding sections remain continuously in place

Given a user-created Mac task super section contains a subsection
When the super section is expanded in the left sidebar
Then the subsection uses the same nested card surface and persistent collapse behavior as a built-in tag subsection

Given an active task is assigned directly or automatically tag-routed to a Mac task super section or one of its subsections
When the user pauses that super section from its Home header
Then those assigned tasks pause with their existing task lifecycle semantics and the section stays visible as Paused with a Resume action
And resuming restores only the tasks paused by that section, leaving independently paused tasks paused

Given Mac task-row `Move to` shows custom super sections with and without subsections
When the user opens the menu
Then leaf super sections are direct actions without chevrons, while only super sections that contain subsections open nested menus

Given a Mac custom super-section or subsection header is visible
When the user right-clicks it and chooses `New Task`
Then Add Task opens with that exact custom path visible and selected in Identity

Given Mac Add Task or Edit Task is open
When the user changes `Path` between Automatic, a super section, and a subsection and saves
Then the task's one durable custom-section assignment matches the chosen destination

Given Mac Task Details shows an unassigned task inside its live resolved sidebar path
When the user opens Edit Task
Then the Identity `Path` control shows that same breadcrumb with `Automatic` context instead of `Default`
And saving without choosing an explicit custom destination keeps the custom-section assignment empty

Given Mac task details show a task that is currently inside a sidebar section and nested subsection
When the user clicks the section breadcrumb in the detail header
Then the left sidebar opens in task-list mode, expands both ancestors, selects the task, and scrolls its row into view

Given that task belongs to a `Future` tag or task-kind subgroup below the currently materialized lazy sidebar content
When the breadcrumb locate action runs
Then scrolling stages through the `Future` section and every containing group before targeting the task row, so the final viewport shows the selected row rather than stopping at the `Future` header

Given Mac task details show a task that is currently inside a visible sidebar section
When the detail header is rendered
Then the section breadcrumb appears directly below the task title and above status, completion, and other metadata

Given the Mac Link Task composer shows an existing task and a selected relationship type
When the user chooses `Create and Link New Task`
Then the Add Task form immediately shows the existing task as a linked task using the inverse relationship type

Given Mac Task Details is open from an unfiltered task list
When the user opens Add Task from the toolbar and returns to Tasks without saving
Then the previously opened task detail returns and the task list keeps its previous task-type mode and filters instead of restoring filters associated with that task

Given a weekly or month-day calendar routine is configured for today's weekday or day of month
When Home derives `Today`
Then that calendar routine appears in the existing today list without a separate scheduled-today group, while rolling interval routines stay in the normal due/status sections unless explicitly planned

Given a structured weekly routine repeats every two weeks on Tuesday starting July 21
When Home derives `Today` for the intervening Tuesday, July 28
Then the routine does not appear in `Today`
And it appears when Home derives `Today` for the next anchored occurrence on August 4

Given a weekly or month-day calendar routine has a canceled occurrence for today
When Home derives `Today`
Then that routine no longer appears in the today plan for the canceled day

Given the Mac `Show Tomorrow section` task-list setting is off
When a task is planned for tomorrow
Then it remains inside `Future` instead of creating a top-level `Tomorrow` section

Given the Mac `Show Tomorrow section` task-list setting is off
When a task row context menu opens its `Plan to do` submenu
Then the direct `Tomorrow` shortcut is hidden

Given the Mac `Show Tomorrow section` task-list setting is on
When Home derives tasks planned for tomorrow or calendar routines scheduled tomorrow
Then `Tomorrow` defaults between `Today` and `Future`, uses the `plannedTomorrow` manual-order bucket, and those rows retain their ordinary section placement

Given Mac Home shows two or more durable top-level task-list sections
When the user right-clicks an eligible section and chooses `Move Up` or `Move Down`
Then the complete section moves one visible durable-section position and the display order persists across presentation rebuilds
And task membership, planning projection, custom-section rules, and row order remain unchanged

Given an eligible Mac Home section is already the first or last movable direction
When its right-click menu opens
Then both move commands remain visible and the unavailable direction is disabled

Given the user right-clicks the Mac Home `Today` or `Tomorrow` section
When its native context menu opens
Then neither `Move Up` nor `Move Down` is available

Given Mac Home renders durable top-level task-list sections
When the user inspects their headers and section surfaces
Then there are no section drag handles or section drop targets

Given a previously ordered section becomes empty or is hidden by current filters
When that section becomes visible again
Then it returns to its stored relative position

Given a new built-in or custom section becomes visible after the user has stored an order
When Home rebuilds the task-list presentation
Then the new section enters beside its nearest default-order neighbors without resetting the user's existing relative order

Given the Mac `Show Tomorrow section` task-list setting is on
When a Todo has exact `At date` availability for tomorrow
Then it appears in `Tomorrow` through its same-day planned date

Given the Mac `Show Tomorrow section` task-list setting is on
When a task row context menu opens its `Plan to do` submenu
Then the direct `Tomorrow` shortcut is available

### Future Preserves Inner Group Behavior

Area: Tasks
Decision links: [0283](../decisions/0283-preserve-mac-future-inner-sections.md), [0314](../decisions/0314-remove-status-grouping-and-collapse-deadline-groups.md), [0347](../decisions/0347-split-mac-future-tag-groups-by-task-kind.md), [0351](../decisions/0351-collapse-mac-future-tag-task-kind-subsections.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/HomeTaskListFilteringTests.swift`

Given Mac Home groups regular tasks by tag
When Home derives the `Future` section
Then each tag group remains a tagged, colorable, collapsible inner section inside `Future`

Given Mac Home groups regular tasks by tag and the tag task-kind split is enabled
When a `Future` tag group contains both todos and routines
Then the parent tag group stays collapsible and renders collapsible `Todos` and `Routines` child subsections

Given Mac Home groups regular tasks by deadline date
When Home derives the `Future` section
Then each deadline-date group remains independently collapsible inside `Future`

Given Mac Home shows `Future` with collapsible inner groups
When the user right-clicks the `Future` header and chooses `Expand All`
Then the `Future` wrapper opens and each collapsible inner group expands, including task-kind child subsections

Given Mac Home shows `Future` with collapsible inner groups
When the user right-clicks the `Future` header and chooses `Collapse All Subsections`
Then the `Future` wrapper stays open and each collapsible inner group collapses, including task-kind child subsections

### Home Task Lists Keep Stable Row Identity

Area: Tasks
Decision links: [0252](../decisions/0252-stabilize-home-task-list-presentation-identity.md), [0440](../decisions/0440-treat-day-planning-sections-as-additive.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/HomeTaskListFilteringTests.swift`

Given task data briefly appears in overlapping active, away, archived, daily, or status inputs during a refresh
When Home task-list presentation is derived
Then each task ID is claimed once in ordinary classification, section and group IDs stay stable, and the UI updates existing rows instead of replacing them

Given one task qualifies for Today or Tomorrow and an ordinary section
When Home task-list presentation is derived
Then the planning section and ordinary section each contain one stable row for that task, without duplicates inside either section

### Planner and Backlog Filter Button Uses a Companion Pane

Area: UI
Decision links: [0690](../decisions/0690-place-mac-filters-beside-planner-and-backlog-workspaces.md), [0312](../decisions/0312-move-mac-task-timeline-filter-entry-to-toolbar.md), [0316](../decisions/0316-present-mac-home-filters-as-companion-pane.md), [0319](../decisions/0319-open-planner-filters-in-home-filter-pane.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage:
- `Tests/macOS/PerformanceRegressionTests.swift`
- `Tests/Shared/MacWorkspaceNavigationSourceTests.swift`
- `Tests/Shared/BacklogTaskListPresentationTests.swift`
- `Tests/macOS/BacklogFeatureTests.swift`

Given Mac Home is showing Planner in Calendar or Timeline mode
Then one filter button appears immediately to the left of the top-right workspace menu
And the workspace menu keeps the same trailing position when the filter appears or disappears
And Planner's local header has no second filter button
When the top-toolbar filter button is pressed
Then the `Shared` / `Task List` / `Timeline` / `Calendar` filter surface opens in a right-side companion pane while the current workspace remains visible
And task-detail panes, the board inspector, and Planner-local right sidebars do not remain open beside it
When the user expands the filter pane fullscreen and then minimizes it
Then the filter surface returns to the right-side companion pane

Given Mac Home is showing Backlog
When the same top-toolbar filter button is pressed
Then Backlog's independent filter surface opens with the same companion, fullscreen, minimize, and close behavior

Given Mac Home is showing Task Ladder, Stats, Settings, Details, or another non-Planner/non-Backlog workspace
Then the top-toolbar filter button is absent

### Timeline Filters Do Not Auto-Open Row Details

Area: Timeline
Decision links: [0280](../decisions/0280-show-timeline-newest-first.md), [0256](../decisions/0256-move-mac-timeline-row-appearance-to-timeline-filter-detail.md), [0316](../decisions/0316-present-mac-home-filters-as-companion-pane.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/TimelineSelectionSupportTests.swift`
- `Tests/macOS/PerformanceRegressionTests.swift`

Given Mac Home is showing the Timeline filter companion pane
When a filter change updates the visible timeline rows
Then the sidebar does not automatically select a fallback row or close the filter pane until the user explicitly leaves the filter pane or selects a row

### Timeline Flag Rules Hide by Default and Remain Recoverable

Area: Timeline / Flags
Decision links: [0677](../decisions/0677-centralize-mac-flag-filters-under-shared.md), [0582](../decisions/0582-hide-flagged-task-activity-from-timeline.md), [0497](../decisions/0497-use-flags-for-task-behavior-rules.md), [0418](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/RoutineTagTests.swift`
- `Tests/Shared/TimelineLogicTests.swift`
- `Tests/Shared/TabFilterStateManagerTests.swift`

Given a task has a Flag configured with `Hide task activity from Timeline`
When no Timeline Flag filter is selected
Then that task's completion, missed, canceled, and task-linked Focus activity is omitted from iOS Timeline and Mac Planner Timeline
And the history, task, Stats, notifications, Planner Calendar, and unrelated context records remain unchanged

When the person selects that Flag in iOS Timeline Filters or Mac Shared Filters
Then matching task activity appears even though the rule normally hides it
And multiple selected Flags use the chosen `All` or `Any` matching mode
And clearing the Flag selection restores the default hidden presentation
And the filter catalog remains available from the cached pre-hide snapshot without whole-history work in scrolling row builders
And Mac Timeline does not duplicate Shared's direct searchable actions, removable chips, or Flag catalog
And Shared Exclude flags can suppress matching task activity after an Include match

### iOS Timeline Refreshes After Synced Activity

Area: Timeline / Sync
Decision links: [0280](../decisions/0280-show-timeline-newest-first.md), [0418](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage:
- `Tests/Shared/TimelineLogicTests.swift`

Given today's activity is imported into the iOS SwiftData store from another device
When Routina posts its coalesced semantic update notification or becomes active
Then iOS Timeline explicitly refetches its stable data snapshot
And today's newest activity appears above yesterday without reopening Timeline
And the scrolling view does not depend on unbounded SwiftData queries or whole-history change tokens

### Timeline Appearance Settings Match iOS Rows

Area: Timeline / Settings
Decision links: [0222](../decisions/0222-configure-timeline-row-fields.md), [0418](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
Coverage:
- `Tests/iOS/ScopedFeatureTests.swift`
- `Tests/Shared/IOSScrollingPerformanceRegressionTests.swift`
- `Tests/Shared/SettingsTimelineRowPreviewTests.swift`

Given Timeline Row settings enable icon, row number, subtitle, and type
When iOS renders Timeline rows and the Appearance preview
Then both surfaces show the same compact icon, numeric badge, subtitle, and type treatment
And row numbers come from the already-grouped Timeline presentation rather than being rebuilt while rows scroll

### Planner List Honors Home Timeline Filters

Area: Timeline
Decision links: [0309](../decisions/0309-show-full-timeline-in-planner-list-mode.md), [0312](../decisions/0312-move-mac-task-timeline-filter-entry-to-toolbar.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/macOS/PerformanceRegressionTests.swift`
- `Tests/macOS/HomeFeatureTests.swift`
- `Tests/Shared/HomeFilterEditorTests.swift`
- `Tests/Shared/MacWorkspaceNavigationSourceTests.swift`

Given Mac Planner is in `List` mode
When the companion filter pane changes `Shared` filters or Timeline-specific filters
Then the Planner List timeline rows use the same filtered entry set as the Timeline sidebar
And an empty filtered list explains that search or filters may be hiding entries
When active Timeline filters hide newer activity while older matching rows remain visible
Then Planner Timeline shows an active-filter notice with a direct clear action above the rows
And the top-toolbar filter button is highlighted and opens the `Timeline` scope in the companion filter pane
When the person uses that direct clear action
Then Timeline-owned and Shared filters affecting Timeline reset together
And Task List-only filters remain unchanged

### Planner Timeline Keeps Go To Date

Area: Planner
Decision links: [0341](../decisions/0341-consolidate-mac-home-toolbar-row.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/macOS/PerformanceRegressionTests.swift`

Given Mac Planner is in `Timeline` mode
When the user presses the `Go to date` header button
Then the Planner date picker opens in the right-side Planner sidebar
And choosing a date updates the Planner selected date without scoping the Timeline list to that date

### Mac New Menu Owns Focus

Area: Home / Focus
Decision links: [0681](../decisions/0681-move-mac-focus-into-new-menu.md), [0686](../decisions/0686-combine-mac-workspace-and-actions-in-one-menu.md)
Current behavior: [UI](../current-behavior/ui.md), [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/macOS/HomeFeatureTests.swift`
- `Tests/macOS/PerformanceRegressionTests.swift`

Given Mac Home uses standard production action availability
When the user presses the workspace-labeled toolbar control
Then its single native menu starts with Add New Task followed by Focus
And it shows Control-Option-Command-T and Control-Option-Command-F beside those actions
And a divider separates those actions from Planner, Backlog, Task Ladder, and the other workspace destinations
And no separate `+` toolbar target is present
Given the eligible Focus-task snapshot contains an active task
And the current Home presentation has no visible task rows
Then Focus remains enabled in the combined workspace menu
When Planner shows Calendar or Timeline
Then neither header renders a separate Focus control
And choosing Focus or pressing its shortcut opens the existing task, tag, and duration sheet

Given another Focus or sprint timer is active
When the user opens the combined workspace menu
Then Focus is disabled
And `Another timer is running` appears immediately after it
And the active live-time badge appears immediately beside the Home sidebar toggle
When the user presses that badge
Then the menu exposes the controls supported by the running timer

### Mac Focus Starts From One Recalling Sheet

Area: Planner / Focus
Decision links: [0603](../decisions/0603-start-mac-focus-from-one-recalling-sheet.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/FocusSessionTagRecencyTests.swift`
- `Tests/macOS/PerformanceRegressionTests.swift`

Given no protected session prevents a new attributed Focus start
When the person presses Focus in the Mac combined workspace menu
Then one Focus sheet opens directly without an intermediate duration menu
And that sheet presents count-up and fixed durations beside task and tag attribution

Given the eligible Focus task snapshot contains tasks tagged `Health` and `HSE`
When the person opens the Mac Focus sheet
Then the task rows and tag strip come from the same presentation snapshot
And the `#Health` and `#HSE` filters are visible when their tagged task rows are visible

Given the latest attributed Focus session was count-up on an available `#HSE` tag
When the person opens the Focus sheet again
Then `Count up · #HSE` is selected by default
And the person can repeat it with Start or change duration and attribution in that same sheet

Given the person selected a duration in the Focus sheet
When the person reopens the sheet after canceling or starting that flow
Then the duration is labeled `Last choice`
And it is selected by default

Given a newer unassigned Focus exists or the latest attributed tag is no longer available
When the person opens the Focus sheet
Then unassigned Focus does not replace the attributed duration default
And an unavailable tag is not restored as a hidden selection

### Plan Focus Allocation Preserves Focus History

Area: Planner
Decision links: [0205](../decisions/0205-run-plan-focus-from-planner.md), [0209](../decisions/0209-allocate-plan-focus-while-running.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/FocusSessionSupportTests.swift`
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given plan focus starts from tasks in `Today`
When focus time is allocated while running or after finish
Then task allocations are recorded without deleting the unassigned focus session history

### Resumed Tag Focus Shows Separate Planner Segments

Area: Planner
Decision links: [0123](../decisions/0123-pause-focus-timers.md), [0267](../decisions/0267-support-mac-toolbar-tag-focus.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given a count-up tag focus session is paused after focused work has accumulated
When the user resumes the same focus session later that day
Then Planner shows the completed pre-pause segment and the current resumed segment as separate blocks with the same tag
And the resumed block duration follows focused time after resume instead of the wall-clock gap while the timer was paused
And an already-saved pre-pause segment is capped to focused time instead of spanning the paused gap
And after multiple pause/resume cycles, each completed focus segment remains its own block instead of being packed into the first block

Given a count-up tag focus session has saved focus segments on a prior visible day and a live current-day segment
When the user switches Planner Calendar between Week, 3 Days, and Day ranges
Then saved focus segments on visible prior days remain visible, while only the live current-day segment is replaced by the live Focus overlay
And active task-list filters do not hide unassigned tag-focus blocks, while calendar text search still matches them by tag/title

### Completed Tag Focus Can Be Corrected From Calendar

Area: Planner
Decision links: [0600](../decisions/0600-edit-recorded-tag-focus-from-mac-planner.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given Mac Planner Calendar `Schedule` shows a completed tag Focus block
When the user double-clicks that block
Then a Planner right sidebar shows the tag, recorded start, duration, and end
And active tag Focus, task Focus, Plan Focus, and board Focus keep their existing routes

Given the person changes the completed tag Focus start or duration and saves
When Planner refreshes the recorded session
Then the owning Focus history and persisted Planner evidence use the corrected interval together
And any previous pause/resume segments for that session are replaced by one continuous corrected interval

### Planner Range Picker Follows Adaptive Visible Days

Area: Planner
Decision links: [0609](../decisions/0609-keep-planner-range-choices-actionable-in-compact-headers.md), [0303](../decisions/0303-align-mac-planner-range-picker-with-adaptive-days.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given Mac Planner prefers Week mode
When the calendar column becomes wide, medium, or narrow
Then the selected range segment and rendered calendar become Week, 3 Days, or Day respectively and previous/next navigation moves by that effective visible range
And the range control lists only modes the current calendar width can render
And the preferred Week mode returns when the calendar becomes wide enough again

Given the user explicitly selects Day
When the calendar column grows from narrow to wide
Then Planner keeps Day selected and continues rendering one day

### Planner Companion Panes Do Not Overlap Calendar

Area: Planner
Decision links: [0296](../decisions/0296-present-mac-task-details-as-planner-inspector.md), [0299](../decisions/0299-constrain-mac-home-window-size.md), [0306](../decisions/0306-use-day-planner-width-for-task-detail-inspector-fit.md), [0307](../decisions/0307-hide-planner-range-picker-in-day-inspector-layout.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`
- `Tests/macOS/PerformanceRegressionTests.swift`

Given Mac Planner is visible beside a right-side companion pane
When the available Planner column becomes tight
Then Mac Home subtracts the fixed companion pane before sizing the Planner column, clips Planner content to that column, and caps the adaptive Planner range to Day until the remaining calendar column is roomy enough for multi-day inspector layout

### Planner Block Resize Stays Continuous Across Layout Changes

Area: Planner
Decision links: [0264](../decisions/0264-match-button-hit-areas-to-visual-surfaces.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given a manual planner block is selected
When the user drags the top or bottom resize grip and the block crosses a height threshold that changes its card presentation
Then the active drag continues resizing the block to its live size and position without requiring the user to release and grab the grip again

### Small Planner Blocks Remain Movable

Area: Planner
Decision links: [0264](../decisions/0264-match-button-hit-areas-to-visual-surfaces.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given a manual planner block is short, such as a 5- or 15-minute block
When the user hovers or drags from the middle of the block
Then the block can still be moved because resize grips stay limited to the block edges

### Deleting a Task Removes Its Planner Blocks

Area: Planner, Tasks
Decision links: [0287](../decisions/0287-remove-deleted-task-blocks-from-planner.md)
Current behavior: [Planner](../current-behavior/planner.md), [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/DayPlanStorageTests.swift`
- `Tests/iOS/TaskDetailFeatureTests.swift`
- `Tests/macOS/TaskDetailFeatureTests.swift`

Given a task has a persisted planner block
When the user deletes that task from edit task
Then matching planner blocks are removed from Planner storage and unrelated planner blocks remain

### Planner Ignores Duplicate Persisted Blocks

Area: Planner / Storage
Decision links: [0418](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanStorageTests.swift`

Given older data contains multiple planner records with the same block ID for one day
When Planner loads that day
Then it keeps only the most recently updated block and the Calendar can render without an identity collision
And the next planner save removes the stale duplicate record

Given synchronization produced different block IDs for the same task, day, start, and duration
When Planner loads that day
Then it keeps only the most recently updated semantic placement and Calendar renders one block
And distinct time slots for that task and coincident blocks for other tasks remain visible
And the next planner save removes the stale semantic duplicate

### Planner Slot Actions Hide Away and Sleep When Away Is Off

Area: Planner
Decision links: [0277](../decisions/0277-hide-notes-and-away-behind-beta-toggles.md), [0279](../decisions/0279-hide-sleep-stats-and-blocking-with-away-toggle.md), [0273](../decisions/0273-log-sleep-from-planner-away-slot-action.md), [0286](../decisions/0286-present-planner-slot-actions-in-sidebar.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanSlotActionPresentationTests.swift`

Given Support & About -> Beta Experiments -> `Show Away` is off
When the user opens the Planner empty-slot action sidebar
Then the panel offers task block creation only and does not expose Away or Sleep logging options

Given the Planner empty-slot action sidebar has only task block creation available
When the sidebar opens for the draft block
Then it does not show a single-option `Task` tab, keeps the draft block visible in the grid, lets the user select a task from an inline filtered list, and can create a new task before adding the block

### Planner Calendar Filters Respect Beta Toggles

Area: Planner
Decision links: [0291](../decisions/0291-gate-planner-calendar-filter-options-by-beta-toggles.md), [0289](../decisions/0289-filter-planner-calendar-layers.md), [0319](../decisions/0319-open-planner-filters-in-home-filter-pane.md), [0277](../decisions/0277-hide-notes-and-away-behind-beta-toggles.md), [0220](../decisions/0220-nest-sleep-and-gate-mac-event-emotion-actions.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanCalendarFilterStateTests.swift`

Given Support & About -> Beta Experiments -> `Show Away` is off
When the user opens the companion filter pane's `Calendar` tab
Then the panel does not expose Away or Sleep filter options

Given Support & About -> Beta Experiments -> `Show Event and Emotion actions` is off
When the user opens the companion filter pane's `Calendar` tab
Then the panel does not expose an Events filter option

Given stale hidden filter state exists for Events, Away, or Sleep from a previous beta-enabled session
When the relevant beta toggle is off
Then those unavailable beta layers do not count as active hidden filters or stay hidden without a visible control

### Mac Task Details Hide Event Add Action When Event Actions Are Off

Area: Tasks
Decision links: [0220](../decisions/0220-nest-sleep-and-gate-mac-event-emotion-actions.md), [0195](../decisions/0195-support-task-event-links.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage:
- `Tests/Shared/TaskDetailSharedViewSupportTests.swift`

Given Support & About -> Beta Experiments -> `Show Event and Emotion actions` is off
When the user opens full Mac Task Details for a task with no linked events
Then the `Add a detail` popover does not expose an Events action

Given Support & About -> Beta Experiments -> `Show Event and Emotion actions` is on
When the user opens full Mac Task Details for a task with no linked events
Then the `Add a detail` popover can expose an Events action

### Mac Task Details Persist Heatmap Per Task

Area: Tasks
Decision links: [0381](../decisions/0381-make-mac-task-detail-heatmap-optional.md), [0393](../decisions/0393-persist-task-detail-heatmap-per-task.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage:
- `Tests/macOS/TaskDetailFeatureTests.swift`
- `Tests/Shared/SettingsRoutineDataPersistenceTests.swift`

Given the user opens full Mac Task Details for a routine that has not explicitly added Heatmap
When the user chooses `Heatmap` from the header's `Add a detail` popover
Then that task stores the heatmap as visible in full Mac Task Details

Given another eligible task has not explicitly added Heatmap
When the user opens full Mac Task Details for that other task
Then the heatmap stays hidden until the user adds it for that task

### Planner Inspector Day Header Keeps Compact Range Choice

Area: Planner
Decision links: [0609](../decisions/0609-keep-planner-range-choices-actionable-in-compact-headers.md), [0306](../decisions/0306-use-day-planner-width-for-task-detail-inspector-fit.md), [0654](../decisions/0654-progressively-reveal-mac-planner-header-choices.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`
- `Tests/macOS/PerformanceRegressionTests.swift`

Given the Mac Planner task-detail companion pane is open
When the effective Planner range has adapted down to Day
Then the range control remains available as a compact current-value trigger whose expanded segment contains Day only
And Planner view and Calendar task view remain compact current-value triggers that reveal one segmented control at a time
And previous/next, filter, and an icon-only Go to date control remain in the header
And the calendar grid can use its compact inspector minimum width so the time column and single day column fit inside the Planner surface

Given the Mac Planner task-detail companion pane is open with enough room for a multi-day effective range
When the person opens Planner view, Calendar task view, or range
Then only that control expands into segments and later controls move right
And the textual date/range button remains available when the widest one-expanded row retains the 120-point usability reserve and comfortable labeled-date width

### Planner Day Headers Open Planned Task Lists

Area: Planner
Decision links: [0288](../decisions/0288-open-planned-day-task-list-from-planner-headers.md), [0300](../decisions/0300-show-plan-to-do-tasks-in-planner-day-agenda.md), [0371](../decisions/0371-drag-day-task-sidebar-rows-to-schedule.md), [0399](../decisions/0399-hide-visible-fulfilled-target-duplicates.md), [0402](../decisions/0402-drag-planner-task-detail-title-to-schedule.md), [0448](../decisions/0448-complete-planned-tasks-inline-from-calendar-list.md), [0509](../decisions/0509-collapse-calendar-list-assumed-done-sections.md), [0530](../decisions/0530-separate-confirmed-assumed-dones-in-calendar-list.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanDayTaskListPresentationTests.swift`
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given a Planner day has all-day task blocks, timed task blocks, standalone events, and protected-session blocks
When the user opens the day header's planned-task list
Then the right sidebar shows task-backed all-day items followed by timed task blocks for that date, and excludes events and protected sessions

Given a Planner day header has a visible planned-task count
When the header has enough room for its compact count button
Then the button shows the numeric count, capped visually at `99+`, without an ellipsis
And the button's accessibility label and help text retain the full count and category breakdown

Given a task has only a date-only `Plan to do` value for Monday
When the user opens Monday's Planner planned-task list
Then the task appears before timed blocks with an `Any time` placement label, without creating a stored Planner block or duplicating any visible all-day or timed item for the same task

Given the right-side Planner day task sidebar is open in Schedule mode
When the user drags a row into the Schedule grid or all-day lane
Then the row uses the same task payload as the left task list and schedules the underlying task through existing Planner drop behavior

Given the Mac Planner task-detail companion pane is open beside Calendar Schedule
When the user drags the task title into the Schedule grid or all-day lane
Then the title uses the same task payload as the left task list and schedules the underlying task through existing Planner drop behavior

Given Planner Calendar is in `List` task-view mode
When day-task columns render the same agenda rows
Then those columns do not provide drag payloads or general Planner-block editing
And eligible planned rows may expose their focused completion action

Given a Mac Calendar `List` day has assumed-done rows
When its day-task column first appears with the Calendar List default set to `Collapsed`
Then the `Assumed done` header and count are visible while its rows are hidden
And selecting the full header expands or collapses only that day’s assumed-done rows

Given the Calendar List default is set to `Expanded`
When a newly shown Calendar List day has assumed-done rows
Then its `Assumed done` rows start expanded without changing the Planner snapshot, filters, completion history, or the focused day-task sidebar

Given a Mac Calendar `List` day has recorded completion rows
When its day-task column first appears with the Calendar List default set to `Collapsed`
Then the `Done` header and count are visible while its rows are hidden
And selecting the full header expands or collapses only that day’s recorded completion rows
And the focused right-side day-task sidebar remains expanded

Given the user opens Calendar filters and selects `Appearance`
When they hide Icon, Time and Duration, or Row Color
Then Calendar `List` columns and the focused day-task sidebar update their shared task rows
And the main Task List and Timeline row appearance choices remain unchanged
And row titles and eligible inline resolution actions remain available

Given Task A is done for a day via linked source Task B
When Task B is already visible in that day's Planner task list
Then Task A is not also shown as a separate `Done` row for the same fulfilled action

Given Mac Home is fullscreen and Planner Calendar is in `List` task-view mode
When the user exits fullscreen
Then Planner Calendar remains in `List` task-view mode instead of resetting to `Schedule`

Given an assumed-done row is visible in Mac Planner Calendar `List` while a task-detail companion pane keeps full Planner snapshot refresh deferred
When the user clicks the row's green check
Then the persisted completion moves the row from `Assumed done` to `Confirmed assumed done` immediately
And the immediate transition only overlays the visible day-task presentation instead of fetching or regrouping full task history

Given an eligible standard planned row is visible for today or a past day in Mac Planner Calendar `List`
When the user hovers the row and clicks its green check
Then the represented occurrence is persisted through the normal task-completion history path
And the row moves from `Planned tasks` to `Done` immediately
And no Planner block is created, moved, resized, or deleted

Given a planned row represents a future day, sequential-step task, or checklist-completion task
When the Calendar `List` row renders
Then it does not show the one-click Done action

### Calendar List Done Durations Accept Custom Minutes

Area: Planner, Tasks
Decision links: [0435](../decisions/0435-edit-calendar-list-done-times-from-mac-task-detail.md), [0441](../decisions/0441-enter-custom-calendar-list-done-durations.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given a recorded Done row is selected in Mac Planner Calendar `List`
When its right-side task-detail card is open
Then the user can enter a custom duration through Hours and Minutes fields
And the duration can use one-minute precision rather than only presets or 15-minute increments
And Save updates only the selected completion occurrence while leaving its Planner block unchanged

### Calendar List Done Duration Can Omit A Specific Time

Area: Planner, Tasks
Decision links: [0444](../decisions/0444-log-completion-duration-without-a-specific-time.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`
- `Tests/Shared/SettingsRoutineDataBackupMappingTests.swift`
- `Tests/Shared/SettingsRoutineDataPersistenceTests.swift`

Given a recorded Done row represents work completed in multiple sessions across one day
When the Mac task-detail card selects `No specific time` and saves a total duration
Then the exact completion keeps its existing timestamp as occurrence identity
And its actual duration is updated without inventing one start/end interval
And reopening the completion keeps `No specific time` selected
And the Calendar List Done row shows `No specific time` with the total duration even when the task retains a separate Planner placement
And backup/import and CloudKit direct pull preserve the timing choice
And Planner blocks, other completion occurrences, recurrence, availability, reminders, estimates, and other days are unchanged

### Protected Modes Do Not Overlap

Area: Planner
Decision links: [0012](../decisions/0012-model-sleep-as-app-level-session-mode.md), [0125](../decisions/0125-support-away-sessions.md), [0158](../decisions/0158-generalize-protected-mode-blocking-settings.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/SleepSessionSupportTests.swift`
- `Tests/Shared/AwaySessionSupportTests.swift`
- `Tests/Shared/FocusSessionSupportTests.swift`

Given Sleep, Focus, or Away is active
When another protected mode is requested
Then the app prevents overlapping protected sessions and keeps history unambiguous

### Empty Stats Reports Stay Hidden

Area: Stats
Decision links: [0236](../decisions/0236-hide-empty-stats-reports.md)
Current behavior: [Stats](../current-behavior/stats.md)
Coverage:
- `Tests/Shared/StatsFeatureDerivedStateSupportTests.swift`
- `Tests/macOS/StatsMacDashboardItemAvailabilityTests.swift`
- `Tests/iOS/StatsDashboardItemAvailabilityTests.swift`

Given a dashboard report has no backing data
When Stats summary items are derived
Then the report is hidden while saved order and hidden-item preferences remain preserved

### Empty Stats Guidance Follows Sleep Availability

Area: Stats / Settings / UI
Decision links: [0221](../decisions/0221-hide-stats-sleep-tab-behind-beta-toggle.md), [0279](../decisions/0279-hide-sleep-stats-and-blocking-with-away-toggle.md)
Current behavior: [Stats](../current-behavior/stats.md)
Coverage:
- `Tests/Shared/StatsEmptyDashboardMessageTests.swift`

Given Stats has no visible reports and no active filters
And either `Show Away` or `Show Sleep tab` is off
When Stats presents its empty-state guidance
Then the guidance does not mention Sleep
And it still explains that tasks, Focus, or other logged activity can produce reports

Given both `Show Away` and `Show Sleep tab` are on
When Stats presents the same unfiltered empty state
Then the guidance can include Sleep

Given active filters produce an empty dashboard
When Sleep availability changes
Then the range-and-filter recovery guidance remains unchanged

### iOS Stats Hides Inert Toolbar Controls

Area: Stats / iOS UI
Decision links: [0700](../decisions/0700-hide-inert-ios-stats-toolbar-controls.md)
Current behavior: [Stats](../current-behavior/stats.md)
Coverage:
- `Tests/Shared/StatsDashboardToolbarAvailabilityTests.swift`

Given iOS Stats has no reportable dashboard item, task data, or active sheet filter
When the dashboard presents its empty state
Then Cards/Compact, Edit, and Filter are absent

Given at least one reportable dashboard item is hidden
When no report is currently visible
Then Edit remains available so the hidden item can be restored

Given an active sheet filter leaves no reportable result
When the dashboard becomes empty
Then Filter remains available so the filter can be cleared
And Edit and Cards/Compact remain absent until they can affect report content

Given the selected scope has a visible report but no visible summary item
When the toolbar is derived
Then Cards/Compact is absent while applicable Edit and Filter controls remain

Given reportable items disappear while dashboard editing or Add is open
When toolbar availability refreshes
Then Stats exits edit mode and dismisses Add

### Semantic Focus Copies Count Once In Stats

Area: Stats / Focus
Decision links: [0598](../decisions/0598-count-semantic-focus-session-copies-once-in-stats.md), [0137](../decisions/0137-show-active-focus-in-stats-today.md)
Current behavior: [Stats](../current-behavior/stats.md)
Coverage:
- `Tests/Shared/RoutineCompletionStatsTests.swift`

Given synchronization preserved several storage rows for the same logical focus sessions
And those rows share the same task, tag, or sprint owner and exact start time
When Stats derives focus duration, hourly rhythm, goal focus, Focus 2048, or task-focus achievements
Then each logical focus session contributes once
And genuinely separate sessions with different start times remain separate
And Stats does not delete the persisted rows while canonicalizing its evidence

### Focus Charts Keep Their Date Axes Readable

Area: Stats / UI
Decision links: [0119](../decisions/0119-show-cumulative-focus-chart.md), [0147](../decisions/0147-use-adaptive-stats-dashboard-width.md)
Current behavior: [Stats](../current-behavior/stats.md)
Coverage:
- `Tests/Shared/StatsFeatureDerivedStateSupportTests.swift`

Given Focus Stats covers more daily points than can carry a complete label at every position
When the focus distribution or cumulative-focus chart is shown on iOS or macOS
Then the axis keeps the first and last date and samples a compact set of complete intermediate labels
And a custom range shows month context at its first visible label and whenever the visible labels cross a month boundary
And a horizontally scrollable plot fills the available viewport before becoming wider than it

### Mac Stats Round Trip Preserves Task Detail

Area: Tasks / Stats
Decision links: [0151](../decisions/0151-combine-mac-stats-and-adventure-tab.md)
Current behavior: [Stats](../current-behavior/stats.md), [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/macOS/HomeFeatureTests.swift`
- `Tests/macOS/HomeFeatureTaskListModeTests.swift`

Given a task detail is selected in Mac Home
When the user opens Stats and then selects Tasks in the top toolbar
Then the same task row and task detail are restored
And the existing task-list type selection and filters remain active

### App Lock Protects Sensitive Reset Actions

Area: Settings
Decision links: [0166](../decisions/0166-use-app-lock-for-cloud-data-reset.md), [0235](../decisions/0235-require-authentication-to-disable-app-lock.md), [0241](../decisions/0241-gate-settings-reset-with-app-lock.md)
Current behavior: [Settings](../current-behavior/settings.md)
Coverage:
- `Tests/Shared/SettingsFeatureTests.swift`

Given a user tries to disable App Lock or restore settings defaults
When device-owner authentication fails, is unavailable, or App Lock is off where required
Then the sensitive action does not proceed

### Saved-Place Map Actions Stay Contextual

Area: Places
Decision links: [0230](../decisions/0230-unify-map-pin-place-and-check-in-actions.md), [0232](../decisions/0232-allow-known-pin-check-in.md), [0233](../decisions/0233-allow-selected-saved-place-check-in.md), [0234](../decisions/0234-hide-current-place-map-check-in.md)
Current behavior: [Places](../current-behavior/places.md)
Coverage:
- `Tests/iOS/PlaceLocationPickerCameraConfigurationTests.swift`
- `Tests/macOS/PlaceLocationPickerCameraConfigurationTests.swift`
- `Tests/Shared/PlaceCheckInSupportTests.swift`

Given the map is showing an unsaved location, an away saved place, or the current resolved saved place
When the action panel is derived
Then Add Place and Check In appear only for the contexts where they make sense

### Task Row Appearance Respects Optional Feature Toggles

Area: Tasks, Places, Settings
Decision links: [0538](../decisions/0538-gate-add-task-goals-with-feature-setting.md), [0275](../decisions/0275-hide-places-behind-beta-toggle.md), [0254](../decisions/0254-move-mac-task-row-appearance-to-home-filter-detail.md)
Current behavior: [Tasks](../current-behavior/tasks.md), [Places](../current-behavior/places.md)
Coverage:
- `Tests/Shared/HomeTaskListFilteringTests.swift`
- `Tests/Shared/SettingsAppearanceFeatureAvailabilityTests.swift`

Given Support & About -> Beta Experiments -> `Show Places` is off
When the user opens the Mac Home filter companion pane's `Task List` -> `Appearance` tab
Then the Task Row card does not expose a `Places` option or count it in the shown-fields summary

Given `Show Places` is on
When the user opens the same Appearance tab
Then the Task Row card includes the `Places` option even if no current task has place-aware content

Given `Show Goals tab` or `Show Places` is off in iOS Settings
When the user opens Settings -> Appearance -> Task Row
Then the matching Goals or Places option is absent, including from the preview and shown-fields count
And enabling the feature restores the option without changing its stored visibility choice

### Mac Main Task Titles Can Wrap Without Mixing Metadata

Area: Tasks, Settings
Decision links: [0662](../decisions/0662-reserve-the-first-mac-task-row-line-for-the-title.md), [0663](../decisions/0663-allow-optional-multiline-mac-task-titles.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/HomeTaskListFilteringTests.swift`
- `Tests/Shared/HomeMacTaskRowMetadataLayoutSourceTests.swift`
- `Tests/Shared/SettingsFeatureTests.swift`

Given the user opens the Mac filter companion pane's `Task List` -> `Appearance` tab
When `Multiline Titles` is off
Then main task-list titles remain on one line and truncate when needed

When `Multiline Titles` is on
Then long main task-list titles wrap onto additional lines
And secondary labels plus later metadata remain below the complete title block
And changing another Task Row field preserves the multiline choice
And iOS task rows remain unchanged

### Mac Task Form Section Titles Stay Consistent

Area: Tasks
Decision links: [0058](../decisions/0058-use-progressive-task-forms.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/macOS/FormSectionTests.swift`

Given the Mac task form shows a section in both the sidebar navigator and the main form
When the Behavior section is rendered
Then both surfaces use the canonical `Behavior` title

### Mac Task Creation Has Visible Confirmation

Area: Tasks / UI
Decision links: [0457](../decisions/0457-confirm-successful-mac-task-creation.md)
Current behavior: [Tasks](../current-behavior/tasks.md), [UI](../current-behavior/ui.md)
Coverage:
- `Tests/macOS/HomeFeatureTests.swift`
- `Tests/macOS/PerformanceRegressionTests.swift`

Given the full Mac Add Task form is open
When a task saves successfully
Then the form closes, the new task is selected with its details visible, and a
transient created-task confirmation names the task
And the confirmation omits a redundant `Open details` action

Given the Mac toolbar creates a task through Quick Add
When its confirmation appears
Then `Open details` remains available
And the optional action and close control align to the toast's normal trailing
inset rather than leaving unused width after them

### iOS New Actions Follow Feature Availability

Area: Settings / UI
Decision links: [0012](../decisions/0012-model-sleep-as-app-level-session-mode.md), [0279](../decisions/0279-hide-sleep-stats-and-blocking-with-away-toggle.md), [0458](../decisions/0458-align-ios-new-actions-with-beta-gates.md)
Current behavior: [Settings](../current-behavior/settings.md), [UI](../current-behavior/ui.md)
Coverage:
- `Tests/Shared/IOSNewTabActionAvailabilityTests.swift`

Given Event and Emotion, Goals, or Sleep is disabled in Beta Experiments
When the user opens the iOS bottom-bar New sheet
Then the matching Event and Emotion, Goal, or Going to sleep rows are absent

Given the Sleep experiment is enabled but the dedicated New-sheet Sleep
preference is disabled
When the user opens New
Then Going to sleep remains absent

Given the persisted Sleep experiment is enabled but its parent Away experiment
is disabled
When the user opens New
Then Going to sleep remains absent

Given `Show Away`, `Show Sleep tab`, or `Shake to start sleep mode` is off
When the person shakes the iOS device
Then no Sleep confirmation opens and no Sleep session starts

Given a shake confirmation was already open when one of those settings turns off
When the person tries to confirm the stale action
Then the confirmation is dismissed and no Sleep session starts

Given an optional action becomes unavailable before a queued selection routes
When the pending action is performed
Then its editor or protected-session start does not open

Given feature availability leaves Task as the only iOS New action
When the user taps the bottom-bar New action
Then task creation opens directly without presenting a one-row chooser

### iOS Timeline Type Filters Follow Feature Availability

Area: Timeline / Settings / UI
Decision links: [0220](../decisions/0220-nest-sleep-and-gate-mac-event-emotion-actions.md), [0221](../decisions/0221-hide-stats-sleep-tab-behind-beta-toggle.md), [0279](../decisions/0279-hide-sleep-stats-and-blocking-with-away-toggle.md), [0458](../decisions/0458-align-ios-new-actions-with-beta-gates.md), [0470](../decisions/0470-keep-beta-experiments-out-of-production.md), [0706](../decisions/0706-gate-disabled-emotions-at-release-presentation-boundaries.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage:
- `Tests/Shared/IOSNewTabActionAvailabilityTests.swift`
- `Tests/Shared/TimelineLogicTests.swift`

Given `Show Event and Emotion actions` is off
When the person opens iOS Timeline filters or scans its horizontal type controls
Then Events and Emotions are not offered as filter choices

Given `Show Away` or `Show Sleep tab` is off
When the person opens iOS Timeline filters or scans its horizontal type controls
Then Sleep is not offered as a filter choice

Given an unavailable Event, Emotion, or Sleep filter was restored from an
earlier enabled session
When iOS Timeline becomes active or the corresponding feature gate changes
Then the hidden filter normalizes to `All`
And it does not remain counted or presented as an active filter

### Disabled Emotions Stay Out of Stats and Timeline

Area: Stats / Timeline / Settings / UI
Decision links: [0220](../decisions/0220-nest-sleep-and-gate-mac-event-emotion-actions.md), [0470](../decisions/0470-keep-beta-experiments-out-of-production.md), [0706](../decisions/0706-gate-disabled-emotions-at-release-presentation-boundaries.md)
Current behavior: [Stats](../current-behavior/stats.md), [UI](../current-behavior/ui.md)
Coverage:
- `Tests/iOS/StatsDashboardItemAvailabilityTests.swift`
- `Tests/Shared/IOSNewTabActionAvailabilityTests.swift`
- `Tests/macOS/PerformanceRegressionTests.swift`

Given Emotion records remain in persistence and `Show Event and Emotion actions` is off
When the person opens iOS Stats or Timeline on iOS or macOS
Then Stats presents no Emotion summary, trend, or achievement domain
And Timeline presents no Emotion rows
And the underlying Emotion records remain stored for later development re-enablement

Given two or more iOS New actions are available
When the user taps the bottom-bar New action
Then the feature-gated chooser opens with those available actions

### iOS More Groups Task Reviews

Area: Tasks / UI
Decision links: [0601](../decisions/0601-keep-ios-task-reviews-development-only.md), [0540](../decisions/0540-group-ios-task-reviews-under-more-destination.md), [0033](../decisions/0033-use-app-owned-ios-more-tab.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage:
- `Tests/Shared/IOSMoreTaskReviewNavigationTests.swift`

Given a person opens compact iOS More in a development build
When they need task-choice or missing-task-detail help
Then More shows one `Review tasks` entry instead of a separate top-level row for every review

Given the person opens `Review tasks`
Then the navigation title shows an orange `DEV` label
And `Help me choose` is available first
And `Add missing task details` groups Pressure, Thinking needed, time estimates, Importance, and Urgency
And selecting any action uses the same app-owned navigation stack with a normal back path to `Review tasks` and More

Given a person opens compact iOS More in a release version
Then `Review tasks` is absent
And its task-review destination cannot be presented

### iOS Home Empty States Offer Task Creation

Area: Home / UI
Decision links: [0539](../decisions/0539-offer-ios-task-creation-from-home-empty-states.md), [0698](../decisions/0698-focus-first-ios-home-on-the-first-task.md)
Current behavior: [Tasks](../current-behavior/tasks.md), [UI](../current-behavior/ui.md)
Coverage:
- `Tests/Shared/HomeIOSCreationEmptyStateTests.swift`
- `Tests/Shared/IOSFirstTaskExperienceTests.swift`

Given a genuinely new iOS installation has finished loading an empty task snapshot
When the person opens Home before this installation has observed a task
Then Home asks what they would like to get done
And `Create Your First Task` opens Smart Add
And task-type actions, Filters, Backlog, Timeline, and Task Ladder are absent
And the standard bottom tabs remain available

Given an existing installation is empty, or this installation previously observed a task
When the person opens an empty Home
Then the established state shows an `Add New Task` button that opens Smart Add
And deleting every task does not replay first-use guidance

Given the person searches Home with a non-empty query that matches no known task
When the search results are empty
Then the no-results state shows `Create Task`
And Smart Add opens with the trimmed query as its task text

Given a known task matches the search but current filters hide it
When the visible search results are empty
Then Home omits the create action to avoid suggesting a duplicate

### iOS Stats Scrolls From Stable Lazy Snapshots

Area: Stats / UI
Decision links: [0418](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
Current behavior: [Stats](../current-behavior/stats.md)
Coverage:
- `Tests/Shared/StatsFeatureDerivedStateSupportTests.swift`
- `Tests/iOSUI/RoutinaUIPerformanceTests.swift`

Given Stats has production-like task and activity history
When the user continuously scrolls the iOS dashboard
Then off-screen reports are constructed lazily with stable concrete view types
And Achievements and Recent Wins render a reducer-owned presentation snapshot
instead of walking whole history from a scrolling section builder
And raw persistence saves do not duplicate semantic refresh notifications
And bursts of semantic updates are coalesced before Stats reloads its snapshot

### iOS Stats Omits Secondary Comparison Reports

Area: Stats / UI
Decision links: [0503](../decisions/0503-remove-ios-secondary-stats-comparison-reports.md)
Current behavior: [Stats](../current-behavior/stats.md)
Coverage:
- Tests/iOS/StatsDashboardItemAvailabilityTests.swift
- Tests/Shared/IOSStatsDashboardPresentationTests.swift

Given a person views or edits the iOS Stats dashboard
When report availability is evaluated for any supported date range
Then Focus vs completed work and Estimated vs Actual time are unavailable
And neither report appears in the dashboard or its Add controls
And the macOS availability policy remains unchanged

### Initial iOS Release Omits Apple Health

Area: Stats / UI
Decision links: [0697](../decisions/0697-omit-apple-health-from-the-first-release.md)
Current behavior: [Stats](../current-behavior/stats.md)
Coverage:
- `Tests/Shared/AppStoreComplianceConfigurationTests.swift`

Given the first-release iOS or iPadOS app is built
When the person opens or edits Stats
Then no Apple Health connection prompt or movement card is available
And the app does not declare HealthKit entitlements or Health privacy-purpose strings
And Routina includes no HealthKit-backed Stats implementation or replacement health library

### iOS Focus 2048 Shows Only Progress-Relevant Details

Area: Stats / UI
Decision links: [0504](../decisions/0504-simplify-ios-focus-2048-stats-details.md)
Current behavior: [Stats](../current-behavior/stats.md)
Coverage:
- Tests/Shared/IOSStatsDashboardPresentationTests.swift

Given a person views Focus 2048 in iOS Stats
When the section renders any focus total
Then it shows earned tiles, the next-tile preview, and the progress bar
And it omits the Largest tile callout, earned-tile count, and insight pills
And macOS retains its supplementary details

### iOS Stats Cards Use Dense Metric Tiles

Area: Stats / UI
Decision links: [0505](../decisions/0505-use-dense-ios-stats-metric-tiles.md)
Current behavior: [Stats](../current-behavior/stats.md)
Coverage:
- Tests/Shared/IOSStatsDashboardPresentationTests.swift

Given a person views summary metrics in iOS Stats Cards mode
When the dashboard renders a two-column summary grid
Then each metric uses a compact icon/title header, one-line value, and optional one-line caption
And tiles use the dense metric-tile height rather than the prior spacious card height
And macOS cards and iOS Compact-mode rows remain unchanged

### One-Off Task Archiving Keeps It Out of Active Guidance

Area: Tasks / Lifecycle
Decision links: [0487](../decisions/0487-allow-archiving-one-off-tasks.md), [0486](../decisions/0486-suggest-confirmed-task-relationships-on-device.md), [0583](../decisions/0583-keep-task-creation-unlimited.md), [0631](../decisions/0631-remove-apple-intelligence-task-relationship-suggestions.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/macOS/TaskDetailFeatureTests.swift`
- `Tests/Shared/HomeTaskRowActionPresentationTests.swift`
- `Tests/Shared/MissingPressureDataFeatureTests.swift`
- `Tests/Shared/MissingThinkingNeededDataFeatureTests.swift`
- `Tests/Shared/MissingEstimatedDurationDataFeatureTests.swift`
- `Tests/Shared/MissingTaskMetadataFeatureTests.swift`
- `Tests/Shared/TaskChoiceFeatureTests.swift`

Given an unfinished one-off task is active
When the person chooses `Archive` from its Mac Task Detail overflow menu or Home row context menu
Then Routina moves it to Archived, cancels its notification, and keeps its task data intact
And every guided `Add missing…` review excludes the task
And Help me choose excludes the task before metadata readiness, comparison, and ranking

### Mac Task Detail Keeps Secondary Lifecycle Actions Together

Area: Tasks / macOS UI
Decision links: [0527](../decisions/0527-keep-mac-task-detail-overflow-compact-and-stateful.md), [0521](../decisions/0521-group-secondary-mac-task-detail-actions.md), [0487](../decisions/0487-allow-archiving-one-off-tasks.md), [0335](../decisions/0335-move-mac-task-detail-actions-into-detail-content.md), [0625](../decisions/0625-group-task-detail-add-detail-with-edit.md), [0626](../decisions/0626-join-mac-task-detail-completion-and-overflow.md)
Coverage:
- `Tests/macOS/PerformanceRegressionTests.swift`
- `Tests/Shared/TaskDetailPlatformActionParityTests.swift`

Given full Mac Task Details is open
Then Done and `⋮` share one rounded lifecycle control with no inter-button gap
And Done retains its semantic completion tint while the neutral `⋮` segment remains visually secondary
And each segment owns its full hit surface and triggers only its own action
When the person opens the vertical `⋮` task-action menu
Then one-off tasks offer Archive or Restore and eligible Cancel todo, while routines offer Pause or Resume
And Delete is a separated destructive menu item that still requires confirmation
And Done remains the only visible task lifecycle action
And only the `⋮` segment receives a restrained accent treatment while its compact native menu is open
And `Add a detail` is absent from that maintenance menu

When optional detail actions remain
Then Edit is a split header control whose pencil opens full Edit Task directly
And the narrow chevron opens an anchored `Add a detail` popover
And Task Details has no wide scrolling Add More card

Given an archived one-off task
When the person chooses `Restore`
Then it returns to active task placement, guided-review, and Help me choose eligibility
And Routina clears only its archived state without creating or shifting recurrence data

### iOS Task Choice Learns Condition-Relevant Tie-Breaks

Area: Tasks / UI
Decision links: [0486](../decisions/0486-suggest-confirmed-task-relationships-on-device.md), [0485](../decisions/0485-remove-opt-in-tag-preferences-pending-automatic-tag-intelligence.md), [0481](../decisions/0481-learn-task-choice-tie-breaks-after-metadata-readiness.md), [0476](../decisions/0476-keep-guided-review-card-and-detail-work-bounded.md), [0468](../decisions/0468-model-task-thinking-needed-separately.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage:
- `Tests/Shared/TaskChoiceFeatureTests.swift`
- `Tests/iOS/AppFeatureTests.swift`

Given a person opens More -> `Review tasks` -> `Help me choose` on compact iOS
When they select available time, energy, and an immediate intent
Then Routina finds currently selectable recurring tasks and unfinished,
uncanceled one-off tasks
And it excludes canceled, paused, snoozed, assumed-done, and current-period-complete tasks
And it excludes tasks with a confirmed `Blocked by` relationship whose
prerequisite is unresolved
And it checks that every eligible task has explicit Importance and Urgency,
Pressure, Thinking needed, and a time estimate
And no visible task metadata is changed while readiness is checked

Given a prerequisite is complete for its current occurrence, completed as a
one-off task, or canceled as a one-off task
When Help me choose loads the dependent task
Then that resolved relationship no longer excludes the dependent task

Given one or more eligible tasks are missing required task-choice data
When the person asks Routina to find the right task
Then it shows the missing-field counts
And it does not make a recommendation until the matching More reviews are complete

Given all eligible tasks have the required data and two have the same
condition-aware score and learned tie-break
When the comparison is prepared
Then Routina asks which task should come first

Given a person chooses one task from a tie-breaking pair
When that choice is saved
Then the preferred task receives a separate learned score one tenth above the
higher score in the pair
And both tasks record that they participated in a comparison
And Routina next asks only another unresolved condition-relevant tie

Given no condition-relevant ties remain
When the current condition is ranked
Then the highest-ranked task is presented as a durable recommendation

Given a recommendation is shown
When the person opens `Check task details`
Then Routina uses the existing Home task-detail route
And learned tie-breaks do not change Importance, Urgency, Pressure, Thinking
needed, Priority, duration, scheduling, planning, task order, or logs

Given the task-choice screen is rendered
When it loads candidates or processes a comparison
Then the reducer owns SwiftData work and the view contains no direct query or
persistence mutation
And the view retains only the visible pair or final recommendation

### Mac Tag Normalization Requires Per-Merge Confirmation

Area: Settings / Tags
Decision links: [0484](../decisions/0484-confirm-conservative-mac-tag-normalization.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/SettingsFeatureTests.swift`

Given Mac Settings -> Tags contains conservative word-form variants such as
`clean` and `Cleaning`
When the tag catalogue is loaded
Then Routina offers a possible duplicate-tag merge without changing data

Given the person selects a proposed merge
When they cancel its confirmation
Then neither tag nor any tagged item changes

Given the person confirms the proposed merge
Then the source tag is replaced everywhere it occurs in tasks, goals, enabled
notes, and events
And an item that already has the replacement tag keeps it only once

### iOS Missing Time Estimate Procedure Uses Direct Presets

Area: Tasks / UI
Decision links: [0480](../decisions/0480-add-guided-ios-time-estimates.md), [0476](../decisions/0476-keep-guided-review-card-and-detail-work-bounded.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage:
- `Tests/Shared/MissingEstimatedDurationDataFeatureTests.swift`
- `Tests/iOS/AppFeatureTests.swift`

Given a person opens More -> `Review tasks` -> `Add missing time estimates` on compact iOS
When the procedure loads
Then Routina includes repeating tasks with no estimated duration and unfinished,
uncanceled one-off tasks with no estimate
And completed or canceled one-off tasks and tasks with an estimate do not appear

Given a task is shown
When the person chooses 15m, 30m, 1h, 2h, 4h, 8h, or 20h, or enters custom
Hours and Minutes
Then Routina keeps that value visibly selected as a temporary draft
When the person taps `Save & next`
Then Routina saves that positive value as `estimatedDurationMinutes` and advances
And it changes neither actual time spent, priority metadata, planning,
scheduling, nor task order

Given the time-estimate card is rendered
Then all seven presets are visible over two wrapped rows without a scrolling
choice list
And Skip and Check task details retain the shared guided-review behavior

### iOS Missing Pressure Procedure Stays Focused And Complete

Area: Tasks / UI
Decision links: [0476](../decisions/0476-keep-guided-review-card-and-detail-work-bounded.md), [0473](../decisions/0473-use-guided-ios-missing-metadata-procedures.md), [0417](../decisions/0417-route-feature-data-loading-through-reducers.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage:
- `Tests/Shared/MissingPressureDataFeatureTests.swift`
- `Tests/Shared/HomeFeatureSelectionRouterTests.swift`
- `Tests/iOSUI/RoutinaUIPerformanceTests.swift`

Given repeating tasks and one-off tasks with Pressure set to `None`, and tasks
already set to Low, Medium, or High
When the user opens More -> `Review tasks` -> `Add missing Pressure data` on compact iOS
Then the repeating `None` tasks and unfinished, uncanceled one-off `None` tasks
are loaded in title order
And completed or canceled one-off tasks do not appear
And the user sees one full-height card at a time with no scrolling list
And the available choices are Low, Medium, and High rather than `None`

Given a procedure card is shown beneath an inline navigation title
When the task counter and progress bar render
Then they have dedicated clearance below the destination title
And the card title begins at the top of its card rather than being vertically centered

Given a missing-pressure task has a custom-section path, tags, and scheduling
or state context
When its procedure card is shown
Then it shows the custom-section path, up to three tags, and up to three
labels such as `Planned today`, `Due tomorrow`, or `Blocked`
And the card does not require scrolling to reach the pressure choices

Given the current procedure card has another missing-pressure task after it
When the user chooses `Skip`
Then the current task remains missing and moves after the remaining cards
And the next task is shown without marking the skipped task complete

Given the current procedure card is shown
When the user chooses `Check task details`
Then Routina selects that task through the existing Home task-detail route

Given the current procedure card receives a non-`None` pressure choice
When the save succeeds
Then the task records that pressure and its normal update activity
And the procedure advances to the next remaining missing-pressure task
And after the final save, the completion state reports that every eligible task
has pressure data

Given the procedure screen is rendered
When it loads or saves task data
Then the reducer's injected model-context dependency owns the SwiftData work
And the SwiftUI view contains no direct query or persistence mutation

Given more than 250 eligible guided-review tasks and a large task-log history
When the user advances cards, opens the selected task's details, and returns
to the procedure repeatedly
Then the procedure retains presentation data for only the visible card
And each next card is loaded through a focused task query
And Home-selected Task Details reuse Home's loaded edit context instead of
refetching every task, place, goal, and log on each round trip

### iOS Missing Thinking Needed Procedure Stays Focused And Independent

Area: Tasks / UI
Decision links: [0478](../decisions/0478-add-guided-ios-thinking-needed-review.md), [0476](../decisions/0476-keep-guided-review-card-and-detail-work-bounded.md), [0468](../decisions/0468-model-task-thinking-needed-separately.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage:
- `Tests/Shared/MissingThinkingNeededDataFeatureTests.swift`
- `Tests/iOS/AppFeatureTests.swift`

Given repeating tasks and one-off tasks with Thinking needed set to `None`, and
tasks already set to Low, Medium, or High
When the user opens More -> `Review tasks` -> `Add missing Thinking needed data` on compact iOS
Then the repeating `None` tasks and unfinished, uncanceled one-off `None` tasks
are loaded in title order
And completed or canceled one-off tasks do not appear
And the user sees one full-height card at a time with no scrolling list
And the available choices are Low, Medium, and High rather than `None`

Given a missing-thinking-needed task is shown
When the user chooses Low, Medium, or High
Then only Thinking needed and the normal task-update activity are saved
And pressure, importance, urgency, priority, duration, and scheduling are unchanged
And the procedure advances to the next remaining task

Given the current Thinking needed procedure card is shown
When the user chooses `Skip` or `Check task details`
Then Skip keeps the task missing and moves it after the remaining cards
And Check task details selects that task through the existing Home route

Given the shared None-valued guided-review reducer receives a neutral `None`
or a value for another metadata field
When it processes the selection
Then it performs no save and does not advance the procedure

Given more than 250 eligible Thinking needed tasks and a large task-log history
When the user advances cards, opens the selected task's details, and returns
to the procedure repeatedly
Then the procedure retains presentation data for only the visible card
And each next card is loaded through a focused task query

### iOS Importance And Urgency Reviews Stay Independent

Area: Tasks / UI
Decision links: [0476](../decisions/0476-keep-guided-review-card-and-detail-work-bounded.md), [0475](../decisions/0475-separate-guided-importance-and-urgency-reviews.md), [0642](../decisions/0642-unify-task-configuration-and-retire-legacy-task-kind-storage.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage:
- `Tests/Shared/MissingTaskMetadataFeatureTests.swift`
- `Tests/iOSUI/RoutinaUIPerformanceTests.swift`
- `Tests/iOS/AppFeatureTests.swift`

Given repeating tasks and unfinished one-off tasks whose own Importance or
Urgency field is still legacy-default and not explicitly reviewed
When the user opens More -> `Review tasks` -> `Review Importance` or `Review Urgency` on compact iOS
Then only tasks missing that selected field are loaded in title order
And completed or canceled one-off tasks do not appear
And a task reviewed for Importance can still appear in Urgency, and vice versa

Given an Importance or Urgency review card is shown beneath an inline navigation title
When the task counter and progress bar render
Then they have dedicated clearance below the destination title
And the card title begins at the top of its card while its actions remain reachable

Given the current review card is shown
When the user chooses one of the four always-visible values
Then that field, its explicitness marker, and the derived Priority persist
And Task Details immediately reflects the selected independent value
And the procedure advances without showing that task again

### iOS Filter Sheets Name Each Choice Once

Area: Tasks / Stats / Timeline / UI
Decision links: [0188](../decisions/0188-prefer-self-explanatory-ui-over-instructional-copy.md), [0537](../decisions/0537-keep-all-ios-home-filter-options-in-persistent-sheets.md), [0548](../decisions/0548-keep-ios-stats-and-timeline-filter-details-in-sheets.md), [0581](../decisions/0581-separate-ios-priority-filter-controls.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage:
- `Tests/Shared/TaskFormIOSLayoutRegressionTests.swift`

Given the person opens the Home, Stats, or Timeline Filters sheet on iOS
When they scan the available filter choices
Then each choice appears as one compact current-value row
And no section heading repeats that row's name
And the Priority heading groups related rows without replacing their independent names

Given the person opens an inline filter picker such as Media
When the detail sheet appears
Then its navigation title identifies the filter
And the picker options begin without repeating the same visible title
And assistive technologies retain a useful control label

### iOS Home Keeps Organization And History Workspaces Reachable

Area: Tasks / Timeline / UI
Decision links: [0033](../decisions/0033-use-app-owned-ios-more-tab.md), [0418](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md), [0664](../decisions/0664-open-ios-workspaces-from-the-home-list.md)
Current behavior: [Tasks](../current-behavior/tasks.md), [UI](../current-behavior/ui.md)
Coverage:
- `Tests/Shared/IOSHomeWorkspaceNavigationSourceTests.swift`

Given the person reaches the end of the iOS Home task list
Then Backlog, Timeline, and Task Ladder appear in that order
And each full visible row opens its workspace through Home navigation
And the bottom tab bar remains unchanged

Given an established Home has no tasks
Then Add New Task remains available
And the same three workspace rows remain below the empty state

Given a new installation has not yet observed its first task
When Home finishes loading an empty task snapshot
Then Backlog, Timeline, and Task Ladder remain hidden until a task is created, imported, restored, or synchronized

Given the person uses the dedicated Search tab
Then the workspace rows do not appear among task-search results

Given the person opens Backlog or Task Ladder from Home
When either workspace presents an unbounded task catalog
Then its reducer-owned cached snapshot feeds the scrolling list
And Home's list body does not derive that workspace presentation

Given the person opens Task Ladder from Home
And a group appears in the current Ladder list
When they use the group's explicit inner-ladder control
Then the group Ladder is pushed as another level in Home's existing navigation hierarchy
And the native Back button returns to the preceding Task Ladder list
And only a later Back action can return from the root Task Ladder to Home

Given the person opens Task Ladder from Home on a compact iOS layout
And a group appears in the current Ladder list
When they activate the group row to open Group Details
Then Group Details is pushed above the current Task Ladder list
And the interactive Back gesture reveals the Task Ladder list underneath
And completing Back returns to that list rather than Home

Given Mac and iOS each created a logical user-preferences singleton before receiving the other device's CloudKit record
And the newer synchronized record contains the Mac Backlog section catalog
When iOS applies the imported preferences
Then Routina keeps the newest record, removes the stale duplicate, and exposes the same Backlog sections on iOS

Given the person opens Timeline from Home
Then Timeline uses Home's existing navigation hierarchy
And it does not install a second compact navigation stack or iPad split hierarchy

Given the person opens Timeline from Home on a compact iOS layout
When they activate a task-backed Timeline row
Then exactly one Task Details screen is pushed above Timeline
And no blank or Home-owned loading destination appears first
And Back returns to the Timeline list rather than directly to Home
