import Foundation
import XCTest
@testable @preconcurrency import RoutinaMacOSDev

final class PerformanceRegressionTests: XCTestCase {
    func testMacFocusStartUsesOneRecallingSheet() throws {
        let controlsSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacSidebarModeStripView.swift"
        )
        let pickerSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacFocusTimerPickerViews.swift"
        )
        let homeSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView.swift"
        )
        let platformSource = try SourceInspectionSupport.readMacHomePlatformSources()

        XCTAssertTrue(controlsSource.contains("case .focus:\n            onFocus()"))
        XCTAssertFalse(
            controlsSource.contains("HomeMacPlanFocusToolbarButton"),
            "The New menu Focus action should open the recalling sheet without restoring a second Planner button."
        )
        XCTAssertTrue(pickerSource.contains("private var durationPicker: some View"))
        XCTAssertTrue(pickerSource.contains("Last choice:"))
        XCTAssertTrue(pickerSource.contains("FocusSessionStartDefaults.rememberDuration(selectedDuration)"))
        XCTAssertTrue(pickerSource.contains("plannedDurationSeconds: selectedDuration"))
        XCTAssertFalse(pickerSource.contains("focusSessions.reduce"))
        XCTAssertTrue(platformSource.contains("func presentHomeToolbarFocusPicker()"))
        XCTAssertTrue(platformSource.contains("FocusSessionStartDefaults.rememberedDuration()"))
        XCTAssertTrue(pickerSource.contains("FocusSessionStartDefaults.latest("))
        XCTAssertTrue(homeSource.contains(".sheet(item: $homeToolbarFocusPickerPresentation)"))
        XCTAssertTrue(homeSource.contains("tasks: presentation.tasks"))
        XCTAssertTrue(homeSource.contains("availableTags: presentation.availableTags"))
        XCTAssertTrue(platformSource.contains("HomeMacFocusTimerPickerPresentation.make("))
        XCTAssertFalse(homeSource.contains("homeToolbarFocusPickerAvailableTags"))
        XCTAssertFalse(homeSource.contains("homeToolbarFocusPickerDuration"))
    }

    func testMacFocusPickerPresentationSnapshotsTasksTagsAndDefaultsTogether() {
        let task = RoutineTask(
            name: "Exercise",
            tags: ["Health"],
            scheduleMode: .fixedInterval
        )

        let presentation = HomeMacFocusTimerPickerPresentation.make(
            tasks: [task],
            focusSessions: [],
            rememberedDuration: 0
        )

        XCTAssertEqual(presentation.tasks.map(\.id), [task.id])
        XCTAssertEqual(presentation.availableTags, ["Health"])
        XCTAssertEqual(presentation.defaults.duration, 0)
        XCTAssertNil(presentation.defaults.tagName)
    }

    func testMacTaskCreatedToastAnchorsItsTrailingActions() throws {
        let toastSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/MacQuickAddCreatedToastView.swift"
        )

        XCTAssertTrue(
            toastSource.contains(
                """
                            Spacer(minLength: 12)

                            if let onOpen {
                """
            ),
            "The flexible gap must sit before the toast actions so unused width does not become trailing padding."
        )

        let platformSource = try SourceInspectionSupport.readMacHomePlatformSources()
        let fullFormConfirmationStart = try XCTUnwrap(
            platformSource.range(of: "if let taskCreationConfirmation = store.taskCreationConfirmation")
        )
        let quickAddConfirmationStart = try XCTUnwrap(
            platformSource.range(
                of: "if let quickAddCreatedToast",
                range: fullFormConfirmationStart.upperBound..<platformSource.endIndex
            )
        )
        let fullFormConfirmation = platformSource[
            fullFormConfirmationStart.lowerBound..<quickAddConfirmationStart.lowerBound
        ]

        XCTAssertTrue(
            fullFormConfirmation.contains("onOpen: nil"),
            "Full Add Task already opens the saved task detail, so its confirmation must not offer a redundant action."
        )
    }

    func testMacDeepLinkMenuDefersSystemSharingServiceDiscovery() throws {
        let source = try Self.sourceFile(
            "SharedCore/Views/RoutinaDeepLinkShareViews.swift"
        )

        XCTAssertTrue(source.contains("RoutinaDeepLinkSharingPresenter.present(deepLink.url)"))
        XCTAssertTrue(source.contains("NSSharingServicePicker(items: [url])"))
        XCTAssertTrue(source.contains("DispatchQueue.main.async {"))
        XCTAssertFalse(
            source.contains(
                """
                #if os(macOS)
                ShareLink(item: deepLink.url)
                """
            ),
            "The Mac menu must not embed ShareLink because it can discover system sharing services while the outer menu opens."
        )
    }

    func testMacTaskDetailLinkMenuFillsItsVisibleHitSurface() throws {
        let source = try Self.sourceFile(
            "SharedCore/Views/RoutinaDeepLinkShareViews.swift"
        )

        XCTAssertTrue(
            source.contains(
                """
                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                """
            ),
            "The plain toolbar menu label must fill the surrounding icon chrome so its whole visible surface is clickable."
        )
    }

    func testMacTaskDetailCompletionAndOverflowShareLifecycleControl() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailToolbarContent.swift"
        )
        let lifecycleControlStart = try XCTUnwrap(
            source.range(of: "private var taskLifecycleControl: some View")
        )
        let completionButtonStart = try XCTUnwrap(
            source.range(
                of: "private func completionActionButton",
                range: lifecycleControlStart.upperBound..<source.endIndex
            )
        )
        let lifecycleControlSource = source[
            lifecycleControlStart.lowerBound..<completionButtonStart.lowerBound
        ]
        let completionAction = try XCTUnwrap(
            lifecycleControlSource.range(of: "completionActionButton(isGrouped: true)")
        )
        let moreActionsMenu = try XCTUnwrap(
            lifecycleControlSource.range(of: "taskLifecycleActionsMenu")
        )

        XCTAssertLessThan(
            completionAction.lowerBound,
            moreActionsMenu.lowerBound,
            "Done must remain left of the overflow menu for secondary task actions."
        )
        XCTAssertTrue(
            lifecycleControlSource.contains("HStack(spacing: 0)"),
            "Done and its related overflow must share one joined control without an inter-button gap."
        )
        XCTAssertTrue(
            lifecycleControlSource.contains(
                ".clipShape(RoundedRectangle(cornerRadius: Metrics.textCornerRadius"
            ),
            "The lifecycle control must own one shared rounded outer shape."
        )
        XCTAssertFalse(
            lifecycleControlSource.contains("store.send(.cancelTodo)"),
            "Cancel Todo belongs in the overflow menu instead of competing with Done."
        )
        XCTAssertFalse(
            lifecycleControlSource.contains("store.send(store.task.isArchived() ? .resumeTapped : .pauseTapped)"),
            "Archive/Restore and Pause/Resume belong in the overflow menu instead of competing with Done."
        )
    }

    func testMacAddTaskEmojiChooserUsesStableSheetPresentation() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/AddRoutine/AddRoutineTCAViewPlatform.swift"
        )

        XCTAssertTrue(source.contains("sheet(isPresented: isPresented)"))
        XCTAssertFalse(
            source.contains("popover(isPresented: isPresented"),
            "The progressively composed Add Task identity control must not use the crashing popover presentation path."
        )
    }

    func testMacTimelineDoesNotBindWholeHistoryQueriesIntoRenderPath() throws {
        let source = try Self.sourceFile("RoutinaMacApp/Screens/Timeline/TimelineView.swift")

        XCTAssertFalse(
            source.contains("@Query"),
            "Timeline scrolling must not observe whole-history SwiftData queries from the view render path."
        )
        XCTAssertTrue(source.contains("@State private var dataSnapshot = TimelineDataSnapshot()"))
        XCTAssertTrue(source.contains("TimelineDataSnapshot.fetch(from: modelContext)"))
        XCTAssertTrue(source.contains("NotificationCenter.default.publisher(for: .routineDidUpdate)"))
        XCTAssertTrue(source.contains("RoutinaMacScrollInteractionGate.isScrollActive"))
        XCTAssertFalse(
            source.contains("timelineDataChangeToken"),
            "Timeline must not rebuild full-history string signatures during SwiftUI body evaluation."
        )
    }

    func testDisabledEmotionFeatureExcludesEmotionRowsFromMacTimelines() throws {
        let standaloneSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Timeline/TimelineView.swift"
        )
        let integratedSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Timeline.swift"
        )

        XCTAssertTrue(
            standaloneSource.contains(
                "areMacEventEmotionActionsEnabled ? dataSnapshot.emotionLogs : []"
            ))
        XCTAssertTrue(
            integratedSource.contains(
                "let visibleEmotionLogs = areMacEventEmotionActionsEnabled ? emotionLogs : []"
            ))
        XCTAssertEqual(
            integratedSource.components(separatedBy: "emotionLogs: visibleEmotionLogs").count - 1,
            2
        )
    }

    func testDisabledEventFeatureExcludesEventRowsFromMacTimelineAndPlannerSnapshots() throws {
        let standaloneSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Timeline/TimelineView.swift"
        )
        let integratedSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Timeline.swift"
        )
        let plannerSource =
            try Self.sourceFile("SharedCore/Views/DayPlanView.swift")
            + "\n"
            + (try Self.sourceFile("SharedCore/Views/DayPlan/DayPlanTimelineRenderSnapshotCache.swift"))
        let homeSidebarSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Sidebar.swift"
        )
        let homePlatformSource = try SourceInspectionSupport.readMacHomePlatformSources()

        XCTAssertTrue(
            standaloneSource.contains(
                "areMacEventEmotionActionsEnabled ? dataSnapshot.events : []"
            ))
        XCTAssertTrue(
            integratedSource.contains(
                "let visibleEvents = areMacEventEmotionActionsEnabled ? events : []"
            ))
        XCTAssertEqual(
            integratedSource.components(separatedBy: "events: visibleEvents").count - 1,
            2
        )
        XCTAssertTrue(plannerSource.contains("let visibleEvents = includesEvents ? events : []"))
        XCTAssertTrue(plannerSource.contains("var includesEvents: Bool"))
        XCTAssertTrue(plannerSource.contains("from: visibleEvents"))
        XCTAssertTrue(plannerSource.contains("events: visibleEvents"))
        XCTAssertTrue(
            plannerSource.contains(
                "guard includesEvents, calendarFilterState.showsEvents else { return [] }"
            ))
        XCTAssertTrue(
            homeSidebarSource.contains(
                "func openAddEvent() {\n        guard areMacEventEmotionActionsEnabled else { return }"
            ))
        XCTAssertTrue(
            homePlatformSource.contains(
                "areMacEventEmotionActionsEnabled && isEventEditorPresented"
            ))
    }

    func testDisabledSleepFeatureExcludesSleepRowsFromMacTimelines() throws {
        let standaloneSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Timeline/TimelineView.swift"
        )
        let integratedSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Timeline.swift"
        )
        let integratedOwnerSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView.swift"
        )

        XCTAssertTrue(
            standaloneSource.contains(
                "includesSleepTimelineFilters ? dataSnapshot.sleepSessions : []"
            ))
        XCTAssertTrue(
            standaloneSource.contains(
                ".onChange(of: isStatsSleepTabEnabled)"
            ))
        XCTAssertTrue(
            integratedSource.contains(
                "let visibleSleepSessions = includesMacSleepTimelineFilters ? sleepSessions : []"
            ))
        XCTAssertEqual(
            integratedSource.components(separatedBy: "sleepSessions: visibleSleepSessions").count - 1,
            2
        )
        XCTAssertTrue(
            integratedOwnerSource.contains(
                ".onChange(of: isStatsSleepTabEnabled)"
            ))
    }

    func testPlannerAdaptiveTimeAxisUsesVisibleSnapshotsWithoutPersistenceWork() throws {
        let axisSource = try Self.sourceFile(
            "SharedCore/Views/DayPlan/DayPlanSupport.swift"
        )
        let calendarSource = try Self.sourceFile(
            "SharedCore/Views/DayPlan/DayPlanWeekCalendarView.swift"
        )

        XCTAssertTrue(axisSource.contains("final class DayPlanAdaptiveTimeAxisCache"))
        XCTAssertTrue(calendarSource.contains("@StateObject private var adaptiveTimeAxisCache"))
        XCTAssertTrue(calendarSource.contains("private var adaptiveTimeAxisIntervals"))
        XCTAssertTrue(calendarSource.contains("for date in dates"))
        XCTAssertFalse(axisSource.contains("FetchDescriptor"))
        XCTAssertFalse(axisSource.contains("ModelContext"))
        XCTAssertFalse(calendarSource.contains("FetchDescriptor"))
        XCTAssertFalse(calendarSource.contains("ModelContext"))
    }

    func testMacToolbarSearchDefersResponderMutationsPastRepresentableUpdate() throws {
        let source = try Self.homeMacToolbarSource()

        XCTAssertTrue(
            source.contains("DispatchQueue.main.async { [weak coordinator = context.coordinator]"),
            "Responder changes can synchronously invoke AppKit delegates, so they must run after updateNSView returns."
        )
        XCTAssertFalse(
            source.contains(
                "context.coordinator.dismissFocusIfNeeded(for: focusDismissRequestID)\n        context.coordinator.focusIfNeeded(for: focusRequestID)"
            )
        )
    }

    func testMacTaskFormsAndToolbarSearchKeepInputWorkOutOfScrollAndKeystrokeFrames() throws {
        let formSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Shared/TaskFormContentPlatform.swift"
        )
        let cardSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Shared/TaskFormMacCards.swift"
        )
        let searchFieldSource = try Self.homeMacToolbarSource()
        let searchPresentationSource = try SourceInspectionSupport.readMacHomePlatformSources()
        let filteringSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Filtering.swift"
        )

        XCTAssertTrue(formSource.contains("LazyVStack(alignment: .leading, spacing: 20)"))
        XCTAssertTrue(formSource.contains(".routinaSegmentedControlSurfaceStyle(.scrolling)"))
        XCTAssertTrue(formSource.contains("return TaskFormMacIdentityCard("))
        XCTAssertTrue(cardSource.contains(".routinaScrollingPillFill(tint: tint, tintOpacity: tintOpacity)"))
        XCTAssertFalse(cardSource.contains(".routinaGlassPanel(cornerRadius: 14, tint: .secondary, tintOpacity: 0.06)"))
        XCTAssertTrue(
            searchFieldSource.contains(
                "func controlTextDidChange(_ notification: Notification) {\n            syncSearchText(from: notification.object)\n        }"
            ),
            "Typing must update the binding without scheduling responder repairs for every character."
        )
        XCTAssertTrue(searchPresentationSource.contains("HomeMacSearchPresentationPolicy.inputDebounce"))
        XCTAssertTrue(searchPresentationSource.contains("isMacSearchPresentationCurrent"))
        XCTAssertTrue(filteringSource.contains("searchText: macSearchPresentationText"))
    }

    func testMacExpandedTaskSidebarKeepsNestedRowsLazyAndStable() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+TaskListSections.swift"
        )

        XCTAssertTrue(
            source.contains("LazyVStack(alignment: .leading, spacing: taskListTaskRowSpacing())")
        )
        XCTAssertTrue(
            source.contains("LazyVStack(alignment: .leading, spacing: taskListGroupStackSpacing(for: section))")
        )
        XCTAssertFalse(
            source.contains(".id(taskListTaskGroupsRenderIdentity(taskGroups))"),
            "Scrolling must not walk all nested task IDs or replace group identity during rendering."
        )
    }

    func testMacSidebarFilterSummaryUsesCachedTaskListPresentation() throws {
        let sidebarSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Sidebar.swift"
        )
        let presentationSource = try Self.sourceFile(
            "SharedCore/Features/Home/HomeTaskListPresentation.swift"
        )

        XCTAssertTrue(sidebarSource.contains("macTaskListPresentation("))
        XCTAssertTrue(sidebarSource.contains(".visibleTaskCount"))
        XCTAssertFalse(
            sidebarSource.contains("sidebarVisibleTaskCount("),
            "A SwiftUI sidebar summary must not rescan every task while the list is rendering or scrolling."
        )
        XCTAssertTrue(presentationSource.contains("let visibleTaskCount: Int"))
        XCTAssertTrue(
            presentationSource.contains(
                "self.visibleTaskCount = sections.reduce(0) { $0 + $1.tasks.count }"
            ),
            "The immutable task-list snapshot must cache its visible count for sidebar summaries."
        )
    }

    func testMacTaskListSignatureDoesNotWalkRoutineTasksFromRenderPath() throws {
        let filteringSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Filtering.swift"
        )
        let displaySource = try Self.sourceFile(
            "RoutinaMacApp/Features/Home/HomeFeature+Display.swift"
        )
        let predicateSource = try Self.sourceFile(
            "SharedCore/Features/Home/HomeTaskListPredicate.swift"
        )

        XCTAssertFalse(filteringSource.contains("HomeMacTaskListRelationshipTaskSignature"))
        XCTAssertFalse(filteringSource.contains("routineTasks.map("))
        XCTAssertTrue(
            displaySource.contains("HomeDisplayFilterSupport.activeRelationshipBlockedTaskIDs("),
            "Relationship availability must be derived at the Home display refresh boundary."
        )
        XCTAssertTrue(predicateSource.contains("return !task.hasActiveRelationshipBlocker"))
        XCTAssertFalse(
            predicateSource.contains("tasks: configuration.routineTasks"),
            "Filtering a presentation row must not search the full SwiftData task collection."
        )
    }

    func testMacCustomSubsectionsUseTagStyleSurfaceAndPersistedCollapseState() throws {
        let taskListSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+TaskListSections.swift"
        )
        let taskListExpansionSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+TaskListExpansion.swift"
        )

        XCTAssertTrue(
            taskListSource.contains(
                """
                group.kind == .custom
                                || group.kind == .tag
                """
            ),
            "Custom subsections must use the same nested section surface as tag subsections."
        )
        XCTAssertEqual(
            taskListExpansionSource.components(
                separatedBy: "case .custom, .deadlineDate, .tag, .untagged, .regular:"
            ).count - 1,
            4,
            "Live toggle, reveal, and snapshot visibility must all route custom subsections through persisted collapse IDs."
        )
    }

    func testMacCustomSectionMenusSeedNewTasksAndFormsExposePathPicker() throws {
        let taskListSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+TaskListMenus.swift"
        )
        let formSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Shared/TaskFormMacCards.swift"
        )

        XCTAssertGreaterThanOrEqual(
            taskListSource.components(
                separatedBy: "store.send(.openAddTaskInCustomSection(customSectionID))"
            ).count - 1,
            2,
            "Both custom super-section and subsection menus must seed Add Task with their section."
        )
        XCTAssertTrue(formSource.contains("Label(\"Path\""))
        XCTAssertTrue(formSource.contains("model.customTaskSectionID.wrappedValue = sectionID"))
        XCTAssertTrue(formSource.contains("HomeCustomTaskSectionStorage.pathTitles("))
    }

    func testMacTaskDetailsUseLiveSidebarLocationAndExistingRevealPath() throws {
        let taskDetailSource = try SourceInspectionSupport.readMacTaskDetailSources()
        let taskListSource = try [
            Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+TaskList.swift"),
            Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+TaskListSections.swift"),
        ].joined(separator: "\n")
        let taskListExpansionSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+TaskListExpansion.swift"
        )
        let taskListScrollSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/MacTaskSourceListScrollSupport.swift"
        )
        let sidebarSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Sidebar.swift"
        )

        XCTAssertTrue(taskDetailSource.contains("private var taskSidebarLocationButton: some View"))
        XCTAssertTrue(taskDetailSource.contains("Button(action: onLocateInSidebar)"))
        XCTAssertTrue(taskDetailSource.contains("ForEach(Array(sidebarLocation.titles.enumerated())"))
        XCTAssertTrue(
            taskDetailSource.contains(
                """
                titleSupplementaryContent: {
                                taskSidebarLocationButton
                """
            ),
            "The live sidebar location should appear directly below the task title."
        )
        XCTAssertTrue(taskListExpansionSource.contains("func macTaskSourceListSidebarLocation(_ taskID: UUID)"))
        XCTAssertTrue(
            taskListExpansionSource.contains("macTaskListPresentationCache.sidebarLocation(for: taskID)"),
            "Task Detail must read its breadcrumb from the presentation snapshot instead of rebuilding whole-history presentation inputs during a transition."
        )
        let sidebarLocationFunctionStart = try XCTUnwrap(
            taskListExpansionSource.range(of: "func macTaskSourceListSidebarLocation(_ taskID: UUID)")
        )
        let sidebarLocationFunctionEnd = try XCTUnwrap(
            taskListExpansionSource.range(
                of: "private func macTaskSourceListSidebarSectionTitle",
                range: sidebarLocationFunctionStart.upperBound..<taskListExpansionSource.endIndex
            )
        )
        let sidebarLocationFunction = taskListExpansionSource[
            sidebarLocationFunctionStart.lowerBound..<sidebarLocationFunctionEnd.lowerBound
        ]
        XCTAssertFalse(sidebarLocationFunction.contains("macTaskListPresentation("))
        XCTAssertFalse(sidebarLocationFunction.contains("store.routineTasks"))
        XCTAssertTrue(taskListExpansionSource.contains("location.groups.forEach(expandTaskListGroup)"))
        let taskListScrollingSource = taskListSource + taskListScrollSource
        XCTAssertEqual(
            taskListScrollingSource.components(
                separatedBy: "MacTaskSourceListScrollAnchor.group("
            ).count - 1,
            3,
            "The locate path must install anchors on parent groups and child groups before using the same anchor during staged scrolling."
        )
        XCTAssertTrue(
            taskListScrollSource.contains("MacTaskSourceListScrollPolicy.stagedScrollSteps(for: request)"),
            "A task nested in an off-screen lazy group must scroll through its section and group ancestors before targeting its row."
        )
        XCTAssertTrue(sidebarSource.contains("scrollSelectedTaskInMacSidebar()"))
        XCTAssertTrue(sidebarSource.contains("revealMacTaskSourceListTask(taskID)"))
    }

    func testMacTimelineRowsAvoidPerRowGlassAndCoalesceRefreshes() throws {
        let homeTimelineSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Timeline.swift"
        )
        let standaloneTimelineSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Timeline/TimelineView.swift"
        )
        let refreshSource = try Self.sourceFile(
            "SharedCore/Screens/Home/HomeTCAView+Refresh.swift"
        )

        XCTAssertTrue(homeTimelineSource.contains(".routinaScrollingRoundedFill("))
        XCTAssertTrue(homeTimelineSource.contains(".routinaScrollingPillFill("))
        XCTAssertFalse(
            homeTimelineSource.contains(
                ".routinaGlassCard(cornerRadius: 8, tint: .secondary, tintOpacity: 0.06)"
            )
        )
        XCTAssertTrue(standaloneTimelineSource.contains(".routinaScrollingRoundedFill("))
        XCTAssertTrue(standaloneTimelineSource.contains(".routinaScrollingPillFill("))
        XCTAssertTrue(
            refreshSource.contains(
                "minimumDelayMilliseconds: routineUpdateCoalescingDelayMilliseconds"
            ),
            "Persistence notifications must be coalesced before they can start a full Home reload near a scroll gesture."
        )
    }

    func testMacHomeDefersWholeHistoryMaintenanceOffTheMainActor() throws {
        let featureSource = try [
            Self.sourceFile("RoutinaMacApp/Features/Home/HomeFeature.swift"),
            Self.sourceFile("RoutinaMacApp/Features/Home/HomeFeature+Coordinators.swift"),
        ].joined(separator: "\n")
        let refreshSource = try Self.sourceFile("SharedCore/Screens/Home/HomeTCAView+Refresh.swift")
        let querySource = try Self.sourceFile("SharedCore/Features/Home/HomeFeatureTaskLoadQuery.swift")
        let persistenceSource = try Self.sourceFile("SharedCore/Persistence/PersistenceController.swift")

        XCTAssertTrue(
            featureSource.contains("loadTasksEffect(),"),
            "The first visible Home snapshot must not run whole-history repair on the UI executor."
        )
        XCTAssertFalse(featureSource.contains("loadTasksEffect(performingMaintenance: !state.hasLoadedTaskSnapshot)"))
        XCTAssertTrue(
            featureSource.contains("func loadTasksEffect(performingMaintenance: Bool = false)"),
            "Ordinary Home refreshes and post-mutation reloads should skip whole-history maintenance."
        )
        XCTAssertTrue(refreshSource.contains("guard !store.hasLoadedTaskSnapshot else { return }"))
        XCTAssertTrue(querySource.contains("if performingMaintenance {"))
        XCTAssertTrue(querySource.contains("RoutineLogHistory.backfillMissingLastDoneLogs"))
        XCTAssertTrue(persistenceSource.contains("Task.detached(priority: .utility)"))
        XCTAssertTrue(persistenceSource.contains("@ModelActor\nprivate actor RoutinaStartupDataMaintenanceWorker"))
    }

    func testMacStatsDoesNotReloadItsWholeSnapshotOnEveryAppearance() throws {
        let source = try Self.sourceFile("RoutinaMacApp/Features/App/AppFeature.swift")

        XCTAssertTrue(source.contains("var hasLoadedDataSnapshot = false"))
        XCTAssertTrue(source.contains("state.hasLoadedDataSnapshot = true"))
        XCTAssertTrue(source.contains("guard !state.hasLoadedDataSnapshot else"))
        XCTAssertTrue(source.contains(".cancellable(id: CancelID.dataRefreshDebounce, cancelInFlight: true)"))
    }

    func testMacStatsViewDoesNotBindSwiftDataQueriesIntoRenderPath() throws {
        let source = try Self.sourceFile("RoutinaMacApp/Screens/StatsView.swift")
        let appFeatureSource = try Self.sourceFile("RoutinaMacApp/Features/App/AppFeature.swift")

        XCTAssertFalse(
            source.contains("@Query"),
            "Mac Stats scrolling should not bind SwiftData @Query arrays into the visible render path. Fetch on data-change notifications instead."
        )
        XCTAssertTrue(
            appFeatureSource.contains("FetchDescriptor<RoutineTask>()"),
            "Stats data should still be refreshed explicitly from SwiftData when the underlying data changes."
        )
        XCTAssertFalse(
            source.contains("publisher(for: ModelContext.didSave)"),
            "Stats must use Routina's semantic update notification so unrelated context saves cannot rebuild the whole dashboard."
        )
        XCTAssertTrue(source.contains("publisher(for: .routineDidUpdate)"))
        XCTAssertTrue(source.contains("store.send(.dataRefreshRequested)"))
        XCTAssertTrue(appFeatureSource.contains("let hasActiveUnpausedFocus"))
        XCTAssertTrue(appFeatureSource.contains("continuousClock.sleep(for: .seconds(30))"))
        XCTAssertTrue(appFeatureSource.contains(".cancellable(id: CancelID.activeFocusRefreshTimer, cancelInFlight: true)"))
        XCTAssertTrue(appFeatureSource.contains("var isMacStatsSurfaceActive = false"))
        XCTAssertTrue(appFeatureSource.contains("let isEnteringStats = mode == .stats && !state.isMacStatsSurfaceActive"))
        XCTAssertTrue(appFeatureSource.contains("return isEnteringStats ? .send(.stats(.dataRefreshRequested)) : .none"))
    }

    func testMacStatsDashboardToolbarControlsAreBetaGated() throws {
        let statsSource = try Self.sourceFile("RoutinaMacApp/Screens/StatsView.swift")
        let settingsSource = try Self.sourceFile("RoutinaMacApp/Screens/Settings/SettingsMacDataSupportDetailViews.swift")

        XCTAssertTrue(statsSource.contains("appSettingMacStatsDashboardControlsEnabled"))
        XCTAssertTrue(
            statsSource.contains(
                "if areMacStatsDashboardControlsEnabled {\n                    ToolbarItemGroup(placement: .primaryAction)"))
        XCTAssertTrue(statsSource.contains("summaryDisplayModeMenu\n                        dashboardEditButton"))
        XCTAssertTrue(settingsSource.contains("Toggle(\"Show Stats dashboard controls\""))
    }

    func testMacHomeToolbarDoesNotScanRoutineTaskModelsForStatsModeBadges() throws {
        let source = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView.swift")
        let platformSource = try SourceInspectionSupport.readMacHomePlatformSources()
        let featureSource = try Self.sourceFile("RoutinaMacApp/Features/Home/HomeFeature+Display.swift")

        XCTAssertFalse(
            (source + platformSource).contains("store.routineTasks.filter"),
            "The mac toolbar is rebuilt while Stats scrolls; it should use display snapshots instead of scanning SwiftData-backed RoutineTask models."
        )
        XCTAssertTrue(source.contains("store.homeToolbarRoutineCount"))
        XCTAssertTrue(source.contains("store.homeToolbarTodoCount"))
        XCTAssertTrue(featureSource.contains("state.homeToolbarRoutineCount"))
        XCTAssertTrue(featureSource.contains("state.homeToolbarTodoCount"))
    }

    func testMacFutureSectionContextMenuBulkTogglesInnerGroups() throws {
        let taskListSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+TaskListMenus.swift"
        )
        let taskListExpansionSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+TaskListExpansion.swift"
        )

        XCTAssertTrue(taskListSource.contains("menu.addActionItem(title: \"Expand All\""))
        XCTAssertTrue(taskListSource.contains("menu.addActionItem(title: \"Collapse All Subsections\""))
        XCTAssertTrue(taskListSource.contains("section.kind == .future && section.taskGroups.contains { $0.isCollapsible }"))
        XCTAssertTrue(taskListExpansionSource.contains("isMacFutureTasksSectionCollapsed = false"))
        XCTAssertTrue(taskListExpansionSource.contains("ids.insert(id)"))
        XCTAssertTrue(taskListExpansionSource.contains("ids.remove(id)"))
    }

    func testMacTaskSectionHeadersDoNotInstallEmptyContextMenus() throws {
        let source = try [
            Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+TaskList.swift"),
            Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+TaskListHeaders.swift"),
            Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+TaskListMenus.swift"),
            Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+TaskListSections.swift"),
        ].joined(separator: "\n")

        XCTAssertTrue(source.contains("if taskListSectionHasContextMenu(section) {"))
        XCTAssertTrue(source.contains("if taskListGroupHasContextMenu(group) {"))
        XCTAssertTrue(source.contains(".routinaMacContextMenu {"))
        XCTAssertTrue(source.contains("taskListSectionNativeContextMenu(for: section, in: presentation)"))
        XCTAssertTrue(source.contains("taskListGroupNativeContextMenu(for: group)"))
        XCTAssertFalse(
            source.contains("taskListSectionContextMenu(for: section)"),
            "Section menus must use the AppKit bridge so menu tracking cannot repeatedly update the entire SwiftUI sidebar."
        )
        XCTAssertTrue(
            source.contains(
                "|| hasFutureSubsectionActions\n            || hasCustomSectionActions\n            || hasFocusActions"
            )
        )
        XCTAssertTrue(
            source.contains(
                "areMacHomeSectionFocusTimersEnabled && group.canStartFocusTimer"
            )
        )
    }

    func testMacToolbarSearchTemporarilyRevealsSidebarAndRestoresCollapseState() throws {
        let homeSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView.swift")
        let platformSource = try SourceInspectionSupport.readMacHomePlatformSources()
        let taskListSource = try [
            Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+TaskList.swift"),
            Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+TaskListSections.swift"),
        ].joined(separator: "\n")
        let taskListExpansionSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+TaskListExpansion.swift"
        )
        let taskListScrollSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/MacTaskSourceListScrollSupport.swift"
        )
        let decisionSource = try Self.sourceFile("docs/decisions/0404-temporarily-expand-mac-sidebar-during-search.md")

        XCTAssertTrue(homeSource.contains("struct HomeMacSearchSidebarRevealSnapshot"))
        XCTAssertTrue(homeSource.contains("let sidebarColumnVisibility: NavigationSplitViewVisibility"))
        XCTAssertTrue(homeSource.contains("let isDailyRoutinesSectionCollapsed: Bool"))
        XCTAssertTrue(homeSource.contains("let isMacPlanTodayDailyRoutinesGroupCollapsed: Bool"))
        XCTAssertTrue(homeSource.contains("let isMacFutureTasksSectionCollapsed: Bool"))
        XCTAssertTrue(homeSource.contains("let isArchivedSectionCollapsed: Bool"))
        XCTAssertTrue(homeSource.contains("let collapsedTagTaskListSectionIDsStorage: String"))
        XCTAssertTrue(homeSource.contains("@State var macSearchSidebarRevealSnapshot: HomeMacSearchSidebarRevealSnapshot?"))
        XCTAssertTrue(homeSource.contains("@State var macSearchSidebarRestoreScrollRequestID = 0"))
        XCTAssertTrue(homeSource.contains("@State var isMacSearchSidebarRestoreInProgress = false"))
        XCTAssertTrue(homeSource.contains("var isMacSearchSidebarRevealActive: Bool"))

        XCTAssertTrue(platformSource.contains("updateMacSearchSidebarReveal(for: searchText.wrappedValue)"))
        XCTAssertTrue(platformSource.contains(".onChange(of: searchText.wrappedValue)"))
        XCTAssertTrue(platformSource.contains("let isSearching = !rawSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty"))
        XCTAssertTrue(platformSource.contains("beginMacSearchSidebarRevealIfNeeded()"))
        XCTAssertTrue(platformSource.contains("restoreMacSearchSidebarRevealIfNeeded()"))
        XCTAssertTrue(platformSource.contains("isMacSearchSidebarRestoreInProgress = false"))
        XCTAssertTrue(platformSource.contains("sidebarColumnVisibility: macHomeSidebarColumnVisibility"))
        XCTAssertTrue(platformSource.contains("collapsedTagTaskListSectionIDsStorage: collapsedTagTaskListSectionIDsStorage"))
        XCTAssertTrue(platformSource.contains("macHomeSidebarColumnVisibility = .all"))
        XCTAssertTrue(platformSource.contains("withTransaction(Transaction(animation: nil))"))
        XCTAssertTrue(platformSource.contains("isMacSearchSidebarRestoreInProgress = true"))
        XCTAssertTrue(platformSource.contains("isMacFutureTasksSectionCollapsed = snapshot.isMacFutureTasksSectionCollapsed"))
        XCTAssertTrue(platformSource.contains("collapsedTagTaskListSectionIDsStorage = snapshot.collapsedTagTaskListSectionIDsStorage"))
        XCTAssertTrue(platformSource.contains("macHomeSidebarColumnVisibility = snapshot.sidebarColumnVisibility"))
        XCTAssertTrue(platformSource.contains("macSearchSidebarRevealSnapshot = nil"))
        XCTAssertTrue(platformSource.contains("macSearchSidebarRestoreScrollRequestID += 1"))
        XCTAssertTrue(platformSource.contains("DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)"))

        XCTAssertTrue(taskListScrollSource.contains("enum MacTaskSourceListScrollAnchor: Hashable"))
        XCTAssertTrue(taskListScrollSource.contains("enum MacTaskSourceListScrollContainerIdentity: Hashable"))
        XCTAssertTrue(taskListScrollSource.contains("struct MacTaskSourceListScrollResetView: NSViewRepresentable"))
        XCTAssertTrue(taskListSource.contains(".id(MacTaskSourceListScrollAnchor.top)"))
        XCTAssertTrue(taskListSource.contains(".id(macTaskSourceListScrollContainerIdentity)"))
        XCTAssertTrue(taskListSource.contains(".onChange(of: macSearchSidebarRestoreScrollRequestID)"))
        XCTAssertTrue(taskListSource.contains("restoreMacTaskSourceListTopPosition(with: scrollProxy)"))
        XCTAssertTrue(taskListScrollSource.contains("proxy.scrollTo(MacTaskSourceListScrollAnchor.top, anchor: .top)"))
        XCTAssertTrue(taskListScrollSource.contains("scrollView.documentView?.layoutSubtreeIfNeeded()"))
        XCTAssertTrue(taskListScrollSource.contains("scrollView.reflectScrolledClipView(clipView)"))
        XCTAssertTrue(taskListSource.contains("private var taskListSearchRestoreTransition: AnyTransition"))
        XCTAssertTrue(taskListSource.contains("? .identity"))
        XCTAssertTrue(taskListSource.contains(": .opacity.combined(with: .move(edge: .top))"))
        XCTAssertTrue(taskListSource.contains(".transition(taskListSearchRestoreTransition)"))
        XCTAssertTrue(
            taskListExpansionSource.contains(
                "if isMacSearchSidebarRevealActive {\n            return true\n        }\n\n        switch section.kind"))
        XCTAssertTrue(
            taskListExpansionSource.contains("guard group.isCollapsible else { return true }\n        if isMacSearchSidebarRevealActive"))
        XCTAssertTrue(decisionSource.contains("temporarily reveals the left sidebar column"))
        XCTAssertTrue(decisionSource.contains("Clearing the search query restores the captured sidebar column visibility"))
        XCTAssertTrue(decisionSource.contains("rebuilds and resets the task-list scroll container to the top of the restored outline"))
        XCTAssertTrue(decisionSource.contains("suppresses collapse transitions during that restore"))
    }

    func testHomeRefreshUsesCentralCloudSyncFanIn() throws {
        let source = try Self.sourceFile("SharedCore/Screens/Home/HomeTCAView+Refresh.swift")

        XCTAssertTrue(
            source.contains("publisher(for: .routineDidUpdate)"),
            "Home should still refresh through the app-owned update notification."
        )
        XCTAssertFalse(
            source.contains("NSPersistentStoreRemoteChange"),
            "Home should not subscribe directly to Core Data remote-change notifications; CloudSyncedSurfaceRefreshCoordinator coalesces them first."
        )
        XCTAssertFalse(
            source.contains("NSPersistentCloudKitContainer.eventChangedNotification"),
            "Home should not subscribe directly to CloudKit event notifications; direct subscriptions duplicate refresh/fetch work during sync."
        )
    }

    func testBacklogUsesCoalescedSemanticRefreshes() throws {
        let viewSource = try Self.sourceFile("RoutinaMacApp/Screens/Backlog/BacklogMacView.swift")
        let featureSource = try Self.sourceFile("SharedCore/Features/Home/BacklogFeature.swift")

        XCTAssertFalse(
            viewSource.contains("ModelContext.didSave"),
            "Backlog must not reload its complete presentation for every raw SwiftData save."
        )
        XCTAssertTrue(
            viewSource.contains("publisher(for: .routineDidUpdate)"),
            "Backlog should refresh through Routina's semantic update notification."
        )
        XCTAssertTrue(viewSource.contains("store.send(.routineDataChanged)"))
        XCTAssertTrue(featureSource.contains("@Dependency(\\.continuousClock) private var continuousClock"))
        XCTAssertTrue(featureSource.contains("try await continuousClock.sleep(for: .milliseconds(450))"))
        XCTAssertTrue(featureSource.contains("await send(.automaticRefresh)"))
        XCTAssertTrue(
            featureSource.contains(
                "case .automaticRefresh:\n"
                    + "                guard !state.isLoading else { return .none }\n"
                    + "                return loadTasks()"
            ),
            "Automatic Backlog refreshes must update silently without entering the user-visible loading state."
        )
        XCTAssertTrue(
            featureSource.contains(".cancellable(id: CancelID.automaticRefresh, cancelInFlight: true)"),
            "A burst of semantic updates must keep one pending Backlog refresh."
        )
        XCTAssertTrue(featureSource.contains(".cancel(id: CancelID.automaticRefresh)"))
        XCTAssertFalse(
            viewSource.contains("newSectionControl"),
            "Backlog should not reserve a permanent section composer above its task list."
        )
        XCTAssertTrue(viewSource.contains("New Backlog Super Section…"))
        XCTAssertTrue(viewSource.contains("Move a task here from the main task list"))
        XCTAssertTrue(viewSource.contains("backlogMoveMenuItems(for:"))
    }

    func testCloudSyncFanInThrottlesSurfaceRefreshes() throws {
        let source = try Self.sourceFile("SharedCore/Sync/CloudSyncedSurfaceRefreshCoordinator.swift")

        XCTAssertTrue(source.contains("surfaceRefreshQuietWindowMilliseconds: Int64 = 1_500"))
        XCTAssertTrue(source.contains("widgetRefreshQuietWindowMilliseconds: Int64 = 30_000"))
        XCTAssertTrue(source.contains("minimumSurfaceRefreshSpacing: TimeInterval = 2.0"))
        XCTAssertTrue(source.contains("maximumSurfaceRefreshDeferral: TimeInterval = 5.0"))
        XCTAssertTrue(source.contains("firstPendingSurfaceRefreshAt"))
        XCTAssertTrue(source.contains("lastSurfaceRefreshAt"))
        XCTAssertTrue(
            source.contains("pendingRefreshTask?.cancel()"),
            "Cloud sync notification bursts should keep one pending surface refresh instead of posting repeated planner invalidations."
        )
        XCTAssertTrue(
            source.contains(
                "postRoutineDidUpdate(\n            widgetRefreshDelayMilliseconds: widgetRefreshQuietWindowMilliseconds\n        )"),
            "Cloud sync should update app surfaces promptly while deferring nonessential widget refresh work out of active scroll windows."
        )
    }

    func testRoutineUpdateCoalescesWidgetRefreshWork() throws {
        let source = try Self.sourceFile("SharedCore/Services/NotificationCoordinator.swift")
        guard
            let methodStart = source.range(of: "func postRoutineDidUpdate(widgetRefreshDelayMilliseconds: Int64? = nil)"),
            let tagRenameStart = source.range(of: "func postRoutineTagDidRename")
        else {
            XCTFail("Expected routine update notification helpers to exist")
            return
        }
        let methodSource = String(source[methodStart.lowerBound..<tagRenameStart.lowerBound])

        XCTAssertTrue(methodSource.contains("RoutineWidgetRefreshScheduler.schedule(delayMilliseconds: widgetRefreshDelayMilliseconds)"))
        XCTAssertFalse(
            methodSource.contains("WidgetStatsService.refresh(using:"),
            "Routine updates should coalesce widget stats refreshes instead of fetching widget data on every posted app update."
        )
        XCTAssertTrue(source.contains("private enum RoutineWidgetRefreshScheduler"))
        XCTAssertTrue(source.contains("pendingTask?.cancel()"))
        XCTAssertTrue(source.contains("defaultWidgetRefreshQuietWindowMilliseconds: Int64 = 1_500"))
    }

    func testPlannerCachesProtectedSessionBlocksDuringScroll() throws {
        let source =
            try Self.sourceFile("SharedCore/Views/DayPlanView.swift")
            + "\n"
            + (try Self.sourceFile("SharedCore/Views/DayPlan/DayPlanTimelinePanelView.swift"))
            + "\n"
            + (try Self.sourceFile("SharedCore/Views/DayPlan/DayPlanTimelineRenderSnapshotCache.swift"))
            + "\n"
            + (try Self.sourceFile("SharedCore/Views/DayPlan/DayPlanProtectedSessionBlocksCache.swift"))

        XCTAssertTrue(source.contains("@StateObject private var sleepBlocksCache = DayPlanSleepBlocksCache()"))
        XCTAssertTrue(source.contains("@StateObject private var awayBlocksCache = DayPlanAwayBlocksCache()"))
        XCTAssertTrue(source.contains("let sleepBlocksByDayKey = sleepBlocksCache.blocksByDayKey("))
        XCTAssertTrue(source.contains("let awayBlocksByDayKey = awayBlocksCache.blocksByDayKey("))
        XCTAssertTrue(source.contains("relevantSessions.contains { $0.endedAt == nil }"))
        XCTAssertTrue(source.contains("relevantSessions.contains { $0.isActive && $0.plannedEndAt == nil }"))
    }

    func testPlannerTimelinePanelDoesNotBindSwiftDataQueriesIntoScrollRenderPath() throws {
        let panelSource = try Self.sourceFile(
            "SharedCore/Views/DayPlan/DayPlanTimelinePanelView.swift"
        )
        let dataSource = try Self.sourceFile(
            "SharedCore/Views/DayPlan/DayPlanTimelineDataSnapshot.swift"
        )

        XCTAssertFalse(
            panelSource.contains("@Query"),
            "Planner timeline scrolling should read an explicit snapshot, not SwiftData @Query arrays that refetch during body updates."
        )
        XCTAssertTrue(panelSource.contains("@State private var dataSnapshot = DayPlanTimelineDataSnapshot()"))
        XCTAssertTrue(panelSource.contains("refreshTimelineDataSnapshot()"))
        XCTAssertFalse(
            panelSource.contains("ModelContext.didSave"),
            "Planner timeline data refreshes should stay behind the app-owned update fan-in instead of every raw SwiftData save."
        )
        XCTAssertTrue(dataSource.contains("struct DayPlanTimelineDataSnapshot"))
        XCTAssertTrue(dataSource.contains("FetchDescriptor<RoutineTask>()"))
    }

    func testPlannerTimelineCachesRenderSnapshotDuringScroll() throws {
        let source =
            try Self.sourceFile("SharedCore/Views/DayPlanView.swift")
            + "\n"
            + (try Self.sourceFile("SharedCore/Views/DayPlan/DayPlanTimelinePanelView.swift"))
            + "\n"
            + (try Self.sourceFile("SharedCore/Views/DayPlan/DayPlanTimelineRenderSnapshotCache.swift"))

        XCTAssertTrue(source.contains("@StateObject private var renderSnapshotCache = DayPlanTimelineRenderSnapshotCache()"))
        XCTAssertTrue(source.contains("let renderSnapshot = renderSnapshotCache.snapshot("))
        XCTAssertTrue(source.contains("final class DayPlanTimelineRenderSnapshotCache"))
        XCTAssertTrue(source.contains("var dataSnapshotID: UUID"))
        XCTAssertTrue(source.contains("Self.hasVisibleOpenEndedTimelineBlock("))
        XCTAssertTrue(source.contains("var referenceMinute: ReferenceMinute?"))
        XCTAssertTrue(source.contains("refreshesEveryMinute\n            ? ReferenceMinute"))
        XCTAssertTrue(
            source.contains("if cachedKey == key, let cachedSnapshot"),
            "Planner scroll/layout passes should reuse the current render snapshot instead of rebuilding timeline dictionaries and SwiftData-derived task state."
        )
    }

    func testPlannerTimelineDataSnapshotDoesNotInvalidateForEquivalentRefreshes() throws {
        let source =
            try Self.sourceFile(
                "SharedCore/Views/DayPlan/DayPlanTimelinePanelView.swift"
            )
            + "\n"
            + (try Self.sourceFile("SharedCore/Views/DayPlan/DayPlanTimelineDataSnapshot.swift"))

        XCTAssertTrue(source.contains("struct DayPlanTimelineDataSnapshotSignature: Equatable"))
        XCTAssertTrue(source.contains("var signature = DayPlanTimelineDataSnapshotSignature()"))
        XCTAssertTrue(source.contains("if refreshedSnapshot.signature != dataSnapshot.signature"))
        XCTAssertTrue(source.contains("@State private var hasDeferredTimelineDataSnapshotRefresh = false"))
        XCTAssertTrue(source.contains("requestTimelineDataSnapshotRefresh()"))
        XCTAssertTrue(source.contains("guard !isExternalInspectorPresented else"))
        XCTAssertTrue(source.contains("RoutinaMacScrollInteractionGate.isScrollActive"))
        XCTAssertTrue(source.contains("scheduleDeferredTimelineDataSnapshotRefreshRetry()"))
        XCTAssertTrue(
            source.contains("colorRawValue = task.colorRawValue"),
            "The planner snapshot signature should include fields that change visible block presentation, not just task IDs."
        )
        XCTAssertTrue(
            source.contains("accumulatedPausedSeconds = session.accumulatedPausedSeconds"),
            "Focus session timing changes should still invalidate the planner snapshot when they affect active focus blocks."
        )
    }

    func testPlannerDayTaskResolutionUsesLightweightPresentationOverlay() throws {
        let viewSource = try Self.sourceFile("SharedCore/Views/DayPlanView.swift")
        let supportSource = try [
            Self.sourceFile("SharedCore/Views/DayPlan/DayPlanDayTaskListModels.swift"),
            Self.sourceFile("SharedCore/Views/DayPlan/DayPlanDayTaskListPresentation.swift"),
        ].joined(separator: "\n")
        guard
            let overlayStart = supportSource.range(of: "struct DayPlanDayTaskResolutionOverlay"),
            let presentationStart = supportSource.range(
                of: "enum DayPlanDayTaskListPresentation",
                range: overlayStart.upperBound..<supportSource.endIndex
            )
        else {
            XCTFail("Expected the Planner day-task resolution overlay")
            return
        }
        let overlaySource = String(
            supportSource[overlayStart.lowerBound..<presentationStart.lowerBound]
        )

        XCTAssertTrue(viewSource.contains("@State private var dayTaskResolutionOverlay"))
        XCTAssertTrue(viewSource.contains("dayTaskResolutionOverlay.applying("))
        XCTAssertFalse(
            overlaySource.contains("FetchDescriptor"),
            "Immediate row resolution must not fetch task history."
        )
        XCTAssertFalse(
            overlaySource.contains("ModelContext"),
            "Immediate row resolution must remain a presentation-only O(visible rows) update."
        )
    }

    func testMacPlannerCompanionLayoutKeepsHeaderInsidePlannerColumn() throws {
        XCTAssertEqual(
            MacDetailContainerSizing.plannerInspectorContentMinWidth,
            DayPlanWeekCalendarSizing.minimumDetailWidth(isExternalInspectorPresented: true)
        )
        XCTAssertEqual(
            MacDetailContainerSizing.plannerTaskDetailMinWidth,
            MacDetailContainerSizing.plannerInspectorContentMinWidth + MacDetailContainerSizing.taskDetailPaneWidth
        )
        XCTAssertEqual(RoutinaMacWindowSizing.minWidth, 1440)
        XCTAssertGreaterThanOrEqual(RoutinaMacWindowSizing.defaultWidth, RoutinaMacWindowSizing.minWidth)
        XCTAssertGreaterThanOrEqual(
            RoutinaMacWindowSizing.minWidth,
            MacDetailContainerSizing.plannerTaskDetailMinWidth + 360 + 80,
            "Mac Home should not resize below the expanded-sidebar plus Planner companion layout, with transition breathing room."
        )

        let detailSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/MacDetailContainerView.swift")
        let dayPlanSource =
            try Self.sourceFile("SharedCore/Views/DayPlanView.swift")
            + "\n"
            + (try Self.sourceFile("SharedCore/Views/DayPlan/DayPlanDetailView.swift"))
            + "\n"
            + (try Self.sourceFile("SharedCore/Views/DayPlan/DayPlanHeaderView.swift"))
            + "\n"
            + (try Self.sourceFile("SharedCore/Views/DayPlan/DayPlanHeaderUtilityControls.swift"))
        let dayPlanSupportSource = try Self.sourceFile("SharedCore/Views/DayPlan/DayPlanViewSupportTypes.swift")

        XCTAssertTrue(
            detailSource.contains("detailContent\n            .clipped()"),
            "Mac detail content should clip oversized child surfaces at the NavigationSplitView detail boundary."
        )
        XCTAssertTrue(detailSource.contains("let contentWidth = max(proxy.size.width - filterPaneWidth, 0)"))
        XCTAssertTrue(detailSource.contains(".frame(width: contentWidth)"))
        XCTAssertTrue(detailSource.contains("let plannerContentWidth = plannerContentWidth("))
        XCTAssertTrue(detailSource.contains(".frame(width: plannerContentWidth)"))
        XCTAssertTrue(detailSource.contains("availableWidth - MacDetailContainerSizing.taskDetailPaneWidth"))
        XCTAssertTrue(
            dayPlanSource.contains("isExternalInspectorPresented: isExternalInspectorPresented"),
            "Planner adaptive range should know when a companion pane is consuming horizontal space."
        )
        XCTAssertTrue(
            detailSource.contains("macHeaderAvailableWidth: max(")
                && detailSource.contains("plannerContentWidth - DayPlanWeekCalendarSizing.detailHorizontalPadding"),
            "Mac Planner should pass its bounded column width to the header so tight inspector density is deterministic."
        )
        XCTAssertTrue(dayPlanSource.contains("parentAvailableWidth: macHeaderAvailableWidth"))
        XCTAssertTrue(dayPlanSource.contains("private var effectiveMacHeaderAvailableWidth: CGFloat"))
        XCTAssertTrue(
            detailSource.contains(".clipped()\n\n                if canShowTaskDetailPane"),
            "Planner content should clip at its own column boundary instead of drawing underneath a right companion pane."
        )
        XCTAssertTrue(dayPlanSource.contains(".background(macHeaderAvailableWidthReader)"))
        XCTAssertTrue(
            dayPlanSource.contains("DayPlanTimelinePanelView(\n                    planner: planner")
                && dayPlanSource.contains(".frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)"),
            "The bounded Planner column width should be forwarded through the detail and timeline panel stack."
        )
        XCTAssertTrue(
            dayPlanSource.contains("DayPlanWeekCalendarView(\n                dates: visibleDates")
                && dayPlanSource.contains(".dayPlanLifecycle("),
            "The calendar should remain in the filling Planner content stack so width proposals reach the grid."
        )
        XCTAssertFalse(
            dayPlanSource.contains(
                "macHeaderRow(showsRangePicker: shouldShowMacHeaderRangePicker)\n            .background(macHeaderAvailableWidthReader)"),
            "Header available width should be measured from the bounded container, not the potentially overflowing controls row."
        )
        XCTAssertTrue(dayPlanSource.contains("@State private var expandedMacHeaderControl: DayPlanExpandedHeaderControl?"))
        XCTAssertTrue(dayPlanSource.contains("usesIconOnlyMacDatePickerButton"))
        XCTAssertTrue(dayPlanSource.contains("macHeaderExpandedControlsWidthProbe"))
        XCTAssertTrue(dayPlanSource.contains("plannerDisplayModeControl(isExpanded:"))
        XCTAssertTrue(dayPlanSource.contains("calendarTaskViewModeControl(isExpanded:"))
        XCTAssertTrue(dayPlanSource.contains("visibleRangeModeControl(isExpanded:"))
        XCTAssertTrue(dayPlanSource.contains("private struct DayPlanExpandableHeaderSegmentedControl"))
        XCTAssertTrue(dayPlanSource.contains("expandedMacHeaderControl == control ? nil : control"))
        XCTAssertTrue(dayPlanSource.contains("expandedMacHeaderControl = nil"))
        XCTAssertTrue(dayPlanSource.contains("if accessibilityReduceMotion"))
        XCTAssertTrue(dayPlanSource.contains("withAnimation(.easeInOut(duration: 0.18), changes)"))
        XCTAssertTrue(dayPlanSource.contains("options: planner.availableVisibleRangeModes"))
        XCTAssertTrue(dayPlanSource.contains("plannerDatePickerButtonMinimumWidth"))
        XCTAssertTrue(dayPlanSource.contains("plannerDatePickerButtonMaximumWidth"))
        XCTAssertTrue(
            dayPlanSource.contains(
                "if displayMode.wrappedValue == .list, let listContent {\n                plannerListContent(listContent)"))
        XCTAssertTrue(dayPlanSource.contains("private var showsPlannerDatePickerButton: Bool"))
        XCTAssertTrue(dayPlanSource.contains("effectiveDisplayMode == .calendar || effectiveDisplayMode == .list"))
        XCTAssertTrue(
            dayPlanSource.contains("DayPlanDatePickerSidebar(\n                        selectedDate: selectedDateBinding"),
            "Planner Timeline should render the same Go to date sidebar as Calendar when the date button is pressed."
        )
        XCTAssertTrue(
            dayPlanSource.contains("usesCompactWidth ? 34 : nil"),
            "The date/range button should switch to a compact icon-only hit target before its label truncates."
        )
        XCTAssertTrue(
            dayPlanSource.contains("plannerUtilityCluster(forceIconOnlyDatePickerButton: usesIconOnlyMacDatePickerButton)"),
            "The header should apply the independent Go to date presentation decision."
        )
        XCTAssertTrue(dayPlanSource.contains("shouldUseIconOnlyDatePickerButton("))
        XCTAssertFalse(dayPlanSource.contains("showsExtraUtilityControl"))
        XCTAssertFalse(
            dayPlanSource.contains("usesIconOnlyMacDatePickerButton ? nil : 210"),
            "The regular date/range button should not reserve blank horizontal space beyond its content."
        )
        XCTAssertFalse(
            dayPlanSource.contains(".truncationMode(.middle)"),
            "Go to date should switch to its icon before the regular label is ellipsized."
        )
        XCTAssertTrue(dayPlanSource.contains(".layoutPriority(3)"))
        XCTAssertTrue(dayPlanSource.contains("shouldUseCompactDateButtonForFit"))
        XCTAssertTrue(dayPlanSupportSource.contains("static let dateButtonTransitionReserveWidth: Double = 120"))
        XCTAssertTrue(dayPlanSupportSource.contains("static let minimumRegularCalendarHeaderAvailableWidth: Double = 1520"))
        XCTAssertFalse(dayPlanSource.contains("minimumRegularCalendarHeaderWithExtraUtilityAvailableWidth"))
        XCTAssertTrue(dayPlanSource.contains("effectiveAvailableWidth("))
        XCTAssertTrue(dayPlanSupportSource.contains("return min(parentWidth, measuredWidth)"))
        XCTAssertFalse(dayPlanSource.contains("macFocusControl"))
        XCTAssertFalse(detailSource.contains("plannerHeaderFocusControl"))
        XCTAssertTrue(dayPlanSource.contains("showsCalendarControlSet: effectiveDisplayMode == .calendar"))
        XCTAssertTrue(dayPlanSource.contains("parentAvailableWidth: macHeaderAvailableWidth"))
        XCTAssertTrue(dayPlanSource.contains(".onChange(of: parentAvailableWidth)"))
        XCTAssertTrue(
            dayPlanSource.contains("updateAdaptiveVisibleRangeModeFromParentWidthIfAvailable()"),
            "External Planner panes should recompute the adaptive range from the bounded parent width instead of waiting for child geometry."
        )
        XCTAssertFalse(dayPlanSource.contains("shouldShowMacHeaderRangePicker"))
    }

    func testHomeDoneStatsDoesNotRewalkLogsForEachOutcome() throws {
        let source = try Self.sourceFile("SharedCore/Features/Home/HomeTaskSupport.swift")

        XCTAssertFalse(
            source.contains("logs.reduce"),
            "Home refresh should scan logs once when building done stats; repeated reductions are noticeable with large Home histories."
        )
        XCTAssertTrue(source.contains("for log in logs"))
    }

    func testMacTaskDetailDefersRoutineUpdateRefreshWhileInspectorIsOpen() throws {
        let refreshSource = try Self.sourceFile("SharedCore/Screens/Home/HomeTCAView+Refresh.swift")
        let macHomeSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView.swift")
        let scrollGateSource = try Self.sourceFile("SharedCore/Services/RoutinaMacScrollInteractionGate.swift")

        XCTAssertTrue(refreshSource.contains("requestRoutineUpdateRefresh()"))
        XCTAssertTrue(refreshSource.contains("shouldDeferRoutineUpdateRefresh"))
        XCTAssertTrue(refreshSource.contains("RoutinaMacScrollInteractionGate"))
        XCTAssertTrue(scrollGateSource.contains("NSEvent.addLocalMonitorForEvents(matching: .scrollWheel)"))
        XCTAssertTrue(refreshSource.contains("scheduleDeferredRoutineUpdateRefreshRetry()"))
        XCTAssertTrue(refreshSource.contains("hasDeferredRoutineUpdateRefresh = true"))
        XCTAssertTrue(refreshSource.contains("requestDeferredRoutineUpdateRefreshIfNeeded()"))
        XCTAssertTrue(
            refreshSource.contains(
                "minimumDelayMilliseconds: taskDetailTransitionQuietDelayMilliseconds"
            ),
            "Closing Task Details should let its pane transition finish before a deferred Home reload begins."
        )
        XCTAssertTrue(refreshSource.contains("private var taskDetailTransitionQuietDelayMilliseconds"))
        XCTAssertTrue(macHomeSource.contains("@State var hasDeferredRoutineUpdateRefresh = false"))
        XCTAssertTrue(macHomeSource.contains("@State var deferredRoutineUpdateRefreshTask: Task<Void, Never>?"))
        XCTAssertFalse(
            refreshSource.contains(
                "publisher(for: .routineDidUpdate)\n"
                    + "                    .receive(on: RunLoop.main)\n"
                    + "            ) { _ in\n"
                    + "                requestRefresh()"
            ),
            "Cloud routine-update pulses should not synchronously reload Home while a Mac task detail pane is being scrolled."
        )
    }

    func testPlannerAdaptiveRangeChangeDoesNotReconcileFocusHistory() throws {
        let source = try Self.sourceFile(
            "SharedCore/Views/DayPlan/DayPlanPresentationSheets.swift"
        )
        guard
            let rangeChangeStart = source.range(of: ".onChange(of: planner.visibleRangeMode)"),
            let dataChangeStart = source.range(
                of: ".onChange(of: dataRevision)",
                range: rangeChangeStart.upperBound..<source.endIndex
            )
        else {
            XCTFail("Expected Planner visible-range and data-revision lifecycle handlers")
            return
        }

        let rangeChangeSource = String(
            source[rangeChangeStart.lowerBound..<dataChangeStart.lowerBound]
        )
        XCTAssertTrue(rangeChangeSource.contains("planner.loadBlocks("))
        XCTAssertFalse(
            rangeChangeSource.contains("reconcileCountUpFocusSegments()"),
            "A width-driven Day/3 Days/Week change must not walk and persist the complete Focus history."
        )
    }

    func testTaskDetailHeaderStacksItsFullSummaryAwayFromActionCluster() throws {
        let source = try Self.sourceFile("SharedCore/Screens/TaskDetail/TaskDetailHeaderViews.swift")

        XCTAssertTrue(source.contains("private var usesStackedHeaderLayout"))
        XCTAssertTrue(source.contains("guard accessoryWidth > 0.5 else"))
        XCTAssertTrue(
            source.contains("headerContentWidth + accessoryWidth + TaskDetailHeaderSectionMetrics.titleAccessorySpacing > availableWidth"))
        XCTAssertTrue(source.contains("HStack {\n                    Spacer(minLength: 0)\n                    measuredHeaderAccessory"))
        XCTAssertTrue(source.contains("headerContentWidthProbe"))
        XCTAssertTrue(source.contains("if let statusContextMessage"))
        XCTAssertTrue(source.contains(".background(headerMetricReader(.headerContentWidth))"))
        XCTAssertTrue(source.contains(".background(headerMetricReader(.accessoryWidth))"))
        XCTAssertTrue(source.contains(".allowsHitTesting(false)"))
        XCTAssertTrue(source.contains("}\n        .frame(maxWidth: .infinity, alignment: .leading)\n        .padding(16)"))
    }

    func testMacHomeBoardReusesColumnOrderedTaskIDs() throws {
        let source = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/HomeMacTodoBoardView.swift")

        XCTAssertFalse(
            source.contains("column.tasks.map(\\.id)"),
            "Board scroll and drag/drop rendering should reuse each column's ordered task IDs instead of rebuilding them for every card."
        )
        XCTAssertTrue(source.contains("let orderedTaskIDs: [UUID]"))
    }

    func testMacLaunchWidgetRefreshKeepsStatsWorkOutOfInitialScrollWindow() throws {
        let source = try Self.sourceFile("RoutinaMacApp/Screens/App/RoutinaMacRootScene.swift")

        XCTAssertTrue(
            source.contains("scheduleLaunchRefresh()"),
            "Launch should use a dedicated schedule so broad stats work does not compete with the first task-detail scroll."
        )
        XCTAssertTrue(
            source.contains("scheduleStatsRefresh(delayNanoseconds: 2_000_000_000)"),
            "Stats widget refresh is intentionally delayed on launch because it may fetch many tasks/logs."
        )
        XCTAssertFalse(
            source.contains("WidgetCenter.shared.reloadAllTimelines()"),
            "Mac launch should reload only the Routina widgets whose data changed instead of invalidating every widget timeline."
        )
    }

    func testMacSettingsUsesAStandardFullscreenWindowWithSystemCommandRouting() throws {
        let source = try Self.sourceFile("RoutinaMacApp/Screens/App/RoutinaMacRootScene.swift")
        let commands = try Self.sourceFile("RoutinaMacApp/Commands/RoutineCommands.swift")

        XCTAssertTrue(
            source.contains("Window(\"Routinam Settings\", id: RoutinaMacSceneID.settings)"),
            "Settings must use a standard Window host so AppKit permits native fullscreen."
        )
        XCTAssertTrue(source.contains(".windowResizability(.contentMinSize)"))
        XCTAssertTrue(source.contains(".defaultLaunchBehavior(.suppressed)"))
        XCTAssertFalse(
            source.contains("Settings {"),
            "SwiftUI's preference-panel Settings scene does not become fullscreen-capable by mutating its NSWindow flags."
        )
        XCTAssertFalse(source.contains("RoutinaMacSettingsWindowConfigurator"))
        XCTAssertTrue(
            commands.contains("CommandGroup(replacing: .appSettings)"),
            "Replacing the special Settings scene must preserve the system Settings menu location."
        )
        XCTAssertTrue(
            commands.contains("openWindow(id: RoutinaMacSceneID.settings)")
        )
        XCTAssertTrue(
            commands.contains(".keyboardShortcut(\",\", modifiers: .command)"),
            "The standard Command-comma Settings shortcut must survive the custom window host."
        )
    }

    func testMacAppTargetsDoNotShipWidgetExtensions() throws {
        let project = try Self.sourceFile("RoutinaMacOS.xcodeproj/project.pbxproj")
        let prodTarget = try Self.projectBlock(
            named: "RoutinaMacOSProd",
            in: project,
            endingBefore: "RoutinaMacOSDev"
        )
        let devTarget = try Self.projectBlock(
            named: "RoutinaMacOSDev",
            in: project,
            endingBefore: "RoutinaMacOSTests"
        )

        for target in [prodTarget, devTarget] {
            XCTAssertFalse(target.contains("Embed Foundation Extensions"))
            XCTAssertFalse(target.contains("Register Widget Extension"))
            XCTAssertFalse(target.contains("RoutinaWidgetExtension.appex"))
            XCTAssertFalse(target.contains("RoutinaWidgetDevExtension.appex"))
            XCTAssertFalse(target.contains("RoutinaWidgetExtension */"))
            XCTAssertFalse(target.contains("RoutinaWidgetDevExtension */"))
        }

        XCTAssertTrue(project.contains("/* RoutinaWidgetExtension */ = {"))
        XCTAssertTrue(project.contains("/* RoutinaWidgetDevExtension */ = {"))
    }

    func testMacRawSwiftDataSavesDoNotDuplicateWidgetRefreshWork() throws {
        let rootSource = try Self.sourceFile("RoutinaMacApp/Screens/App/RoutinaMacRootScene.swift")
        let statusStoreSource = try Self.sourceFile("RoutinaMacApp/Screens/App/RoutinaMacFocusTimerStatusStore.swift")
        guard
            let saveReceiveStart = rootSource.range(of: "publisher(for: ModelContext.didSave)"),
            let routineReceiveStart = rootSource.range(
                of: "publisher(for: .routineDidUpdate)",
                range: saveReceiveStart.upperBound..<rootSource.endIndex
            )
        else {
            XCTFail("Expected mac root scene save/update notification handlers")
            return
        }
        let saveReceiveSource = String(rootSource[saveReceiveStart.lowerBound..<routineReceiveStart.lowerBound])

        XCTAssertFalse(
            saveReceiveSource.contains("widgetRefreshScheduler.schedule()"),
            "Raw SwiftData save notifications are noisy during CloudKit sync and should not duplicate coalesced routine-update widget refresh work."
        )
        XCTAssertTrue(saveReceiveSource.contains("focusTimerStatusStore.scheduleRefresh()"))
        XCTAssertFalse(
            rootSource.contains("func schedule(delayNanoseconds"),
            "The mac widget scheduler should be launch-only; routine updates use the shared coalesced widget scheduler."
        )
        XCTAssertTrue(statusStoreSource.contains("private var scheduledRefreshTask"))
        XCTAssertTrue(statusStoreSource.contains("func scheduleRefresh(delayNanoseconds: UInt64 = 500_000_000)"))
        XCTAssertTrue(statusStoreSource.contains("scheduledRefreshTask?.cancel()"))
    }

    func testWidgetStatsServiceDoesNotFetchCanceledLogsForStats() throws {
        let source = try Self.sourceFile("SharedCore/Services/WidgetStatsService.swift")

        XCTAssertFalse(
            source.contains("FetchDescriptor<RoutineLog>()"),
            "Widget stats should not fetch every routine log on launch; canceled logs are irrelevant for completion stats."
        )
        XCTAssertTrue(source.contains("log.kindRawValue == completedKindRawValue"))
    }

    func testMacFocusToolbarShowsTimerWithoutResizingEverySecond() throws {
        let source = try Self.sourceFile("RoutinaMacApp/Screens/Shared/RoutinaMacFocusTimerToolbarBadge.swift")

        XCTAssertTrue(
            source.contains("RoutinaMacFocusTimerToolbarTimeText(status: status)"),
            "The active focus toolbar badge should show the live timer counter, not only a static focus label."
        )
        XCTAssertTrue(source.contains("status.menuBarTimeText(at: context.date)"))
        XCTAssertTrue(
            source.contains("Text(\"+00:00:00\")"),
            "Reserve a stable counter width so second-by-second timer updates do not resize the toolbar item."
        )
    }

    func testHomeNewMenuOwnsFocusInsteadOfThePlannerHeader() throws {
        let detailSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/MacDetailContainerView.swift")
        let dayPlanSource =
            try Self.sourceFile("SharedCore/Views/DayPlanView.swift")
            + "\n"
            + (try Self.sourceFile("SharedCore/Views/DayPlan/DayPlanHeaderView.swift"))
            + "\n"
            + (try Self.sourceFile("SharedCore/Views/DayPlan/DayPlanHeaderUtilityControls.swift"))
        let controlsSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/HomeMacSidebarModeStripView.swift")
        let platformSource = try SourceInspectionSupport.readMacHomePlatformSources()
        let statusMenuSource = try Self.sourceFile("RoutinaMacApp/Screens/App/RoutinaMacFocusTimerStatusBarController.swift")

        XCTAssertFalse(dayPlanSource.contains("macFocusControl"))
        XCTAssertFalse(detailSource.contains("plannerHeaderFocusControl"))
        XCTAssertTrue(controlsSource.contains("case .focus:\n            onFocus()"))
        XCTAssertTrue(controlsSource.contains(".disabled(shortcut == .focus && focusAvailability.isDisabled)"))
        XCTAssertTrue(controlsSource.contains("Label(\"Another timer is running\", systemImage: \"info.circle\")"))
        XCTAssertTrue(controlsSource.contains("shortcut == .focus && focusAvailability.hasActiveTimer"))
        XCTAssertFalse(controlsSource.contains("Text(\"New\")"))
        XCTAssertFalse(controlsSource.contains(".menuIndicator(.hidden)"))
        XCTAssertTrue(controlsSource.contains("ForEach(combinedMenuShortcuts)"))
        XCTAssertTrue(controlsSource.contains("MacAddMenuShortcut.combinedMenuActions(from: visibleAddMenuShortcuts)"))
        XCTAssertTrue(controlsSource.contains("ForEach(availableWorkspaceModes)"))
        XCTAssertFalse(controlsSource.contains("private var addOptionsMenu"))
        XCTAssertFalse(controlsSource.contains(".frame(width: 32, height: 32)"))
        XCTAssertTrue(
            platformSource.contains(
                "hasStartableTasks: !store.routineDisplays.isEmpty || !store.awayRoutineDisplays.isEmpty"
            )
        )
        XCTAssertFalse(platformSource.contains("homeToolbarFocusStartDisplayCount"))
        XCTAssertTrue(statusMenuSource.contains("status.isPaused ? \"Resume Timer\" : \"Pause Timer\""))
    }

    func testMacHomeFocusToolbarUsesSingleTimerSlot() throws {
        let source = try Self.homeMacToolbarSource()
        let homeSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView.swift")
        let rootSceneSource = try Self.sourceFile("RoutinaMacApp/Screens/App/RoutinaMacRootScene.swift")
        let sidebarSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Sidebar.swift")
        let platformSource = try SourceInspectionSupport.readMacHomePlatformSources()
        let appShellSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeMacAppShell.swift")
        let navigationSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeMacNavigationContent.swift")
        let detailSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/MacDetailContainerView.swift")
        let taskDetailSource = try SourceInspectionSupport.readMacTaskDetailSources()
        let taskToolbarSource = try Self.sourceFile("RoutinaMacApp/Screens/TaskDetail/TaskDetailToolbarContent.swift")
        let dayPlanSource = try Self.sourceFile("SharedCore/Views/DayPlanView.swift")
        let toolbarComponentsSource = try Self.sourceFile("RoutinaMacApp/Screens/Shared/MacToolbarComponents.swift")
        let controlsSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/HomeMacSidebarModeStripView.swift")
        let shortcutSource = try Self.sourceFile("RoutinaMacApp/Commands/MacAddMenuShortcut.swift")
        let commandSource = try Self.sourceFile("RoutinaMacApp/Commands/RoutineCommands.swift")

        XCTAssertTrue(
            source.contains("HomeMacToolbarSearchField("),
            "Home should keep the global task and timeline search field in the top search affordance for searchable surfaces."
        )
        XCTAssertTrue(source.contains("let showsSearch: Bool"))
        XCTAssertTrue(
            source.contains("struct HomeMacTopToolbarChrome: View"),
            "Home search should live in the SwiftUI top chrome so text input and animation remain in the main view hierarchy."
        )
        XCTAssertTrue(
            source.contains("RoutinaMacFocusTimerToolbarBadge(showsTitle: false)"),
            "An active timer should remain visible immediately beside the Home sidebar toggle."
        )
        XCTAssertTrue(
            platformSource.contains("var homeTopToolbarChrome: some View"),
            "The Home shell should own the Outlook-style top chrome from the same state that powers search, focus, and task creation."
        )
        XCTAssertTrue(platformSource.contains("ZStack(alignment: .top) {"))
        XCTAssertTrue(platformSource.contains(".padding(.top, HomeMacToolbarSearchLayout.topToolbarHeight)"))
        XCTAssertTrue(appShellSource.contains("ignoresSafeArea(edges: .top)"))
        XCTAssertTrue(
            navigationSource.contains(".toolbar(removing: .sidebarToggle)")
        )
        XCTAssertTrue(homeSource.contains("@State var macHomeSidebarColumnVisibility: NavigationSplitViewVisibility = .all"))
        XCTAssertTrue(platformSource.contains("sidebarColumnVisibility: $macHomeSidebarColumnVisibility"))
        XCTAssertTrue(platformSource.contains("func toggleMacHomeSidebar()"))
        XCTAssertTrue(navigationSource.contains("NavigationSplitView(columnVisibility: $sidebarColumnVisibility)"))
        XCTAssertTrue(platformSource.contains("HomeMacSidebarSplitViewConfigurator("))
        XCTAssertTrue(platformSource.contains("func routinaHomeSidebarSplitViewConstraints() -> some View"))
        XCTAssertTrue(navigationSource.contains(".routinaHomeSidebarSplitViewConstraints()"))
        XCTAssertTrue(platformSource.contains("minimumWidth: HomeSidebarSizing.minWidth"))
        XCTAssertTrue(platformSource.contains("maximumWidth: HomeSidebarSizing.maxWidth"))
        XCTAssertTrue(platformSource.contains("sidebarItem.maximumThickness = maximumWidth"))
        XCTAssertTrue(platformSource.contains("!sidebarItem.isCollapsed"))
        XCTAssertTrue(platformSource.contains("sidebarView.frame.width > 1"))
        XCTAssertTrue(platformSource.contains("context.allowsImplicitAnimation = false"))
        XCTAssertTrue(platformSource.contains("withAnimation(.easeInOut(duration: 0.22)) {\n            macHomeSidebarColumnVisibility"))
        XCTAssertFalse(platformSource.contains("transaction.disablesAnimations = true"))
        XCTAssertTrue(rootSceneSource.contains(".windowResizability(.contentMinSize)"))
        XCTAssertTrue(source.contains("HomeMacSidebarVisibilityToolbarButton("))
        XCTAssertTrue(source.contains("Collapse Sidebar"))
        XCTAssertTrue(source.contains("Expand Sidebar"))
        XCTAssertTrue(source.contains("static let sidebarToggleButtonSize: CGFloat = 28"))
        XCTAssertTrue(source.contains("width: HomeMacToolbarSearchLayout.sidebarToggleButtonSize"))
        XCTAssertTrue(source.contains("height: HomeMacToolbarSearchLayout.sidebarToggleButtonSize"))
        guard
            let sidebarToggleStart = source.range(of: "private struct HomeMacSidebarVisibilityToolbarButton: View"),
            let toolbarLayoutStart = source.range(of: "enum HomeMacToolbarSearchLayout")
        else {
            XCTFail("Expected the Mac Home sidebar toggle and toolbar layout definitions to exist.")
            return
        }
        let sidebarToggleSource = String(source[sidebarToggleStart.lowerBound..<toolbarLayoutStart.lowerBound])
        XCTAssertTrue(
            sidebarToggleSource.contains(".contentShape(Rectangle())"),
            "The sidebar visibility button should make the whole fixed toolbar target clickable."
        )
        XCTAssertTrue(toolbarComponentsSource.contains("private final class RoutinaMacToolbarIconButton: NSButton"))
        XCTAssertTrue(toolbarComponentsSource.contains("override func acceptsFirstMouse(for event: NSEvent?) -> Bool"))
        XCTAssertTrue(toolbarComponentsSource.contains("override func hitTest(_ point: NSPoint) -> NSView?"))
        XCTAssertTrue(
            toolbarComponentsSource.contains("bounds.contains(point)"),
            "AppKit-backed toolbar icons should claim their entire NSButton bounds, not just the drawn symbol."
        )
        XCTAssertFalse(source.contains("struct HomeMacTitlebarSearchInstaller"))
        XCTAssertFalse(platformSource.contains("HomeMacTitlebarSearchInstaller("))
        XCTAssertFalse(source.contains("NSTitlebarAccessoryViewController"))
        XCTAssertFalse(source.contains("HomeMacTitlebarSearchHostingView"))
        XCTAssertFalse(source.contains("window.standardWindowButton(.closeButton)"))
        XCTAssertFalse(platformSource.contains("homeTitlebarSearchInstaller"))
        XCTAssertFalse(platformSource.contains(".safeAreaInset(edge: .top, spacing: 0)"))
        XCTAssertFalse(source.contains("ToolbarItem(placement: .principal)"))
        XCTAssertFalse(source.contains("struct HomeMacExpandedToolbarSearchOverlay: View"))
        XCTAssertTrue(source.contains("static let compactWidth: CGFloat = 620"))
        XCTAssertTrue(source.contains("static let focusedWidth: CGFloat = 860"))
        XCTAssertTrue(source.contains("static let topToolbarHeight: CGFloat = 62"))
        XCTAssertTrue(source.contains("static let topToolbarHorizontalPadding: CGFloat = 18"))
        XCTAssertTrue(source.contains("static let trafficLightReservedLeadingPadding: CGFloat = 184"))
        XCTAssertTrue(
            source.contains("ZStack(alignment: .center) {"),
            "The toolbar row should center search independently of asymmetric leading and trailing controls."
        )
        XCTAssertTrue(source.contains("private var toolbarSearch: some View"))
        XCTAssertTrue(
            source.contains(
                "if showsSearch {\n                toolbarSearch\n                    .frame(maxWidth: .infinity, alignment: .center)"),
            "The search field should stay centered against the full toolbar width when visible, not the remaining space in an HStack."
        )
        XCTAssertTrue(source.contains("private var toolbarTrailingCluster: some View"))
        XCTAssertFalse(
            source.contains("Spacer(minLength: 8)\n\n            HomeMacToolbarSearchField("),
            "Search should not be pushed by a leading spacer in the same HStack as the command controls."
        )
        XCTAssertTrue(source.contains("private var toolbarCommandCluster: some View"))
        XCTAssertFalse(source.contains("private var commandRow: some View"))
        XCTAssertFalse(source.contains("static let commandRowHeight"))
        XCTAssertFalse(source.contains("commandRowBackground"))
        XCTAssertFalse(source.contains("static let titlebarHostWidth"))
        XCTAssertFalse(source.contains("static let titlebarToolbarGapHeight"))
        XCTAssertFalse(source.contains("titlebarTopPadding"))
        XCTAssertFalse(source.contains("static let minimumExpandedWidth"))
        XCTAssertFalse(source.contains("static let expandedSearchRowHeight"))
        XCTAssertFalse(source.contains("static let expandedSearchHorizontalInset"))
        XCTAssertFalse(source.contains("static let expandedOverlayTopPadding"))
        XCTAssertFalse(source.contains("static let activeHostWidth"))
        XCTAssertFalse(source.contains("static let hostReleaseDelay"))
        XCTAssertTrue(source.contains("static let height: CGFloat = 44"))
        XCTAssertTrue(source.contains("static let toolbarActionRestoreDelay: TimeInterval = animationDuration"))
        XCTAssertTrue(homeSource.contains("@State var isToolbarSearchTextFocused = false"))
        XCTAssertTrue(homeSource.contains("@State var isToolbarSearchExpanded = false"))
        XCTAssertTrue(homeSource.contains("@State var toolbarSearchVisiblePillWidth = HomeMacToolbarSearchLayout.compactWidth"))
        XCTAssertTrue(homeSource.contains("@State var toolbarSearchExpansionTransitionID = 0"))
        XCTAssertTrue(homeSource.contains("@State var toolbarSearchFocusRequestID = 0"))
        XCTAssertTrue(homeSource.contains("@State var toolbarSearchFocusDismissRequestID = 0"))
        XCTAssertTrue(homeSource.contains("@State var isMacWindowFullscreen = false"))
        XCTAssertFalse(homeSource.contains("isMacFullscreenTitlebarRevealed"))
        XCTAssertTrue(platformSource.contains("isSearchTextFocused: $isToolbarSearchTextFocused"))
        XCTAssertTrue(platformSource.contains("showsSearch: showsHomeToolbarSearch"))
        XCTAssertTrue(platformSource.contains("var showsHomeToolbarSearch: Bool"))
        XCTAssertTrue(platformSource.contains("!isMacStatsMode"))
        XCTAssertTrue(platformSource.contains("&& !isMacAddTaskMode"))
        XCTAssertTrue(platformSource.contains("searchVisiblePillWidth: $toolbarSearchVisiblePillWidth"))
        XCTAssertTrue(platformSource.contains("searchExpansionTransitionID: $toolbarSearchExpansionTransitionID"))
        XCTAssertTrue(platformSource.contains("searchFocusRequestID: $toolbarSearchFocusRequestID"))
        XCTAssertTrue(platformSource.contains("searchFocusDismissRequestID: $toolbarSearchFocusDismissRequestID"))
        XCTAssertFalse(detailSource.contains("matchedGeometryEffect("))
        XCTAssertFalse(detailSource.contains("taskDetailSurfaceMotion("))
        XCTAssertFalse(detailSource.contains("MacTaskDetailSurfaceMotionModifier"))
        XCTAssertTrue(
            detailSource.contains("static func taskDetailFullscreen(edge: Edge) -> AnyTransition {\n        .identity\n    }"),
            "Task details should not duplicate translucent surfaces while expanding into Full Details."
        )
        XCTAssertTrue(
            detailSource.contains("static func taskDetailPane(edge: Edge) -> AnyTransition {\n        .identity\n    }"),
            "Task detail companion panes should enter and leave without opacity/scale compositing."
        )
        XCTAssertTrue(
            detailSource.contains("static var taskDetailWorkspace: AnyTransition {\n        .identity\n    }"),
            "The workspace behind task details should not fade under duplicated detail cards."
        )
        XCTAssertTrue(platformSource.contains("func focusExpandedToolbarSearchFromCommand()"))
        XCTAssertTrue(platformSource.contains("focusExpandedToolbarSearchFromCommand()"))
        XCTAssertTrue(
            platformSource.contains(
                "toolbarSearchVisiblePillWidth = HomeMacToolbarSearchLayout.compactWidth\n            isToolbarSearchExpanded = true"))
        XCTAssertFalse(platformSource.contains("HomeMacExpandedToolbarSearchOverlay("))
        XCTAssertFalse(platformSource.contains("private var expandedToolbarSearchRow: some View"))
        XCTAssertFalse(platformSource.contains(".frame(height: HomeMacToolbarSearchLayout.expandedSearchRowHeight)"))
        XCTAssertFalse(platformSource.contains("expandedOverlayTopPadding"))
        XCTAssertFalse(platformSource.contains(".transition(.identity)"))
        XCTAssertFalse(platformSource.contains(".zIndex(30)"))
        XCTAssertTrue(source.contains("@Binding var isTextFocused: Bool"))
        XCTAssertTrue(source.contains("@Binding var isSearchExpanded: Bool"))
        XCTAssertTrue(source.contains("@Binding var visiblePillWidth: CGFloat"))
        XCTAssertTrue(source.contains("@Binding var searchExpansionTransitionID: Int"))
        XCTAssertTrue(source.contains("@Binding var focusRequestID: Int"))
        XCTAssertTrue(source.contains("@Binding var focusDismissRequestID: Int"))
        XCTAssertFalse(source.contains("@State private var isTextFocused = false"))
        XCTAssertFalse(source.contains("@State private var visiblePillWidth = HomeMacToolbarSearchLayout.compactWidth"))
        XCTAssertFalse(source.contains("@State private var searchModeTransitionID"))
        XCTAssertFalse(source.contains("@State private var searchExpansionTransitionID = 0"))
        XCTAssertFalse(source.contains("@State private var focusRequestID = 0"))
        XCTAssertFalse(source.contains("@State private var focusDismissRequestID = 0"))
        XCTAssertTrue(source.contains("private func beginSearchFocusRequest()"))
        XCTAssertTrue(source.contains("focusRequestID += 1\n        setSearchFocused(true)"))
        XCTAssertTrue(
            source.contains("guard focusTextField(selectingText: false) else { return }\n            handledFocusRequestID = requestID"))
        XCTAssertFalse(source.contains("setSearchFocused(true)\n        DispatchQueue.main.async"))
        XCTAssertFalse(source.contains("private func setSearchModeActive"))
        XCTAssertFalse(source.contains("transaction.disablesAnimations = true"))
        XCTAssertFalse(source.contains("activeHostWidth"))
        XCTAssertFalse(source.contains("private var layoutWidth: CGFloat"))
        XCTAssertFalse(
            source.contains("isSearchExpanded ? HomeMacToolbarSearchLayout.focusedWidth : HomeMacToolbarSearchLayout.compactWidth"))
        XCTAssertFalse(source.contains("if !isSearchExpanded {\n            ToolbarItem(placement: .navigation)"))
        XCTAssertFalse(source.contains("ToolbarItem(placement: .principal) {\n            HomeMacToolbarSearchField("))
        XCTAssertTrue(source.contains("RoutinaMacPlaceCheckInToolbarButton("))
        XCTAssertTrue(source.contains("MacToolbarStatusBadge("))
        XCTAssertTrue(source.contains("let showsDoneCount: Bool"))
        XCTAssertTrue(source.contains("if showsDoneCount {\n                MacToolbarStatusBadge("))
        XCTAssertTrue(source.contains("HomeMacBoardInspectorToolbarButton("))
        XCTAssertFalse(source.contains("let titlebarContainerView = closeButton.superview"))
        XCTAssertFalse(source.contains("containerView.addSubview(hostingView, positioned: .above, relativeTo: nil)"))
        XCTAssertFalse(source.contains("alignmentButton.convert(buttonCenter, to: containerView).y"))
        XCTAssertFalse(source.contains("hostingView.frame = NSRect("))
        XCTAssertFalse(source.contains("NSWindow.didResizeNotification"))
        XCTAssertFalse(source.contains("window.addTitlebarAccessoryViewController(accessory)"))
        XCTAssertFalse(source.contains("hittableWidth = parent.visiblePillWidth"))
        XCTAssertTrue(platformSource.contains("isSearchExpanded: $isToolbarSearchExpanded"))
        XCTAssertTrue(platformSource.contains("isSearchTextFocused: $isToolbarSearchTextFocused"))
        XCTAssertTrue(platformSource.contains("isCreatingTaskFromSearch: isToolbarSearchCreateInProgress"))
        XCTAssertTrue(platformSource.contains("guard showsHomeToolbarSearch else { return }"))
        XCTAssertTrue(platformSource.contains(".onChange(of: showsHomeToolbarSearch)"))
        XCTAssertTrue(platformSource.contains("dismissToolbarSearchFocus()"))
        XCTAssertFalse(platformSource.contains(".background(homeTitlebarSearchInstaller)"))
        XCTAssertFalse(platformSource.contains("ToolbarItemGroup(placement: .primaryAction) {\n            if isDevelopmentAppVariant"))
        XCTAssertFalse(platformSource.contains("if !isToolbarSearchExpanded {\n            ToolbarItemGroup(placement: .primaryAction)"))
        XCTAssertFalse(platformSource.contains("if !isToolbarSearchExpanded {\n            ToolbarItem(placement: .primaryAction)"))
        XCTAssertFalse(platformSource.contains("hidesTaskDetailToolbarActions: isToolbarSearchExpanded"))
        XCTAssertFalse(homeSource.contains("hidesToolbarActions: isToolbarSearchExpanded"))
        XCTAssertFalse(detailSource.contains("let hidesTaskDetailToolbarActions: Bool"))
        XCTAssertFalse(detailSource.contains("hidesToolbarActions: hidesTaskDetailToolbarActions"))
        XCTAssertFalse(taskDetailSource.contains("hidesToolbarActions: Bool = false"))
        XCTAssertFalse(taskDetailSource.contains("hidesToolbarActions: hidesToolbarActions"))
        XCTAssertFalse(taskToolbarSource.contains("let hidesToolbarActions: Bool"))
        XCTAssertFalse(taskToolbarSource.contains("if !hidesToolbarActions {"))
        XCTAssertTrue(
            taskDetailSource.contains("headerAccessory: {\n                taskDetailActionCluster"),
            "Task-specific actions should live in the task detail header card instead of competing with toolbar search."
        )
        XCTAssertFalse(taskDetailSource.contains("taskDetailActionBar"))
        XCTAssertTrue(taskToolbarSource.contains("struct TaskDetailActionClusterView: View"))
        XCTAssertFalse(taskToolbarSource.contains("ToolbarItem(placement: .primaryAction)"))
        XCTAssertTrue(source.contains("let textField = HomeMacToolbarSearchClickableTextField(string: text)"))
        XCTAssertFalse(source.contains("HomeMacToolbarSearchNSTextField"))
        XCTAssertFalse(source.contains("onPrepareForFocus:"))
        XCTAssertFalse(source.contains("parent.onPrepareForFocus()"))
        XCTAssertFalse(source.contains("override func becomeFirstResponder() -> Bool"))
        XCTAssertTrue(source.contains("private final class HomeMacToolbarSearchClickableTextField: NSTextField"))
        XCTAssertTrue(source.contains("var onMouseDown: (() -> Void)?"))
        XCTAssertTrue(source.contains("override func mouseDown(with event: NSEvent)"))
        XCTAssertTrue(source.contains("func pointerFocusRequested()"))
        XCTAssertFalse(source.contains("HomeMacToolbarSearchAnimatedHost"))
        XCTAssertFalse(source.contains("HomeMacToolbarSearchHostNSView"))
        XCTAssertFalse(source.contains("PillTransitionDirection"))
        XCTAssertFalse(source.contains("keepsActiveHost"))
        XCTAssertTrue(source.contains("searchShell(width: visiblePillWidth)"))
        XCTAssertTrue(source.contains("value: visiblePillWidth"))
        XCTAssertFalse(source.contains("targetWidth"))
        XCTAssertTrue(source.contains("private func searchShell(width: CGFloat) -> some View"))
        XCTAssertTrue(source.contains("private var textLeading: CGFloat"))
        XCTAssertTrue(source.contains(".offset(x: HomeMacToolbarSearchLayout.horizontalPadding)"))
        XCTAssertTrue(source.contains(".padding(.leading, textLeading)"))
        XCTAssertTrue(source.contains(".frame(width: width, height: HomeMacToolbarSearchLayout.height, alignment: .leading)"))
        XCTAssertTrue(source.contains(".frame(width: width, height: HomeMacToolbarSearchLayout.height)"))
        XCTAssertTrue(source.contains(".frame(\n                width: visiblePillWidth,"))
        XCTAssertFalse(source.contains(".frame(width: layoutWidth,"))
        XCTAssertFalse(source.contains("HStack(spacing: 10) {\n            Image(systemName: \"magnifyingglass\")"))
        XCTAssertTrue(source.contains("private var searchFocusBinding: Binding<Bool>"))
        XCTAssertTrue(source.contains("set: { setSearchFocused($0) }"))
        XCTAssertFalse(
            source.contains(
                "(isFocused || keepsActiveHost) ? HomeMacToolbarSearchLayout.activeHostWidth : HomeMacToolbarSearchLayout.compactWidth"))
        XCTAssertFalse(source.contains(".onChange(of: isFocused)"))
        XCTAssertFalse(source.contains("DispatchQueue.main.asyncAfter(deadline: .now() + HomeMacToolbarSearchLayout.hostReleaseDelay)"))
        XCTAssertTrue(
            source.contains("DispatchQueue.main.asyncAfter(deadline: .now() + HomeMacToolbarSearchLayout.toolbarActionRestoreDelay)"))
        XCTAssertTrue(
            source.contains(
                "if nextValue {\n"
                    + "            searchExpansionTransitionID += 1\n"
                    + "            let transitionID = searchExpansionTransitionID\n"
                    + "            if !isSearchExpanded {"
            ))
        XCTAssertTrue(
            source.contains(
                "visiblePillWidth = HomeMacToolbarSearchLayout.compactWidth\n"
                    + "                isSearchExpanded = true\n"
                    + "                DispatchQueue.main.async"
            ))
        XCTAssertTrue(source.contains("animateVisiblePillWidth(to: HomeMacToolbarSearchLayout.focusedWidth)"))
        XCTAssertFalse(source.contains("guard !isTextFocused else { return }"))
        XCTAssertTrue(source.contains("animateVisiblePillWidth(to: HomeMacToolbarSearchLayout.compactWidth)"))
        XCTAssertTrue(source.contains("private func animateVisiblePillWidth(to width: CGFloat)"))
        XCTAssertTrue(source.contains("let transitionID = searchExpansionTransitionID\n        DispatchQueue.main.asyncAfter"))
        XCTAssertTrue(source.contains("guard searchExpansionTransitionID == transitionID else { return }"))
        XCTAssertFalse(source.contains("guard searchExpansionTransitionID == transitionID, !self.isTextFocused else { return }"))
        XCTAssertTrue(source.contains("isSearchExpanded = false"))
        XCTAssertFalse(source.contains("animationStageWidth"))
        XCTAssertFalse(source.contains(".frame(maxWidth: .infinity, maxHeight: HomeMacToolbarSearchLayout.height)"))
        XCTAssertTrue(source.contains("HomeMacToolbarSearchTextEditorView"))
        XCTAssertTrue(source.contains("Image(systemName: \"magnifyingglass\")"))
        XCTAssertTrue(source.contains("private var centeredIdleContent: some View"))
        XCTAssertTrue(source.contains("private var usesCenteredIdleContent: Bool"))
        XCTAssertTrue(source.contains("!isTextFocused && text.isEmpty"))
        XCTAssertTrue(source.contains("HomeMacToolbarSearchLayout.searchBackgroundColor(isFocused: isTextFocused)"))
        XCTAssertTrue(source.contains("static func searchBackgroundColor(isFocused: Bool) -> Color"))
        XCTAssertTrue(source.contains("Color(nsColor: .textBackgroundColor).opacity(0.98)"))
        XCTAssertTrue(source.contains("textField.isBordered = false"))
        XCTAssertTrue(source.contains("textField.drawsBackground = false"))
        XCTAssertTrue(source.contains("textField.leadingAnchor.constraint(equalTo: leadingAnchor)"))
        XCTAssertTrue(source.contains("textField.trailingAnchor.constraint(equalTo: trailingAnchor)"))
        XCTAssertTrue(source.contains("setContentHuggingPriority(.defaultLow, for: .horizontal)"))
        XCTAssertTrue(source.contains("NSView.noIntrinsicMetric"))
        XCTAssertTrue(source.contains("textField.alignment = .left"))
        XCTAssertTrue(source.contains("textField.cell?.alignment = .left"))
        XCTAssertTrue(source.contains("textField.cell?.usesSingleLineMode = true"))
        XCTAssertTrue(source.contains("Image(systemName: \"xmark.circle.fill\")"))
        XCTAssertTrue(source.contains("static let clearButtonHitSize: CGFloat = 34"))
        XCTAssertTrue(source.contains("width: HomeMacToolbarSearchLayout.clearButtonHitSize"))
        XCTAssertTrue(source.contains("DragGesture(minimumDistance: 0)"))
        XCTAssertTrue(source.contains("guard !text.isEmpty else { return }\n                    clearSearchText()"))
        XCTAssertTrue(source.contains("Clear search"))
        XCTAssertTrue(source.contains("isTextFocused && (isCreatingTask || canCreateTaskFromQuery)"))
        XCTAssertTrue(source.contains("controlTextDidBeginEditing"))
        XCTAssertTrue(source.contains("@Binding var isFocused: Bool"))
        XCTAssertTrue(source.contains("self.handledFocusRequestID = parent.focusRequestID - 1"))
        XCTAssertTrue(
            source.contains("guard handledFocusRequestID == parent.focusRequestID else { return }"))
        XCTAssertTrue(
            source.contains(
                "guard parent.isFocused else {\n"
                    + "                handledFocusRequestID = requestID\n"
                    + "                return\n"
                    + "            }\n"
                    + "            guard focusTextField(selectingText: false) else { return }"
            ))
        XCTAssertTrue(source.contains("focusDismissRequestID += 1"))
        XCTAssertTrue(source.contains("private func dismissSearchFocusFromKeycap()"))
        XCTAssertTrue(source.contains("setSearchFocused(false)\n        focusDismissRequestID += 1"))
        XCTAssertTrue(source.contains("searchFocusTarget(width: width)"))
        XCTAssertFalse(source.contains(".onTapGesture {\n            beginSearchFocusRequest()\n        }"))
        XCTAssertTrue(source.contains("dismissFocusIfNeeded(for: nextFocusDismissRequestID)"))
        XCTAssertTrue(source.contains("HomeMacSearchOutsideDismissView"))
        XCTAssertTrue(source.contains("NSEvent.addLocalMonitorForEvents"))
        XCTAssertTrue(source.contains("NSEvent.addLocalMonitorForEvents(matching: .keyDown)"))
        XCTAssertTrue(source.contains("guard event.keyCode == 53"))
        XCTAssertTrue(source.contains("matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]"))
        XCTAssertTrue(source.contains("clickIsInsideVisiblePill"))
        XCTAssertTrue(source.contains("view.bounds.insetBy(dx: -2, dy: -2).contains(viewLocation)"))
        XCTAssertTrue(source.contains("HomeMacSearchInteractionRegionView()"))
        XCTAssertTrue(source.contains("clickIsInsideParserPreview("))
        XCTAssertTrue(source.contains("currentMouseDownIsInsideParserPreview(relativeTo: textField)"))
        XCTAssertTrue(
            source.contains("event.window === window\n            else {"),
            "Picker menu-window events must not be mistaken for clicks outside the Quick Add surface."
        )
        XCTAssertTrue(source.contains("parent.isFocused = true\n                parent.focusRequestID += 1"))
        XCTAssertTrue(source.contains("view.setPrefersIBeamCursor(isFocused)"))
        XCTAssertTrue(source.contains("window.invalidateCursorRects(for: self)"))
        XCTAssertTrue(source.contains("addCursorRect(bounds, cursor: .iBeam)"))
        XCTAssertTrue(source.contains("#selector(NSResponder.cancelOperation(_:))"))
        XCTAssertTrue(source.contains("dismissSearchFocus()"))
        XCTAssertTrue(source.contains("window.makeFirstResponder(nil)"))
        XCTAssertTrue(source.contains("Text(\"Esc\")"))
        XCTAssertTrue(source.contains("Dismiss search focus"))
        XCTAssertFalse(source.contains("Image(systemName: \"xmark\")"))
        XCTAssertTrue(
            rootSceneSource.contains("window.toolbarStyle = .unifiedCompact"),
            "The native Mac window chrome should stay compact because Home draws its own titlebar-height toolbar row."
        )
        XCTAssertTrue(
            rootSceneSource.contains(
                "setFullSizeContentView(\n"
                    + "                isEnabled: !window.styleMask.contains(.fullScreen),\n"
                    + "                for: window\n"
                    + "            )"
            ),
            "Normal Home windows should keep full-size transparent titlebar content, while fullscreen should not let split/sidebar backing draw behind traffic lights."
        )
        XCTAssertTrue(rootSceneSource.contains("NSWindow.didEnterFullScreenNotification"))
        XCTAssertTrue(rootSceneSource.contains("NSWindow.didExitFullScreenNotification"))
        XCTAssertTrue(rootSceneSource.contains("configureFullscreenTitlebarMode(\n                    isFullscreen: true"))
        XCTAssertTrue(rootSceneSource.contains("configureFullscreenTitlebarMode(\n                    isFullscreen: false"))
        XCTAssertTrue(rootSceneSource.contains("window.styleMask.insert(.fullSizeContentView)"))
        XCTAssertTrue(rootSceneSource.contains("window.styleMask.remove(.fullSizeContentView)"))
        XCTAssertTrue(rootSceneSource.contains("window.titlebarSeparatorStyle = .none"))
        XCTAssertTrue(rootSceneSource.contains("window.toolbar?.sizeMode = .small"))
        XCTAssertFalse(rootSceneSource.contains("showsBaselineSeparator"))
        XCTAssertFalse(
            rootSceneSource.contains("window.toolbarStyle = .expanded"),
            "Expanded native toolbar chrome creates a separate fullscreen strip over the custom Home toolbar."
        )
        XCTAssertTrue(
            platformSource.contains(".toolbarBackgroundVisibility(.hidden, for: .windowToolbar)"),
            "The native window toolbar background should not paint an opaque strip over the SwiftUI-owned Home toolbar in fullscreen."
        )
        XCTAssertTrue(platformSource.contains("HomeMacWindowFullscreenObserver(isFullscreen: $isMacWindowFullscreen)"))
        XCTAssertTrue(platformSource.contains(".routinaMacHomeToolbarTitlebarIntegration(isFullscreen: isMacWindowFullscreen)"))
        XCTAssertTrue(
            appShellSource.contains("func routinaMacHomeToolbarTitlebarIntegration(isFullscreen: Bool) -> some View"),
            "Mac Home should keep fullscreen titlebar behavior centralized instead of scattering safe-area tweaks through Home content."
        )
        XCTAssertTrue(appShellSource.contains("if isFullscreen {\n            self"))
        XCTAssertTrue(appShellSource.contains("} else {\n            ignoresSafeArea(edges: .top)\n        }"))
        XCTAssertFalse(platformSource.contains("static let stableTitlebarHeight"))
        XCTAssertFalse(platformSource.contains("HomeMacFullscreenChrome"))
        XCTAssertFalse(platformSource.contains("HomeMacFullscreenTitlebarReserveBackground"))
        XCTAssertFalse(platformSource.contains("padding(.top, HomeMacFullscreenChrome.stableTitlebarHeight)"))
        XCTAssertFalse(
            platformSource.contains(".overlay(alignment: .top) {\n                    HomeMacFullscreenTitlebarReserveBackground()"),
            "Fullscreen must not add a separate visible reserve band above the integrated Home toolbar."
        )
        XCTAssertTrue(platformSource.contains(".padding(.top, HomeMacToolbarSearchLayout.topToolbarHeight)"))
        XCTAssertTrue(source.contains("static let trafficLightReservedLeadingPadding: CGFloat = 184"))
        XCTAssertTrue(source.contains("static let sidebarToggleLeadingPadding: CGFloat = 28"))
        XCTAssertTrue(
            source.contains(".padding(.leading, HomeMacToolbarSearchLayout.trafficLightReservedLeadingPadding)"),
            "Toolbar controls should start after the native traffic-light region so fullscreen can avoid a separate vertical dead band."
        )
        XCTAssertFalse(platformSource.contains("routinaMacFullscreenTitlebarSafeArea"))
        XCTAssertFalse(platformSource.contains("routinaMacFullscreenTitlebarSpacing"))
        XCTAssertFalse(platformSource.contains("NSEvent.mouseLocation"))
        XCTAssertFalse(platformSource.contains("titlebarRevealPollingTask"))
        XCTAssertFalse(platformSource.contains("titlebarHideTask"))
        XCTAssertFalse(platformSource.contains("isTitlebarRevealed"))
        XCTAssertFalse(platformSource.contains("setTitlebarRevealed"))
        XCTAssertTrue(appShellSource.contains("NSWindow.willEnterFullScreenNotification"))
        XCTAssertTrue(appShellSource.contains("NSWindow.didExitFullScreenNotification"))
        XCTAssertTrue(appShellSource.contains("private var isAttachRetryScheduled = false"))
        XCTAssertFalse(
            appShellSource.contains("observedWindow = nil\n            setFullscreen(false)"),
            "Detaching the helper NSView must not clear fullscreen state; SwiftUI detach/reattach can otherwise make fullscreen chrome blink."
        )
        XCTAssertTrue(source.contains("textField.controlSize = .large"))
        XCTAssertTrue(source.contains("textField.focusRingType = .none"))
        XCTAssertFalse(source.contains("focusRingType = .default"))
        XCTAssertTrue(source.contains("Search or create a task"))
        XCTAssertTrue(source.contains("canCreateTaskFromQuery"))
        XCTAssertTrue(source.contains("Return"))
        XCTAssertTrue(source.contains("Create task"))
        XCTAssertTrue(source.contains("static let createHintWidth: CGFloat = 154"))
        XCTAssertTrue(
            source.contains(".frame(width: HomeMacToolbarSearchLayout.createHintWidth, alignment: .leading)"),
            "The Return/Create task hint needs a reserved width so the transparent text editor cannot compress it out of view."
        )
        XCTAssertTrue(
            source.contains(
                "createHint\n"
                    + "                        .transition(.opacity.combined(with: .scale(scale: 0.98)))\n"
                    + "                        .layoutPriority(3)"
            ),
            "The create hint should outrank the flexible text editor during toolbar search layout."
        )
        XCTAssertTrue(source.contains("HomeMacToolbarSearchParserPreview"))
        XCTAssertTrue(source.contains("Detected details"))
        XCTAssertTrue(source.contains("RoutinaQuickAddDraft"))
        XCTAssertTrue(source.contains("enum HomeMacToolbarSearchLayout"))
        XCTAssertFalse(source.contains("parserPreviewDraft"))
        XCTAssertFalse(source.contains("parserPreviewPresentation"))
        XCTAssertFalse(source.contains(".popover("))
        XCTAssertFalse(source.contains("NSSearchField"))
        XCTAssertTrue(source.contains("routinaMacFocusSearchOrCreate"))
        XCTAssertTrue(source.contains("parent.onSubmit"))
        XCTAssertTrue(source.contains("restoreFocusAfterSearchUpdate()"))
        XCTAssertTrue(source.contains("let selectedRange = textField.currentEditor()?.selectedRange"))
        XCTAssertTrue(source.contains("editor.selectedRange = HomeMacToolbarSearchTextField.clampedSelectionRange("))
        XCTAssertFalse(
            source.contains("location: textField.stringValue.count"),
            "Toolbar search focus restore must preserve the field editor selection so mid-string typing does not jump to the end."
        )
        XCTAssertTrue(
            source.contains("shouldLeaveCurrentTextEditorFocused"),
            "Toolbar search may restore focus after filtering, but it must not steal focus from an intentionally focused comment, note, or other text editor."
        )
        XCTAssertTrue(source.contains("window.firstResponder as? NSTextView"))
        XCTAssertTrue(source.contains("activeEditor !== textField.currentEditor()"))
        XCTAssertTrue(platformSource.contains("createTaskFromToolbarSearch"))
        XCTAssertTrue(platformSource.contains("canCreateTaskFromToolbarSearch"))
        XCTAssertTrue(platformSource.contains("toolbarSearchCreateDraft"))
        XCTAssertFalse(platformSource.contains("parserPreviewDraft: toolbarSearchCreateDraft"))
        XCTAssertTrue(platformSource.contains("RoutinaQuickAddParser.parse"))
        XCTAssertTrue(platformSource.contains("draft.hasDetectedMetadata"))
        XCTAssertTrue(platformSource.contains("HomeMacToolbarSearchParserPreview("))
        XCTAssertTrue(platformSource.contains("reminderChoice: $toolbarSearchReminderChoice"))
        XCTAssertTrue(platformSource.contains("customReminderAt: $toolbarSearchCustomReminderAt"))
        XCTAssertTrue(platformSource.contains("taskTitle: toolbarSearchTaskTitleBinding"))
        XCTAssertTrue(platformSource.contains("resolveToolbarSearchLinkTitle"))
        XCTAssertTrue(platformSource.contains("reconcileToolbarSearchPreviewState"))
        XCTAssertTrue(platformSource.contains("RoutinaQuickAddDraftContinuity.canPreservePreviewState"))
        XCTAssertTrue(platformSource.contains("toolbarSearchPinnedParserPreviewDraft"))
        XCTAssertTrue(platformSource.contains("RoutinaQuickAddPreviewPinning.updatedDraft"))
        XCTAssertTrue(platformSource.contains("toolbarSearchHasConfirmedResult"))
        XCTAssertTrue(platformSource.contains("value: toolbarSearchPinnedParserPreviewDraft != nil"))
        XCTAssertFalse(
            platformSource.contains("value: toolbarSearchCreateDraft\n"),
            "Transient parser eligibility must not own the detected-details container transition."
        )
        XCTAssertTrue(platformSource.contains("return linkURL.absoluteString"))
        XCTAssertFalse(platformSource.contains("toolbarSearchTaskTitleSourceText"))
        XCTAssertFalse(
            platformSource.contains(
                ".onChange(of: searchTextBinding.wrappedValue) { _, newValue in\n                toolbarSearchReminderChoice = .none"),
            "Compatible Quick Add query edits must not unconditionally clear the selected reminder."
        )
        XCTAssertTrue(platformSource.contains("submission: HomeMacToolbarQuickAddSubmission? = nil"))
        XCTAssertTrue(platformSource.contains("submission: submission"))
        XCTAssertTrue(platformSource.contains("reminderAt: resolvedSubmission?.reminderAt"))
        XCTAssertTrue(platformSource.contains("taskNameOverride: resolvedSubmission?.taskTitle"))
        XCTAssertTrue(source.contains("LPMetadataProvider"))
        XCTAssertTrue(source.contains("TextField(\"Task title\", text: $taskTitle)"))
        XCTAssertTrue(
            source.contains(
                ".onSubmit {\n"
                    + "                onSubmit(\n"
                    + "                    HomeMacToolbarQuickAddSubmission("
            ))
        XCTAssertTrue(source.contains("Fetching title…"))
        XCTAssertTrue(source.contains("No reminder"))
        XCTAssertTrue(source.contains("1 hour before"))
        XCTAssertTrue(source.contains("2 hours before"))
        XCTAssertTrue(source.contains("1 day before"))
        XCTAssertTrue(source.contains("Custom date/time"))
        XCTAssertTrue(source.contains("Updating details…"))
        XCTAssertTrue(platformSource.contains("HomeMacToolbarSearchLayout.focusedWidth"))
        XCTAssertTrue(platformSource.contains("HomeMacToolbarSearchLayout.parserPreviewTopPadding"))
        XCTAssertTrue(source.contains("static let parserPreviewTrailingPadding: CGFloat = 22"))
        XCTAssertFalse(source.contains(".background(.bar)"))
        XCTAssertTrue(
            platformSource.contains(
                "HomeMacToolbarSearchLayout.topToolbarHeight\n"
                    + "                    + HomeMacToolbarSearchLayout.parserPreviewTopPadding"
            ),
            "Quick-add parser previews should appear below the custom top toolbar chrome instead of covering the search row."
        )
        XCTAssertFalse(platformSource.contains("HomeMacToolbarSearchLayout.parserPreviewTrailingPadding"))
        XCTAssertFalse(platformSource.contains("HomeMacToolbarSearchLayout.expandedSearchHorizontalInset"))
        XCTAssertTrue(platformSource.contains("hasToolbarSearchResult"))
        XCTAssertTrue(platformSource.contains("!hasToolbarSearchResult(for: trimmedText)"))
        XCTAssertFalse(
            platformSource.contains("MacQuickAddSpotlightOverlay"),
            "The configurable quick-add shortcut should now be merged into the toolbar search field instead of opening a separate overlay."
        )
        XCTAssertTrue(platformSource.contains("plannerSearchText: macSearchPresentationText"))
        XCTAssertTrue(detailSource.contains("calendarSearchText: plannerSearchText"))
        XCTAssertTrue(dayPlanSource.contains("filteredBlocksByDayKey("))
        XCTAssertTrue(dayPlanSource.contains("filteredTimelineBlocksByDayKey("))
        XCTAssertTrue(dayPlanSource.contains("tasksMatchingCalendarSearch(from: currentTasks)"))
        XCTAssertFalse(
            sidebarSource.contains("platformSearchField(searchText: searchTextBinding)"),
            "Task and timeline search should have one active text field. Duplicating the shared search binding in the sidebar steals first responder from the toolbar field."
        )
        XCTAssertFalse(source.contains("RoutinaMacFocusTimerToolbarItem(hiddenKinds: [.unassigned])"))
        XCTAssertFalse(detailSource.contains("plannerHeaderFocusControl"))
        XCTAssertFalse(dayPlanSource.contains("macFocusControl"))
        XCTAssertTrue(controlsSource.contains("Label(shortcut.menuTitle, systemImage: shortcut.systemImage)"))
        XCTAssertTrue(controlsSource.contains(".keyboardShortcut(shortcut.keyEquivalent, modifiers: shortcut.modifiers)"))
        XCTAssertFalse(controlsSource.contains("onlyVisibleAddMenuShortcut"))
        XCTAssertTrue(shortcutSource.contains("return \"Add New Task\""))
        XCTAssertTrue(shortcutSource.contains("case .focus:   return \"f\""))
        XCTAssertTrue(commandSource.contains("addMenuCommand(.focus, notificationName: .routinaMacOpenFocus)"))
    }

    func testMacSearchNoResultSidebarCanOpenSeededAddTask() throws {
        let taskListSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+TaskList.swift")
        let sidebarSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Sidebar.swift")
        let platformSource = try SourceInspectionSupport.readMacHomePlatformSources()

        XCTAssertTrue(
            sidebarSource.contains("return \"Try a different timeline search or filters.\""),
            "The task-list sidebar should match the Planner Timeline no-results subtext while a search query is active."
        )
        XCTAssertTrue(taskListSource.contains("canCreateTaskFromToolbarSearch"))
        XCTAssertTrue(taskListSource.contains("actionTitle: \"Create task\""))
        XCTAssertTrue(
            taskListSource.contains("openAddTaskFromToolbarSearch(searchTextBinding.wrappedValue)"),
            "The sidebar no-results action should reuse the seeded full-form route instead of quick-creating directly."
        )
        XCTAssertTrue(platformSource.contains("func openAddTaskFromToolbarSearch(_ rawText: String)"))
        XCTAssertTrue(platformSource.contains("toolbarSearchFocusDismissRequestID += 1"))
        XCTAssertTrue(platformSource.contains("store.send(.openAddTaskSheet(seedName: trimmedText))"))
        XCTAssertFalse(
            platformSource.contains("private func openAddTaskFromToolbarSearch"),
            "The seeded Add Task route needs to be reusable by the sidebar no-results button."
        )
    }

    func testMacHomeFiltersUseRightSideCompanionPane() throws {
        let detailSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/MacDetailContainerView.swift")
        let filterContainerSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/HomeMacFilterDetailContainerView.swift")
        let sharedFilterControlsSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacImportanceUrgencyMatrixView.swift")
        let routineFilterSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/HomeMacRoutineFiltersDetailView.swift")
        let timelineFilterSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/HomeMacTimelineFiltersDetailView.swift")
        let calendarFilterSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/HomeMacCalendarFiltersDetailView.swift")
        let toolbarSource = try Self.homeMacToolbarSource()
        let dayPlanSource =
            try Self.sourceFile("SharedCore/Views/DayPlanView.swift")
            + "\n"
            + (try Self.sourceFile("SharedCore/Views/DayPlan/DayPlanHeaderView.swift"))
            + "\n"
            + (try Self.sourceFile("SharedCore/Views/DayPlan/DayPlanHeaderUtilityControls.swift"))
            + "\n"
            + (try Self.sourceFile("SharedCore/Views/DayPlan/DayPlanTimelineRenderSnapshot.swift"))
        let sidebarSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Sidebar.swift")
        let platformSource = try SourceInspectionSupport.readMacHomePlatformSources()
        let boardSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Board.swift")
        let timelineSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Timeline.swift")
        guard
            let fullscreenFilterStart = detailSource.range(of: "private var fullscreenFilterDetailContent: some View"),
            let fullscreenFilterEnd = detailSource.range(
                of: "private var mainDetailContent: some View",
                range: fullscreenFilterStart.upperBound..<detailSource.endIndex
            )
        else {
            XCTFail("Fullscreen filter detail source boundary is missing.")
            return
        }
        let fullscreenFilterSource = String(
            detailSource[fullscreenFilterStart.lowerBound..<fullscreenFilterEnd.lowerBound]
        )

        XCTAssertTrue(detailSource.contains("static let filterDetailPaneWidth: CGFloat = 420"))
        XCTAssertTrue(detailSource.contains("static let fullscreenFilterContentMaxWidth: CGFloat = 840"))
        XCTAssertTrue(fullscreenFilterSource.contains("MacDetailContainerSizing.fullscreenFilterContentMaxWidth"))
        XCTAssertTrue(detailSource.contains("private var filterDetailPane: some View"))
        XCTAssertTrue(detailSource.contains("private var fullscreenFilterDetailContent: some View"))
        XCTAssertTrue(detailSource.contains("onMinimizeFullscreenFilterDetail"))
        XCTAssertEqual(
            detailSource.components(separatedBy: ".background(Color.secondary.opacity(0.045), ignoresSafeAreaEdges: [])").count - 1,
            2,
            "Right-side companion pane backgrounds should stop at the toolbar safe area instead of tinting behind the principal search field."
        )
        XCTAssertTrue(detailSource.contains("onCloseTaskDetails()\n                        onCloseFilterDetail()"))
        XCTAssertTrue(filterContainerSource.contains("GeometryReader"))
        XCTAssertTrue(filterContainerSource.contains(".frame(width: proxy.size.width, alignment: .topLeading)"))
        XCTAssertTrue(filterContainerSource.contains("compactHorizontalPadding"))
        XCTAssertTrue(filterContainerSource.contains("HomeMacFilterDetailLayout(availableWidth: proxy.size.width)"))
        XCTAssertTrue(filterContainerSource.contains(".environment(\\.homeMacFilterDetailLayout, layout)"))
        XCTAssertTrue(sidebarSource.contains("case .calendar:"))
        XCTAssertTrue(sidebarSource.contains("macCalendarFiltersDetailContent"))
        XCTAssertTrue(sidebarSource.contains("minimumSegmentWidth: 82"))
        XCTAssertTrue(sidebarSource.contains("horizontalPadding: 8"))
        XCTAssertTrue(sidebarSource.contains("macFilterScopeIsActive"))
        XCTAssertTrue(sidebarSource.contains("Text(macFilterDetailScope.scopeDescription)"))
        XCTAssertFalse(sidebarSource.contains("minimumSegmentWidth: 132"))
        XCTAssertFalse(sidebarSource.contains(".frame(maxWidth: 520)"))
        XCTAssertFalse(routineFilterSource.contains(".frame(width: 520)"))
        XCTAssertTrue(routineFilterSource.contains(".frame(maxWidth: .infinity)"))
        XCTAssertTrue(routineFilterSource.contains("HomeMacSidebarSectionCard(title: \"Filters\")"))
        XCTAssertTrue(routineFilterSource.contains("HomeMacAdaptiveFilterControlRow(\n                    \"Status\""))
        XCTAssertTrue(filterContainerSource.contains("struct HomeMacAdaptiveFilterChoiceControl"))
        XCTAssertTrue(filterContainerSource.contains("filterLayout.usesCompactPickers"))
        XCTAssertTrue(filterContainerSource.contains(".pickerStyle(.menu)"))
        XCTAssertGreaterThanOrEqual(
            routineFilterSource.components(
                separatedBy: "HomeMacAdaptiveFilterChoiceControl("
            ).count - 1,
            6,
            "Task List controls that previously wrapped in the companion pane should use adaptive compact pickers."
        )
        XCTAssertGreaterThanOrEqual(
            sharedFilterControlsSource.components(
                separatedBy: "HomeMacAdaptiveFilterChoiceControl("
            ).count - 1,
            5,
            "Every Task Ladder value should use an adaptive compact picker."
        )
        XCTAssertFalse(routineFilterSource.contains("maximumSegmentsPerRow"))
        XCTAssertFalse(sharedFilterControlsSource.contains("maximumSegmentsPerRow"))
        XCTAssertFalse(routineFilterSource.contains("HomeMacCollapsibleFilterSection(\n            title: \"Filters\""))
        XCTAssertTrue(routineFilterSource.contains("if showsFlagSection {"))
        XCTAssertTrue(routineFilterSource.contains("flagSectionContent()"))
        XCTAssertTrue(sidebarSource.contains("showsFlagSection: homeFlagFilterData.hasFlags"))
        XCTAssertTrue(platformSource.contains("var platformFlagFilterBar: some View"))
        XCTAssertFalse(timelineFilterSource.contains(".frame(width: 420)"))
        XCTAssertTrue(timelineFilterSource.contains(".frame(maxWidth: .infinity)"))
        XCTAssertTrue(timelineFilterSource.contains("@Binding var selectedStatus: TimelineStatusFilter"))
        XCTAssertTrue(timelineFilterSource.contains("selection: $selectedType"))
        XCTAssertTrue(timelineFilterSource.contains("selection: $selectedStatus"))
        XCTAssertTrue(timelineFilterSource.contains("fillsAvailableWidth: filterLayout.fillsAvailableWidth"))
        XCTAssertFalse(timelineFilterSource.contains("private var statusBinding"))
        XCTAssertTrue(calendarFilterSource.contains("HomeMacCalendarFiltersDetailView"))
        XCTAssertTrue(calendarFilterSource.contains("DayPlanCalendarFilterState"))
        XCTAssertTrue(toolbarSource.contains("HomeMacToolbarFilterButton"))
        XCTAssertTrue(dayPlanSource.contains("onCalendarFilterButtonPressed"))
        XCTAssertTrue(dayPlanSource.contains("DayPlanCalendarTaskFilterCache"))
        XCTAssertTrue(dayPlanSource.contains("calendarTaskFilterCache.snapshot("))
        XCTAssertFalse(dayPlanSource.contains("renderSnapshot.tasks.filter(calendarTaskFilter)"))
        XCTAssertTrue(
            dayPlanSource.contains(
                "if showsCalendarFilterButton {\n                calendarFilterButton\n            }"
            ))
        XCTAssertFalse(
            detailSource.contains("if store.isMacFilterDetailPresented {\n                filterView()"),
            "Home filters should no longer replace the full detail area when opened from the Planner filter button."
        )
        XCTAssertTrue(sidebarSource.contains("func toggleMacCalendarFilterDetailFromPlanner()"))
        XCTAssertTrue(sidebarSource.contains("func expandMacFilterDetailPane()"))
        XCTAssertTrue(sidebarSource.contains("isMacFilterDetailFullscreen = true"))
        XCTAssertTrue(sidebarSource.contains("taskDetailPanePlacement = nil\n            store.send(.setMacFilterDetailPresented(true))"))
        XCTAssertTrue(platformSource.contains("onToggleDayPlanCalendarFilters: toggleMacCalendarFilterDetailFromPlanner"))
        XCTAssertTrue(platformSource.contains("isFilterDetailFullscreen: isMacFilterDetailFullscreen"))
        XCTAssertTrue(boardSource.contains("var macBoardCenterContent: some View {\n        macTodoBoardContent\n    }"))
        XCTAssertTrue(
            timelineSource.contains(
                "isActive: isMacTimelineMode,\n                allowsFallbackSelection: !store.isMacFilterDetailPresented"))
    }

    func testMacFilterDetailLayoutUsesCompactPanePickersAndWideFullscreenRows() {
        let companionLayout = HomeMacFilterDetailLayout(availableWidth: 420)
        XCTAssertFalse(companionLayout.fillsAvailableWidth)
        XCTAssertTrue(companionLayout.usesCompactPickers)

        let fullscreenLayout = HomeMacFilterDetailLayout(availableWidth: 840)
        XCTAssertTrue(fullscreenLayout.fillsAvailableWidth)
        XCTAssertFalse(fullscreenLayout.usesCompactPickers)
    }

    func testMacFilterAppearanceRowsAlignNativeSwitchesWithFullWidthLabels() throws {
        let rowSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacSidebarSectionCard.swift"
        )
        let appearanceSources = try [
            "RoutinaMacApp/Screens/Home/Components/HomeMacRoutineFiltersDetailView.swift",
            "RoutinaMacApp/Screens/Home/Components/HomeMacTimelineFiltersDetailView.swift",
            "RoutinaMacApp/Screens/Home/Components/HomeMacCalendarFiltersDetailView.swift",
        ].map(Self.sourceFile)

        XCTAssertTrue(rowSource.contains("struct HomeMacFilterAppearanceToggleRow: View"))
        XCTAssertTrue(rowSource.contains("Toggle(isOn: $isOn)"))
        XCTAssertTrue(rowSource.contains(".toggleStyle(.switch)"))
        XCTAssertGreaterThanOrEqual(
            rowSource.components(
                separatedBy: ".frame(maxWidth: .infinity, alignment: .leading)"
            ).count - 1,
            2,
            "Both the native toggle and its label must accept the row width so every switch shares one trailing column."
        )
        XCTAssertTrue(
            rowSource.contains(".contentShape(Rectangle())"),
            "The expanded label surface must remain part of the toggle hit target."
        )

        for source in appearanceSources {
            XCTAssertTrue(
                source.contains("HomeMacFilterAppearanceToggleRow("),
                "Every Mac filter Appearance screen must use the aligned shared switch row."
            )
        }
    }

    func testPlannerTimelineListUsesHomeTimelineFilters() throws {
        let source = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Timeline.swift")
        let listSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/HomeMacTimelineSidebarView.swift")
        let sidebarSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Sidebar.swift")
        let platformSource = try SourceInspectionSupport.readMacHomePlatformSources()
        let dayPlanSource = try Self.sourceFile(
            "SharedCore/Views/DayPlan/DayPlanHeaderUtilityControls.swift"
        )
        guard
            let start = source.range(of: "var plannerTimelineEntries: [TimelineEntry] {"),
            let end = source.range(
                of: "var groupedPlannerTimelineEntries: [(date: Date, entries: [TimelineEntry])] {",
                range: start.upperBound..<source.endIndex
            )
        else {
            XCTFail("Expected planner timeline entry derivation to be present")
            return
        }
        let plannerEntriesSource = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(
            plannerEntriesSource.contains("timelineEntries"),
            "Planner List mode should use the same Home timeline entries as the Timeline sidebar so Both/Timeline filters apply consistently."
        )
        XCTAssertFalse(
            plannerEntriesSource.contains("unfilteredPlannerTimelineEntries"),
            "The unfiltered Planner Timeline source is only for empty-state counting and toolbar search result detection, not visible rows."
        )
        XCTAssertTrue(
            listSource.contains("Try a different timeline search or filters."),
            "Planner List's empty state should mention filters now that Home Timeline filters affect its visible rows."
        )
        XCTAssertTrue(
            listSource.contains("HomeMacPlannerTimelineFilterNotice"),
            "Planner Timeline should show active Timeline filters above older matching rows so hidden recent activity is discoverable."
        )
        XCTAssertTrue(
            listSource.contains("Clear Filters"),
            "Planner Timeline should expose a direct clear action for active Timeline filters."
        )
        XCTAssertTrue(
            source.contains("Newer activity hidden by filters"),
            "Planner Timeline should call out the specific case where filters hide newer activity while older rows remain visible."
        )
        XCTAssertTrue(
            sidebarSource.contains("dayPlanDisplayMode == .list ? .timeline : .calendar"),
            "The Planner filter button should open Timeline scope while Planner Timeline is selected."
        )
        XCTAssertTrue(
            platformSource.contains("isPlannerTimelineFilterActive: isPlannerTimelineListVisible && macHasActiveTimelineFilters"),
            "Planner Timeline filter state should drive the header filter button's active treatment."
        )
        XCTAssertTrue(
            dayPlanSource.contains("let isListMode = effectiveDisplayMode == .list"),
            "The shared Planner header should distinguish Timeline filters from Calendar layer filters."
        )
    }

    func testMacTimelineCachesWholeHistoryPresentationDuringScroll() throws {
        let source = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Timeline.swift")
        let homeSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView.swift")
        let refreshSource = try Self.sourceFile("SharedCore/Screens/Home/HomeTCAView+Refresh.swift")
        let listSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/HomeMacTimelineSidebarView.swift")

        XCTAssertTrue(source.contains("final class HomeMacTimelinePresentationCache"))
        XCTAssertTrue(source.contains("if cachedSignature == signature, let cachedPresentation"))
        XCTAssertTrue(source.contains("RoutinaMacScrollInteractionGate.isScrollActive, let cachedPresentation"))
        XCTAssertTrue(source.contains("private var macTimelinePresentation: HomeMacTimelinePresentation"))
        XCTAssertTrue(source.contains("macTimelinePresentationCache.presentation(for: signature)"))
        XCTAssertTrue(source.contains("let groupedFilteredEntries: [(date: Date, entries: [TimelineEntry])]"))
        XCTAssertTrue(source.contains("let rowNumbersByEntryID: [UUID: Int]"))
        XCTAssertTrue(homeSource.contains("@StateObject var macTimelinePresentationCache"))
        XCTAssertTrue(refreshSource.contains("macTimelinePresentationCache.invalidate()"))
        XCTAssertFalse(
            listSource.contains("private var rowNumbersByEntryID"),
            "Visible Timeline list body updates should reuse cached row numbers instead of walking all history."
        )
    }

    func testMacToolbarStatusBadgeKeepsStableTextWidth() throws {
        let source = try Self.sourceFile("RoutinaMacApp/Screens/Shared/MacToolbarComponents.swift")

        XCTAssertTrue(
            source.contains(".fixedSize(horizontal: true, vertical: false)"),
            "Toolbar status badges should reserve their measured text width so labels like the Done counter do not truncate while AppKit relayouts."
        )
        XCTAssertTrue(source.contains(".lineLimit(1)"))
    }

    func testMacFocusTimerStatusFreezesPausedTaskTimer() {
        let status = RoutinaMacFocusTimerStatus(
            id: UUID(),
            targetID: UUID(),
            kind: .task,
            title: "Deep work",
            startedAt: Date(timeIntervalSince1970: 0),
            plannedDurationSeconds: 0,
            pausedAt: Date(timeIntervalSince1970: 10 * 60),
            accumulatedPausedSeconds: 0
        )

        XCTAssertEqual(status.menuBarTimeText(at: Date(timeIntervalSince1970: 30 * 60)), "10:00")
        XCTAssertEqual(status.menuBarModeText(at: Date(timeIntervalSince1970: 30 * 60)), "paused")
        XCTAssertEqual(status.systemImage, "pause.circle.fill")
    }

    func testStatsChartsOnlyUseNestedScrollingWhenChartNeedsOverflow() {
        XCTAssertFalse(
            StatsChartPresentation(selectedRange: .today, isCompact: false).usesHorizontalChartScroll
        )
        XCTAssertFalse(
            StatsChartPresentation(selectedRange: .week, isCompact: false).usesHorizontalChartScroll
        )
        XCTAssertFalse(
            StatsChartPresentation(selectedRange: .month, isCompact: false).usesHorizontalChartScroll
        )
        XCTAssertTrue(
            StatsChartPresentation(selectedRange: .month, isCompact: true).usesHorizontalChartScroll
        )
        XCTAssertTrue(
            StatsChartPresentation(selectedRange: .year, isCompact: false).usesHorizontalChartScroll
        )
    }

    func testStatsDerivedStateLargeDatasetPerformance() {
        let referenceDate = Self.referenceDate
        let calendar = Self.calendar
        let fixture = Self.makeStatsFixture(
            taskCount: 2_400,
            logCount: 18_000,
            focusSessionCount: 2_400,
            referenceDate: referenceDate
        )

        let baseline = Self.makeStatsDerivedState(
            fixture: fixture,
            referenceDate: referenceDate,
            calendar: calendar
        )
        XCTAssertGreaterThan(baseline.filteredTaskCount, 0)
        XCTAssertGreaterThan(baseline.metrics.chartPoints.count, 100)
        XCTAssertLessThanOrEqual(baseline.metrics.chartPoints.count, DoneChartRange.year.trailingDayCount)
        XCTAssertEqual(baseline.metrics.createdChartPoints.count, baseline.metrics.chartPoints.count)
        XCTAssertFalse(baseline.metrics.tagUsagePoints.isEmpty)
        XCTAssertFalse(baseline.tagSummaries.isEmpty)
        XCTAssertFalse(baseline.availableExcludeTags.contains("Focus"))
        XCTAssertGreaterThan(baseline.taskCountForSelectedTypeFilter, baseline.filteredTaskCount)

        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(
            metrics: [
                XCTClockMetric(),
                XCTCPUMetric(),
                XCTMemoryMetric(),
            ],
            options: options
        ) {
            _ = Self.makeStatsDerivedState(
                fixture: fixture,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }
    }

    func testStatsDerivedStatePrecomputesSidebarTagData() {
        let referenceDate = Self.referenceDate
        let calendar = Self.calendar
        let focusRoutine = RoutineTask(
            name: "Focus Routine",
            tags: ["Focus", "Deep"],
            scheduleMode: .fixedInterval,
            lastDone: referenceDate.addingTimeInterval(-86_400),
            createdAt: referenceDate.addingTimeInterval(-172_800)
        )
        let blockedTodo = RoutineTask(
            name: "Blocked Todo",
            tags: ["Focus", "Blocked"],
            scheduleMode: .oneOff,
            lastDone: nil,
            createdAt: referenceDate.addingTimeInterval(-86_400),
            todoStateRawValue: TodoState.blocked.rawValue
        )
        let healthRoutine = RoutineTask(
            name: "Health Routine",
            tags: ["Health"],
            scheduleMode: .fixedInterval,
            lastDone: nil,
            createdAt: referenceDate.addingTimeInterval(-43_200)
        )
        let state = StatsFeatureDerivedStateBuilder.build(
            tasks: [focusRoutine, blockedTodo, healthRoutine],
            logs: [
                RoutineLog(timestamp: referenceDate, taskID: focusRoutine.id, kind: .completed),
                RoutineLog(timestamp: referenceDate, taskID: blockedTodo.id, kind: .completed),
            ],
            focusSessions: [],
            selectedRange: .week,
            taskTypeFilter: .all,
            createdChartTaskTypeFilter: .all,
            selectedImportanceUrgencyFilter: nil,
            advancedQuery: "",
            selectedTags: ["Focus"],
            includeTagMatchMode: .all,
            excludedTags: ["Blocked"],
            excludeTagMatchMode: .any,
            tagColors: ["focus": "#112233"],
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(state.taskCountForSelectedTypeFilter, 3)
        XCTAssertEqual(state.filteredTaskCount, 1)
        XCTAssertEqual(state.availableExcludeTags, ["Blocked", "Deep"])
        XCTAssertEqual(
            state.tagSummaries.map(\.name),
            ["Blocked", "Deep", "Focus", "Health"]
        )
        XCTAssertEqual(
            state.tagSummaries.first { $0.name == "Focus" }?.colorHex,
            "#112233"
        )
    }

    func testTimelineGroupingLargeDatasetPerformance() {
        let referenceDate = Self.referenceDate
        let calendar = Self.calendar
        let fixture = Self.makeTimelineFixture(
            taskCount: 1_800,
            logCount: 16_000,
            referenceDate: referenceDate
        )

        let baseline = Self.makeTimelineSections(
            fixture: fixture,
            referenceDate: referenceDate,
            calendar: calendar
        )
        XCTAssertGreaterThanOrEqual(baseline.count, 28)
        XCTAssertFalse(baseline.first?.entries.isEmpty ?? true)

        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(
            metrics: [
                XCTClockMetric(),
                XCTCPUMetric(),
                XCTMemoryMetric(),
            ],
            options: options
        ) {
            _ = Self.makeTimelineSections(
                fixture: fixture,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }
    }
}

private extension PerformanceRegressionTests {
    struct StatsFixture {
        var tasks: [RoutineTask]
        var logs: [RoutineLog]
        var focusSessions: [FocusSession]
    }

    struct TimelineFixture {
        var tasks: [RoutineTask]
        var logs: [RoutineLog]
    }

    static var referenceDate: Date {
        Date(timeIntervalSince1970: 1_774_007_200)
    }

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    static func sourceFile(_ relativePath: String) throws -> String {
        try SourceInspectionSupport.readProjectFile(relativePath)
    }

    static func homeMacToolbarSource() throws -> String {
        try [
            "RoutinaMacApp/Screens/Home/Components/HomeMacHomeToolbarContent.swift",
            "RoutinaMacApp/Screens/Home/Components/HomeMacToolbarSearchField.swift",
            "RoutinaMacApp/Screens/Home/Components/HomeMacToolbarQuickAddPreview.swift",
            "RoutinaMacApp/Screens/Home/Components/HomeMacToolbarSearchInteractionSupport.swift",
            "RoutinaMacApp/Screens/Home/Components/HomeMacToolbarSearchTextField.swift",
        ]
        .map(sourceFile)
        .joined(separator: "\n")
    }

    static func projectBlock(
        named targetName: String,
        in source: String,
        endingBefore nextTargetName: String
    ) throws -> String {
        guard
            let start = source.range(of: "/* \(targetName) */ = {"),
            let end = source.range(
                of: "/* \(nextTargetName) */ = {",
                range: start.upperBound..<source.endIndex
            )
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return String(source[start.lowerBound..<end.lowerBound])
    }

    static func makeStatsDerivedState(
        fixture: StatsFixture,
        referenceDate: Date,
        calendar: Calendar
    ) -> StatsFeatureDerivedState {
        StatsFeatureDerivedStateBuilder.build(
            tasks: fixture.tasks,
            logs: fixture.logs,
            focusSessions: fixture.focusSessions,
            selectedRange: .year,
            taskTypeFilter: .all,
            createdChartTaskTypeFilter: .all,
            selectedImportanceUrgencyFilter: nil,
            advancedQuery: "",
            selectedTags: ["Focus"],
            includeTagMatchMode: .all,
            excludedTags: ["Blocked"],
            excludeTagMatchMode: .any,
            tagColors: [:],
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    static func makeTimelineSections(
        fixture: TimelineFixture,
        referenceDate: Date,
        calendar: Calendar
    ) -> [(date: Date, entries: [TimelineEntry])] {
        let entries = TimelineLogic.filteredEntries(
            logs: fixture.logs,
            tasks: fixture.tasks,
            range: .month,
            filterType: .all,
            now: referenceDate,
            calendar: calendar
        )
        return TimelineLogic.groupedByDay(entries: entries, calendar: calendar)
    }

    static func makeStatsFixture(
        taskCount: Int,
        logCount: Int,
        focusSessionCount: Int,
        referenceDate: Date
    ) -> StatsFixture {
        let tasks = makeTasks(count: taskCount, referenceDate: referenceDate)
        let logs = makeLogs(count: logCount, tasks: tasks, referenceDate: referenceDate)
        let focusSessions = makeFocusSessions(
            count: focusSessionCount,
            tasks: tasks,
            referenceDate: referenceDate
        )
        return StatsFixture(tasks: tasks, logs: logs, focusSessions: focusSessions)
    }

    static func makeTimelineFixture(
        taskCount: Int,
        logCount: Int,
        referenceDate: Date
    ) -> TimelineFixture {
        let tasks = makeTasks(count: taskCount, referenceDate: referenceDate)
        let logs = makeLogs(count: logCount, tasks: tasks, referenceDate: referenceDate)
        return TimelineFixture(tasks: tasks, logs: logs)
    }

    static func makeTasks(count: Int, referenceDate: Date) -> [RoutineTask] {
        (0..<count).map { index in
            let isTodo = index.isMultiple(of: 4)
            return RoutineTask(
                name: "Perf Task \(index)",
                emoji: isTodo ? "square.and.pencil" : "checklist",
                notes: "Synthetic performance fixture task \(index)",
                priority: priority(for: index),
                importance: importance(for: index),
                urgency: urgency(for: index),
                tags: tags(for: index),
                scheduleMode: isTodo ? .oneOff : .fixedInterval,
                interval: Int16((index % 14) + 1),
                lastDone: referenceDate.addingTimeInterval(TimeInterval(-86_400 * (index % 60))),
                pausedAt: index.isMultiple(of: 11) ? referenceDate : nil,
                pinnedAt: index.isMultiple(of: 9) ? referenceDate.addingTimeInterval(TimeInterval(-index)) : nil,
                createdAt: referenceDate.addingTimeInterval(TimeInterval(-43_200 * (index % 365))),
                todoStateRawValue: isTodo ? todoState(for: index).rawValue : nil,
                estimatedDurationMinutes: 15 + (index % 8) * 5,
                storyPoints: (index % 13) + 1
            )
        }
    }

    static func makeLogs(count: Int, tasks: [RoutineTask], referenceDate: Date) -> [RoutineLog] {
        (0..<count).map { index in
            let task = tasks[index % tasks.count]
            let secondsAgo = TimeInterval(900 * index)
            return RoutineLog(
                timestamp: referenceDate.addingTimeInterval(-secondsAgo),
                taskID: task.id,
                kind: index.isMultiple(of: 9) ? .canceled : .completed,
                actualDurationMinutes: 10 + (index % 8) * 5
            )
        }
    }

    static func makeFocusSessions(
        count: Int,
        tasks: [RoutineTask],
        referenceDate: Date
    ) -> [FocusSession] {
        (0..<count).map { index in
            let task = tasks[index % tasks.count]
            let startedAt = referenceDate.addingTimeInterval(TimeInterval(-1_800 * index))
            return FocusSession(
                taskID: task.id,
                startedAt: startedAt,
                plannedDurationSeconds: 25 * 60,
                completedAt: startedAt.addingTimeInterval(TimeInterval(600 + (index % 6) * 300))
            )
        }
    }

    static func tags(for index: Int) -> [String] {
        let primary = ["Focus", "Health", "Admin", "Learning", "Planning", "Writing"]
        let secondary = ["Morning", "Evening", "Review", "Deep Work", "Quick"]
        var tags = [
            primary[index % primary.count],
            secondary[(index / 3) % secondary.count],
        ]
        if index.isMultiple(of: 10) {
            tags.append("Blocked")
        }
        return tags
    }

    static func priority(for index: Int) -> RoutineTaskPriority {
        RoutineTaskPriority.allCases[index % RoutineTaskPriority.allCases.count]
    }

    static func importance(for index: Int) -> RoutineTaskImportance {
        RoutineTaskImportance.allCases[index % RoutineTaskImportance.allCases.count]
    }

    static func urgency(for index: Int) -> RoutineTaskUrgency {
        RoutineTaskUrgency.allCases[index % RoutineTaskUrgency.allCases.count]
    }

    static func todoState(for index: Int) -> TodoState {
        switch index % 4 {
        case 0:
            return .ready
        case 1:
            return .inProgress
        case 2:
            return .blocked
        default:
            return .paused
        }
    }
}
