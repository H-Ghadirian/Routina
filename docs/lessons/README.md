# Bug-Fix Lessons

This directory contains durable lessons learned from Routina bug fixes. Each fixed bug gets its own note so the cause and prevention guidance remain easy to find during later development.

## How to Use This Log

- After every bug fix, add one numbered Markdown note and add it to the index below.
- Name notes `NNNN-short-description.md`, using the next available four-digit number.
- Focus on reusable engineering knowledge rather than a chronological work summary.
- Link relevant decision records, regression scenarios, tests, and source files when useful.
- If several symptoms share one root cause and are fixed together, one lesson note is sufficient.
- If a later fix changes the understanding of an older lesson, add a new note and cross-link both rather than rewriting history.

## Note Template

```markdown
# NNNN — Short lesson title

Date: YYYY-MM-DD

## Symptom

What users or developers observed.

## Root Cause

Why the defect occurred.

## Fix

What changed to correct it.

## Prevention Rule

The concrete rule future development should follow.

## Regression Safeguard

Tests, scenarios, assertions, tooling, or review checks that protect against recurrence.
```

## Index

- [0172 — Recheck shortcut availability at execution](0172-recheck-shortcut-availability-at-execution.md)
- [0171 — Derive optional sections from their content](0171-derive-optional-sections-from-their-content.md)
- [0170 — Gate every Timeline type control](0170-gate-every-timeline-type-control.md)
- [0169 — Verify selection summaries at the return surface](0169-verify-selection-summaries-at-the-return-surface.md)
- [0168 — Keep selected choices single-sourced in searchable pickers](0168-keep-selected-choices-single-sourced-in-searchable-pickers.md)
- [0167 — Name each iOS filter choice once](0167-name-each-ios-filter-choice-once.md)
- [0166 — Keep Task Ladder rows individually lazy](0166-keep-task-ladder-rows-individually-lazy.md)
- [0165 — Keep automatic Backlog refreshes silent](0165-keep-automatic-backlog-refreshes-silent.md)
- [0164 — Cache task-detail sidebar locations](0164-cache-task-detail-sidebar-locations.md)
- [0163 — Do not sync unchanged preferences](0163-do-not-sync-unchanged-preferences.md)
- [0162 — Defer iOS Home refreshes during scrolling](0162-defer-ios-home-refreshes-during-scrolling.md)
- [0161 — Keep production iOS profiling setup warm but disposable](0161-speed-up-production-ios-profile-launches.md)
- [0160 — Keep task-time corrections wired to their editing state](0160-keep-task-time-corrections-wired-to-their-editing-state.md)
- [0159 — Keep shared task-detail priority controls visible for routines](0159-keep-shared-task-detail-priority-controls-visible-for-routines.md)
- [0158 — Preserve pressure timestamps during ranking](0158-preserve-pressure-timestamps-during-ranking.md)
- [0157 — Keep Home elapsed status aligned with completion history](0157-keep-home-elapsed-status-aligned-with-completion-history.md)
- [0156 — Keep iOS performance flows aligned with compact navigation](0156-keep-ios-performance-flows-aligned-with-compact-navigation.md)
- [0155 — Cache sidebar filter-summary counts](0155-cache-sidebar-filter-summary-counts.md)
- [0154 — Keep startup data maintenance off the main actor](0154-keep-startup-data-maintenance-off-the-main-actor.md)
- [0153 — Link Search-tab selection to search activation](0153-link-search-tab-selection-to-search-activation.md)
- [0152 — Keep large Search restoration off the main actor](0152-keep-large-search-restoration-off-main-actor.md)
- [0151 — Move large Search presentations off the main actor](0151-move-large-search-presentations-off-main-actor.md)
- [0150 — Defer unreachable tag configuration](0150-defer-unreachable-tag-configuration.md)
- [0149 — Gate iOS task-row appearance controls](0149-gate-ios-task-row-appearance-controls.md)
- [0148 — Coalesce Backlog refreshes](0148-coalesce-backlog-refreshes.md)
- [0147 — Keep Flag assignment aligned with auto-assume eligibility](0147-keep-flag-assignment-aligned-with-auto-assume-eligibility.md)
- [0146 — Derive elapsed completion status from recorded history](0146-derive-elapsed-completion-status-from-recorded-history.md)
- [0145 — Own iOS filter details at stable sheet roots](0145-own-ios-filter-details-at-stable-sheet-roots.md)
- [0144 — Route optional dashboard prompts through dashboard customization](0144-route-optional-dashboard-prompts-through-dashboard-customization.md)
- [0143 — Treat device verification as revision-specific](0143-treat-device-verification-as-revision-specific.md)
- [0142 — Bound iOS foreground CloudKit reconciliation](0142-bound-ios-foreground-cloudkit-reconciliation.md)
- [0141 — Scope the iOS search field to its Search tab](0141-scope-ios-search-field-to-search-tab.md)
- [0140 — Defer inactive iOS tab refreshes](0140-defer-inactive-ios-tab-refreshes.md)
- [0139 — Keep iOS search input ahead of Home presentation work](0139-keep-ios-search-input-ahead-of-home-presentation-work.md)
- [0138 — Gate Add Task goals with feature availability](0138-gate-add-task-goals-with-feature-availability.md)
- [0137 — Use a reliable glyph for the Mac overflow trigger](0137-use-reliable-glyph-for-mac-overflow-trigger.md)
- [0136 — Give overflow controls visible idle chrome](0136-give-overflow-controls-visible-idle-chrome.md)
- [0135 — Gate Home Goal filters with feature availability](0135-gate-home-goal-filter-with-feature-availability.md)
- [0134 — Keep active tag filter rules identifiable](0134-keep-active-tag-filter-rules-identifiable.md)
- [0133 — Defer large tag catalogs from iOS filter scrolls](0133-defer-large-tag-catalogs-from-ios-filter-scrolls.md)
- [0132 — Let iOS Flag chips wrap before truncating](0132-let-ios-flag-chips-wrap-before-truncating.md)
- [0131 — Let compact iOS tag chips wrap before truncating](0131-let-compact-ios-tag-chips-wrap-before-truncating.md)
- [0130 — Anchor nested pickers to stable form roots](0130-anchor-nested-pickers-to-stable-form-roots.md)
- [0129 — Verify dictionary inference in iOS builds](0129-verify-dictionary-inference-in-ios-builds.md)
- [0128 — Let task-detail tags use their intrinsic width](0128-let-task-detail-tags-use-their-intrinsic-width.md)
- [0127 — Keep desktop sheet minimum sizes out of iOS presentations](0127-keep-desktop-sheet-minimum-sizes-out-of-ios-presentations.md)
- [0126 — Discover remotely started Focus during iOS reconciliation](0126-discover-remotely-started-focus-during-ios-reconciliation.md)
- [0125 — Keep synthetic completion and notification eligibility aligned](0125-keep-synthetic-completion-and-notification-eligibility-aligned.md)
- [0124 — Allow unchanged async Settings state](0124-allow-unchanged-async-settings-state.md)
- [0123 — Keep disabled features out of iCloud usage](0123-keep-disabled-features-out-of-cloud-usage.md)
- [0122 — Distinguish a CloudKit download from an export](0122-distinguish-cloudkit-download-from-export.md)
- [0121 — Decode partial CloudKit failures without copying user data](0121-decode-partial-cloudkit-failures-without-copying-user-data.md)
- [0120 — Archive symbols for externally built helper tools](0120-archive-symbols-for-externally-built-helper-tools.md)
- [0001 — Number mixed timeline entries in display order](0001-number-mixed-timeline-entries-in-display-order.md)
- [0002 — Keep Timeline change detection out of the render path](0002-keep-timeline-change-detection-out-of-render-path.md)
- [0003 — Separate Home maintenance from refresh](0003-separate-home-maintenance-from-refresh.md)
- [0004 — Do not reload Stats on view reappearance](0004-do-not-reload-stats-on-view-reappearance.md)
- [0005 — Defer AppKit responder changes out of `updateNSView`](0005-defer-appkit-responder-changes-out-of-update-ns-view.md)
- [0006 — Keep expanded sidebar groups lazy and stably identified](0006-keep-expanded-sidebar-groups-lazy-and-stably-identified.md)
- [0007 — Keep Timeline row compositing and refreshes off the scroll frame](0007-keep-timeline-row-compositing-and-refreshes-off-the-scroll-frame.md)
- [0008 — Keep assumed completion visually distinct from recorded completion](0008-keep-assumed-completion-visually-distinct.md)
- [0009 — Never install empty Mac context menus](0009-never-install-empty-mac-context-menus.md)
- [0010 — Keep Mac sidebar context-menu tracking out of SwiftUI](0010-keep-mac-sidebar-context-menu-tracking-out-of-swiftui.md)
- [0011 — Route every collapsible sidebar group through persisted state](0011-route-collapsible-sidebar-groups-through-persisted-state.md)
- [0012 — Preserve scroll position across sidebar disclosure changes](0012-preserve-scroll-position-across-sidebar-disclosure-changes.md)
- [0013 — Do not expose fallback recurrence for cadence-free tasks](0013-do-not-expose-fallback-recurrence-for-cadence-free-tasks.md)
- [0014 — Present the Mac Add Task emoji picker as a sheet](0014-present-mac-add-task-emoji-picker-as-a-sheet.md)
- [0015 — Persist deliberately revealed task-detail controls](0015-persist-deliberately-revealed-task-detail-controls.md)
- [0016 — Defer Mac sharing-service discovery until selection](0016-defer-mac-sharing-service-discovery.md)
- [0017 — Bound growing form suggestion lists](0017-bound-growing-form-suggestion-lists.md)
- [0018 — Derive mirrored form labels from one section model](0018-derive-mirrored-form-labels-from-one-section-model.md)
- [0019 — Distinguish neutral defaults from explicit Quick Add metadata](0019-distinguish-neutral-defaults-from-explicit-quick-add-metadata.md)
- [0020 — Put hit shapes inside control labels](0020-put-hit-shapes-inside-control-labels.md)
- [0021 — Place shared actions before conditional actions](0021-place-shared-actions-before-conditional-actions.md)
- [0022 — Do not infer optional-section intent from legacy defaults](0022-do-not-infer-optional-section-intent-from-legacy-defaults.md)
- [0023 — Derive Stats comparisons from range duration](0023-derive-stats-comparisons-from-range-duration.md)
- [0024 — Fit chart annotations within chart bounds](0024-fit-chart-annotations-within-chart-bounds.md)
- [0025 — Keep preselected relationships resolvable](0025-keep-preselected-relationships-resolvable.md)
- [0026 — Clear detail selection on transient navigation](0026-clear-detail-selection-on-transient-navigation.md)
- [0027 — Preserve detail across transient Add Task](0027-preserve-detail-across-transient-add-task.md)
- [0028 — Preserve task context across Stats navigation](0028-preserve-task-context-across-stats-navigation.md)
- [0029 — Name linked-task actions by their destination](0029-name-linked-task-actions-by-destination.md)
- [0030 — Gate all recurrence behavior behind effective cadence](0030-gate-all-recurrence-behavior-behind-effective-cadence.md)
- [0031 — Preserve structured recurrence through edit state](0031-preserve-structured-recurrence-through-edit-state.md)
- [0032 — Use the structured-storage contract at sync boundaries](0032-use-the-structured-storage-contract-at-sync-boundaries.md)
- [0032 — Share relationship intent across linked-task entry points](0032-share-relationship-intent-across-linked-task-entry-points.md)
- [0033 — Match recurrence control cardinality to storage](0033-match-recurrence-control-cardinality-to-storage.md)
- [0034 — Drive recurrence editors from the lossless draft](0034-drive-recurrence-editors-from-the-lossless-draft.md)
- [0035 — Apply composed recurrence semantics at every runtime boundary](0035-apply-composed-recurrence-semantics-at-every-runtime-boundary.md)
- [0036 — Centralize occurrence resolution identity](0036-centralize-occurrence-resolution-identity.md)
- [0037 — Persist the selected occurrence timestamp](0037-persist-the-selected-occurrence-timestamp.md)
- [0038 — Keep Add Task autosave out of render paths](0038-keep-add-task-autosave-out-of-render-paths.md)
- [0039 — Gate appearance controls with feature availability](0039-gate-appearance-controls-with-feature-availability.md)
- [0040 — Retire product concepts across all presentation surfaces](0040-retire-product-concepts-across-all-presentation-surfaces.md)
- [0041 — Do not repeat complete form values as summaries](0041-do-not-repeat-complete-form-values-as-summaries.md)
- [0042 — Separate early completion time from scheduled occurrence](0042-separate-early-completion-time-from-scheduled-occurrence.md)
- [0043 — Pair optional actions with their render path](0043-pair-optional-actions-with-their-render-path.md)
- [0044 — Keep progressive controls after their trigger](0044-keep-progressive-controls-after-their-trigger.md)
- [0045 — Model planning as an additive projection](0045-model-planning-as-an-additive-projection.md)
- [0046 — Do not route section actions through duplicate editors](0046-do-not-route-section-actions-through-duplicate-editors.md)
- [0047 — Localize dynamic controls to their owner](0047-localize-dynamic-controls-to-their-owner.md)
- [0048 — Separate disclosure state from feature state](0048-separate-disclosure-state-from-feature-state.md)
- [0049 — Separate completion identity from work timing](0049-separate-completion-identity-from-work-timing.md)
- [0050 — Use occurrence resolution in day projections](0050-use-occurrence-resolution-in-day-projections.md)
- [0051 — Isolate Add Task event catalog refresh](0051-isolate-add-task-event-catalog-refresh.md)
- [0052 — Stage locate scrolling through lazy ancestors](0052-stage-locate-scrolling-through-lazy-ancestors.md)
- [0053 — Match day projections against the authoritative recurrence](0053-match-day-projections-against-authoritative-recurrence.md)
- [0054 — Resolve Planner assumptions before snapshot refresh](0054-resolve-planner-assumptions-before-snapshot-refresh.md)
- [0055 — Resolve today before advancing recurrence](0055-resolve-today-before-advancing-recurrence.md)
- [0056 — Preserve local drafts across catalog writes](0056-preserve-local-drafts-across-catalog-writes.md)
- [0057 — Prefer discrete reordering in drag-heavy lists](0057-prefer-discrete-reordering-in-drag-heavy-lists.md)
- [0058 — Separate Planner time data from display density](0058-separate-planner-time-data-from-display-density.md)
- [0059 — Only nest menu destinations that have children](0059-only-nest-menu-destinations-that-have-children.md)
- [0060 — Distinguish automatic placement from missing placement](0060-distinguish-automatic-placement-from-missing-placement.md)
- [0061 — Keep task-creation confirmation explicit](0061-keep-task-creation-confirmation-explicit.md)
- [0062 — Contrast labels against glass selection surfaces](0062-contrast-labels-against-glass-selection-surfaces.md)
- [0063 — Avoid stacking low-contrast semantic styles](0063-avoid-stacking-low-contrast-semantic-styles.md)
- [0064 — Gate global entry points with feature availability](0064-gate-global-entry-points-with-feature-availability.md)
- [0065 — Keep Stats history out of scroll builders](0065-keep-stats-history-out-of-scroll-builders.md)
- [0066 — Refetch iOS Timeline after sync invalidation](0066-refetch-ios-timeline-after-sync-invalidation.md)
- [0067 — Match New-action presentation to cardinality](0067-match-new-action-presentation-to-cardinality.md)
- [0068 — Prioritize segment labels at compact widths](0068-prioritize-segment-labels-at-compact-widths.md)
- [0069 — Do not inherit fixed preference-window capabilities](0069-do-not-inherit-fixed-preference-window-capabilities.md)
- [0070 — Do not use standalone dividers as Form rows](0070-do-not-use-standalone-dividers-as-form-rows.md)
- [0071 — Centralize cross-platform action eligibility](0071-centralize-cross-platform-action-eligibility.md)
- [0072 — Choose a window host that supports required capabilities](0072-choose-a-window-host-that-supports-required-capabilities.md)
- [0073 — Declare export compliance in production plists](0073-declare-export-compliance-in-production-plists.md)
- [0074 — Render Markdown blocks as visible structure](0074-render-markdown-blocks-as-visible-structure.md)
- [0075 — Enforce hidden features at the preference boundary](0075-enforce-hidden-features-at-the-preference-boundary.md)
- [0076 — Cache iOS main-screen presentations](0076-cache-ios-main-screen-presentations.md)
- [0077 — Avoid Liquid Glass multiplication in scrolling forms](0077-avoid-liquid-glass-multiplication-in-scrolling-forms.md)
- [0078 — Do not resolve sandboxed app data from external processes](0078-do-not-resolve-sandboxed-app-data-from-external-processes.md)
- [0079 — Keep guided metadata procedures reducer-owned](0079-keep-guided-metadata-procedures-reducer-owned.md)
- [0080 — Exclude finished one-off tasks from metadata procedures](0080-exclude-finished-one-off-tasks-from-metadata-procedures.md)
- [0081 — Bound guided review and detail loading](0081-bound-guided-review-and-detail-loading.md)
- [0082 — Keep Simulator UI-test host and runtime links aligned](0082-keep-simulator-ui-test-host-and-runtime-links-aligned.md)
- [0083 — Keep guided-review progress clear of navigation titles](0083-keep-guided-review-progress-clear-of-navigation-titles.md)
- [0084 — Reject neutral values in shared guided reviews](0084-reject-neutral-values-in-shared-guided-reviews.md)
- [0085 — Keep one-off completion permanent](0085-keep-one-off-completion-permanent.md)
- [0086 — Keep batch AI failures task-scoped](0086-keep-batch-ai-failures-task-scoped.md)
- [0087 — Deduplicate planner block records before rendering](0087-deduplicate-planner-block-records-before-rendering.md)
- [0088 — Keep one-off auto-assume controls out of recurrence-only branches](0088-keep-one-off-auto-assume-controls-out-of-recurrence-only-branches.md)
- [0089 — Refresh time-derived Home displays before filtering](0089-refresh-time-derived-home-displays-before-filtering.md)
- [0090 — Carry defined catalogs through task-form state](0090-carry-defined-catalogs-through-task-form-state.md)
- [0091 — Refresh Home after flag-rule changes](0091-refresh-home-after-flag-rule-changes.md)
- [0092 — Carry flags into Home display snapshots](0092-carry-flags-into-home-display-snapshots.md)
- [0093 — Keep task-list Flags in the task-list filter pane](0093-keep-task-list-flags-in-the-task-list-filter-pane.md)
- [0094 — Explain hidden task Flags in details](0094-explain-hidden-task-flags-in-details.md)
- [0095 — Validate Flag rules at selection time](0095-validate-flag-rules-at-selection-time.md)
- [0096 — Validate renamed SwiftUI types](0096-validate-renamed-swiftui-types.md)
- [0097 — Verify shared component references in platform forms](0097-verify-shared-component-references.md)
- [0098 — Keep direct task linkers on the full preloaded catalog](0098-keep-direct-task-linkers-on-the-full-preloaded-catalog.md)
- [0099 — Preserve task-list presentation across Stats navigation](0099-preserve-task-list-presentation-across-stats-navigation.md)
- [0100 — Keep task-detail comment editor bindings live](0100-keep-task-detail-comment-editor-bindings-live.md)
- [0101 — Share adaptive Task Detail metadata layouts](0101-share-adaptive-task-detail-metadata-layouts.md)
- [0102 — Keep Mac task-form and search work frame-safe](0102-keep-mac-task-form-and-search-work-frame-safe.md)
- [0103 — Return opaque task-form views after local setup](0103-return-opaque-task-form-views-after-local-setup.md)
- [0104 — Reconcile active Focus after CloudKit import delay](0104-reconcile-active-focus-after-cloud-import-delay.md)
- [0105 — Keep Timeline preview and row rendering aligned](0105-keep-timeline-preview-and-row-rendering-aligned.md)
- [0106 — Let assigned Flag chips use available width](0106-let-assigned-flag-chips-use-available-width.md)
- [0107 — Name repeatable cadence-free completions](0107-name-repeatable-cadence-free-completions.md)
- [0108 — Keep iOS Add More Details last](0108-keep-ios-add-more-details-last.md)
- [0109 — Wrap five-option iOS filter segments](0109-wrap-five-option-ios-filter-segments.md)
- [0110 — Cache Home row numbers outside List builders](0110-cache-home-row-numbers-outside-list-builders.md)
- [0111 — Gate the Mac sleep command by the Away setting](0111-gate-mac-sleep-command-by-away-setting.md)
- [0112 — Measure the full task-detail summary before wrapping](0112-measure-the-full-task-detail-summary-before-wrapping.md)
- [0113 — Preserve assumed one-off time blocks on confirmation](0113-preserve-assumed-one-off-time-blocks-on-confirmation.md)
- [0114 — Gate every production-excluded platform branch](0114-gate-every-production-excluded-platform-branch.md)
- [0115 — Declare both HealthKit purpose strings](0115-declare-both-healthkit-purpose-strings.md)
- [0116 — Compile out protected experimental services](0116-compile-out-protected-experimental-services.md)
- [0117 — Report signed CloudKit environment in diagnostics](0117-report-signed-cloudkit-environment-in-diagnostics.md)
- [0118 — Sandbox every embedded macOS executable](0118-sandbox-every-embedded-macos-executable.md)
- [0119 — Scope Security task entitlement reads to macOS](0119-scope-security-task-entitlement-reads-to-macos.md)
