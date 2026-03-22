import CloudKit
import ComposableArchitecture
import SwiftData
import SwiftUI
import UserNotifications

@Reducer
struct SettingsFeature {

    @ObservableState
    struct State: Equatable {
        var appVersion: String = ""
        var dataModeDescription: String = AppEnvironment.dataModeLabel
        var iCloudContainerDescription: String = AppEnvironment.cloudKitContainerIdentifier ?? "Disabled"
        var cloudDiagnosticsSummary: String = CloudKitSyncDiagnostics.snapshot().summary
        var cloudDiagnosticsTimestamp: String = CloudKitSyncDiagnostics.snapshot().timestampText
        var pushDiagnosticsStatus: String = CloudKitSyncDiagnostics.snapshot().pushStatus
        var isDebugSectionVisible: Bool = false
        var cloudSyncAvailable: Bool = AppEnvironment.isCloudSyncEnabled
        var notificationsEnabled: Bool = SharedDefaults.app[.appSettingNotificationsEnabled]
        var systemSettingsNotificationsEnabled: Bool = true
        var notificationReminderTime: Date = NotificationPreferences.reminderTimeDate()
        var isCloudSyncInProgress: Bool = false
        var isCloudDataResetInProgress: Bool = false
        var isCloudDataResetConfirmationPresented: Bool = false
        var isDeletePlaceConfirmationPresented: Bool = false
        var cloudStatusMessage: String = ""
        var isDataTransferInProgress: Bool = false
        var dataTransferStatusMessage: String = ""
        var appIconStatusMessage: String = ""
        var selectedAppIcon: AppIconOption = .persistedSelection
        var savedPlaces: [RoutinePlaceSummary] = []
        var savedTags: [RoutineTagSummary] = []
        var placePendingDeletion: RoutinePlaceSummary?
        var tagPendingDeletion: RoutineTagSummary?
        var tagPendingRename: RoutineTagSummary?
        var placeDraftName: String = ""
        var tagRenameDraft: String = ""
        var placeDraftCoordinate: LocationCoordinate?
        var placeDraftRadiusMeters: Double = 150
        var placeStatusMessage: String = ""
        var tagStatusMessage: String = ""
        var isPlaceOperationInProgress: Bool = false
        var isTagOperationInProgress: Bool = false
        var locationAuthorizationStatus: LocationAuthorizationStatus = .notDetermined
        var lastKnownLocationCoordinate: LocationCoordinate?
        var isDeleteTagConfirmationPresented: Bool = false
        var isTagRenameSheetPresented: Bool = false
    }

    enum Action: Equatable {
        case toggleNotifications(Bool)
        case notificationAuthorizationFinished(Bool)
        case notificationReminderTimeChanged(Date)
        case openAppSettingsTapped
        case onAppear
        case tagManagerAppeared
        case onAppBecameActive
        case contactUsTapped
        case aboutSectionLongPressed
        case systemNotificationPermissionChecked(Bool)
        case cloudDiagnosticsUpdated
        case syncNowTapped
        case setCloudDataResetConfirmation(Bool)
        case resetCloudDataConfirmed
        case setDeletePlaceConfirmation(Bool)
        case setDeleteTagConfirmation(Bool)
        case setTagRenameSheet(Bool)
        case placesLoaded([RoutinePlaceSummary])
        case tagsLoaded([RoutineTagSummary])
        case locationSnapshotUpdated(LocationSnapshot)
        case placeDraftNameChanged(String)
        case tagRenameDraftChanged(String)
        case placeDraftCoordinateChanged(LocationCoordinate?)
        case placeDraftRadiusChanged(Double)
        case savePlaceTapped
        case renameTagTapped(String)
        case saveTagRenameTapped
        case deletePlaceTapped(UUID)
        case deleteTagTapped(String)
        case deletePlaceConfirmed
        case deleteTagConfirmed
        case placeOperationFinished(success: Bool, message: String)
        case tagOperationFinished(success: Bool, message: String)
        case exportRoutineDataTapped
        case importRoutineDataTapped
        case appIconSelected(AppIconOption)
        case appIconChangeFinished(requestedOption: AppIconOption, errorMessage: String?)
        case routineDataTransferFinished(success: Bool, message: String)
        case cloudSyncFinished(success: Bool, message: String)
        case cloudDataResetFinished(success: Bool, message: String)
    }

    @Dependency(\.modelContext) var modelContext
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.appIconClient) var appIconClient
    @Dependency(\.locationClient) var locationClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .toggleNotifications(let isOn):
                guard isOn else {
                    state.notificationsEnabled = false
                    SharedDefaults.app[.appSettingNotificationsEnabled] = false
                    return .run { _ in
                        await self.notificationClient.cancelAll()
                    }
                }

                return .run { send in
                    let granted = await self.notificationClient.requestAuthorizationIfNeeded()
                    await send(.notificationAuthorizationFinished(granted))
                }

            case .notificationAuthorizationFinished(let isGranted):
                state.notificationsEnabled = isGranted
                state.systemSettingsNotificationsEnabled = isGranted
                SharedDefaults.app[.appSettingNotificationsEnabled] = isGranted

                guard isGranted else { return .none }
                return .run { @MainActor _ in
                    try? await self.rescheduleNotificationsIfNeeded(in: self.modelContext())
                }

            case .notificationReminderTimeChanged(let reminderTime):
                state.notificationReminderTime = reminderTime
                NotificationPreferences.storeReminderTime(reminderTime)

                guard state.notificationsEnabled else { return .none }
                return .run { @MainActor _ in
                    try? await self.rescheduleNotificationsIfNeeded(in: self.modelContext())
                }

            case .openAppSettingsTapped:
                if let url = PlatformSupport.notificationSettingsURL {
                    return .run { @MainActor _ in
                        PlatformSupport.open(url)
                    }
                }
                return .none

            case .onAppear:
                state.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
                state.isDebugSectionVisible = false
                state.notificationReminderTime = NotificationPreferences.reminderTimeDate()
                state.selectedAppIcon = .persistedSelection
                state.appIconStatusMessage = ""
                let diagnostics = CloudKitSyncDiagnostics.snapshot()
                state.cloudDiagnosticsSummary = diagnostics.summary
                state.cloudDiagnosticsTimestamp = diagnostics.timestampText
                state.pushDiagnosticsStatus = diagnostics.pushStatus
                return .run { @MainActor send in
                    let context = self.modelContext()
                    let settings = await UNUserNotificationCenter.current().notificationSettings()
                    let systemEnabled = self.isSystemNotificationAuthorizationEnabled(settings.authorizationStatus)
                    send(.systemNotificationPermissionChecked(systemEnabled))
                    let placeSummaries = try? self.fetchPlaceSummaries(in: context)
                    send(.placesLoaded(placeSummaries ?? []))
                    let tagSummaries = try? self.fetchTagSummaries(in: context)
                    send(.tagsLoaded(tagSummaries ?? []))
                    let locationSnapshot = await self.locationClient.snapshot(false)
                    send(.locationSnapshotUpdated(locationSnapshot))
                }

            case .tagManagerAppeared:
                return .run { @MainActor send in
                    let tagSummaries = try? self.fetchTagSummaries(in: self.modelContext())
                    send(.tagsLoaded(tagSummaries ?? []))
                }

            case .contactUsTapped:
                if let emailURL = URL(string: "mailto:h.qadirian@gmail.com") {
                    return .run { @MainActor _ in
                        PlatformSupport.open(emailURL)
                    }
                }
                return .none

            case .aboutSectionLongPressed:
                state.isDebugSectionVisible = true
                return .none

            case let .systemNotificationPermissionChecked(value):
                state.systemSettingsNotificationsEnabled = value
                return .none

            case .cloudDiagnosticsUpdated:
                let diagnostics = CloudKitSyncDiagnostics.snapshot()
                state.cloudDiagnosticsSummary = diagnostics.summary
                state.cloudDiagnosticsTimestamp = diagnostics.timestampText
                state.pushDiagnosticsStatus = diagnostics.pushStatus
                return .none

            case .onAppBecameActive:
                let notificationsEnabled = state.notificationsEnabled
                return .run { @MainActor send in
                    let context = self.modelContext()
                    let settings = await UNUserNotificationCenter.current().notificationSettings()
                    let systemEnabled = self.isSystemNotificationAuthorizationEnabled(settings.authorizationStatus)
                    send(.systemNotificationPermissionChecked(systemEnabled))
                    let placeSummaries = try? self.fetchPlaceSummaries(in: context)
                    send(.placesLoaded(placeSummaries ?? []))
                    let tagSummaries = try? self.fetchTagSummaries(in: context)
                    send(.tagsLoaded(tagSummaries ?? []))
                    let locationSnapshot = await self.locationClient.snapshot(false)
                    send(.locationSnapshotUpdated(locationSnapshot))
                    if notificationsEnabled {
                        if systemEnabled {
                            try? await self.rescheduleNotificationsIfNeeded(in: context)
                        } else {
                            await self.notificationClient.cancelAll()
                        }
                    }
                }

            case .syncNowTapped:
                guard !state.isCloudDataResetInProgress else {
                    return .none
                }
                guard state.cloudSyncAvailable else {
                    state.cloudStatusMessage = "iCloud sync is disabled in this build."
                    return .none
                }

                state.isCloudSyncInProgress = true
                state.cloudStatusMessage = "Syncing with iCloud..."
                return .run { @MainActor send in
                    do {
                        let context = modelContext()
                        if context.hasChanges {
                            try context.save()
                        }
                        if let containerIdentifier = AppEnvironment.cloudKitContainerIdentifier {
                            try await CloudKitDirectPullService.pullLatestIntoLocalStore(
                                containerIdentifier: containerIdentifier,
                                modelContext: context
                            )
                        }
                        NotificationCenter.default.postRoutineDidUpdate()
                        await send(
                            .cloudSyncFinished(
                                success: true,
                                message: "Sync completed."
                            )
                        )
                    } catch {
                        await send(
                            .cloudSyncFinished(
                                success: false,
                                message: "Sync failed: \(error.localizedDescription)"
                            )
                        )
                    }
                }

            case let .setCloudDataResetConfirmation(isPresented):
                state.isCloudDataResetConfirmationPresented = isPresented
                return .none

            case .resetCloudDataConfirmed:
                state.isCloudDataResetConfirmationPresented = false

                guard !state.isCloudSyncInProgress,
                      !state.isCloudDataResetInProgress
                else {
                    return .none
                }

                guard state.cloudSyncAvailable,
                      let cloudContainerIdentifier = AppEnvironment.cloudKitContainerIdentifier
                else {
                    state.cloudStatusMessage = "iCloud sync is disabled in this build."
                    return .none
                }

                state.isCloudDataResetInProgress = true
                state.cloudStatusMessage = "Deleting iCloud data..."
                return .run { @MainActor send in
                    do {
                        try await CloudDataResetService.resetAllUserData(
                            cloudKitContainerIdentifier: cloudContainerIdentifier,
                            modelContext: modelContext()
                        )
                        NotificationCenter.default.postRoutineDidUpdate()
                        await send(
                            .cloudDataResetFinished(
                                success: true,
                                message: "All Routina data was deleted from iCloud and this device."
                            )
                        )
                    } catch {
                        await send(
                            .cloudDataResetFinished(
                                success: false,
                                message: cloudDataResetErrorMessage(for: error)
                            )
                        )
                    }
                }

            case let .setDeletePlaceConfirmation(isPresented):
                state.isDeletePlaceConfirmationPresented = isPresented
                if !isPresented {
                    state.placePendingDeletion = nil
                }
                return .none

            case let .setDeleteTagConfirmation(isPresented):
                state.isDeleteTagConfirmationPresented = isPresented
                if !isPresented {
                    state.tagPendingDeletion = nil
                }
                return .none

            case let .setTagRenameSheet(isPresented):
                state.isTagRenameSheetPresented = isPresented
                if !isPresented {
                    state.tagPendingRename = nil
                    state.tagRenameDraft = ""
                }
                return .none

            case let .placesLoaded(places):
                state.savedPlaces = places
                if let pendingPlace = state.placePendingDeletion,
                   let updatedPlace = places.first(where: { $0.id == pendingPlace.id }) {
                    state.placePendingDeletion = updatedPlace
                }
                return .none

            case let .tagsLoaded(tags):
                state.savedTags = tags
                if let pendingTag = state.tagPendingDeletion,
                   let updatedTag = self.tagSummary(named: pendingTag.name, in: tags) {
                    state.tagPendingDeletion = updatedTag
                }
                if let pendingTag = state.tagPendingRename,
                   let updatedTag = self.tagSummary(named: pendingTag.name, in: tags) {
                    state.tagPendingRename = updatedTag
                }
                return .none

            case let .locationSnapshotUpdated(snapshot):
                state.locationAuthorizationStatus = snapshot.authorizationStatus
                if let coordinate = snapshot.coordinate {
                    state.lastKnownLocationCoordinate = coordinate
                }
                return .none

            case let .placeDraftNameChanged(name):
                state.placeDraftName = name
                state.placeStatusMessage = ""
                return .none

            case let .tagRenameDraftChanged(name):
                state.tagRenameDraft = name
                state.tagStatusMessage = ""
                return .none

            case let .placeDraftCoordinateChanged(coordinate):
                state.placeDraftCoordinate = coordinate
                state.placeStatusMessage = ""
                return .none

            case let .placeDraftRadiusChanged(radius):
                state.placeDraftRadiusMeters = min(max(radius, 25), 2_000)
                state.placeStatusMessage = ""
                return .none

            case let .renameTagTapped(tagName):
                guard !state.isTagOperationInProgress,
                      let tag = self.tagSummary(named: tagName, in: state.savedTags)
                else {
                    return .none
                }

                state.tagPendingRename = tag
                state.tagRenameDraft = tag.name
                state.tagStatusMessage = ""
                state.isTagRenameSheetPresented = true
                return .none

            case .savePlaceTapped:
                let cleanedName = RoutinePlace.cleanedName(state.placeDraftName)
                guard let cleanedName else {
                    state.placeStatusMessage = "Enter a place name first."
                    return .none
                }
                guard let coordinate = state.placeDraftCoordinate else {
                    state.placeStatusMessage = "Choose a location on the map first."
                    return .none
                }
                guard !state.isPlaceOperationInProgress else {
                    return .none
                }

                state.isPlaceOperationInProgress = true
                state.placeStatusMessage = ""
                let radiusMeters = state.placeDraftRadiusMeters

                return .run { @MainActor send in
                    do {
                        let context = self.modelContext()
                        if try self.hasDuplicatePlaceName(cleanedName, in: context) {
                            send(
                                .placeOperationFinished(
                                    success: false,
                                    message: "A place with this name already exists."
                                )
                            )
                            return
                        }

                        context.insert(
                            RoutinePlace(
                                name: cleanedName,
                                latitude: coordinate.latitude,
                                longitude: coordinate.longitude,
                                radiusMeters: radiusMeters
                            )
                        )
                        try context.save()
                        NotificationCenter.default.postRoutineDidUpdate()
                        let summaries = try self.fetchPlaceSummaries(in: context)
                        send(.placesLoaded(summaries))
                        send(
                            .placeOperationFinished(
                                success: true,
                                message: "Saved \(cleanedName)."
                            )
                        )
                    } catch {
                        send(
                            .placeOperationFinished(
                                success: false,
                                message: "Saving place failed: \(error.localizedDescription)"
                            )
                        )
                    }
                }

            case .saveTagRenameTapped:
                guard !state.isTagOperationInProgress else {
                    return .none
                }
                guard let pendingTag = state.tagPendingRename else {
                    return .none
                }
                guard let cleanedName = RoutineTag.cleaned(state.tagRenameDraft) else {
                    state.tagStatusMessage = "Enter a tag name first."
                    return .none
                }

                state.isTagRenameSheetPresented = false
                state.tagPendingRename = nil
                state.tagRenameDraft = ""
                state.isTagOperationInProgress = true
                state.tagStatusMessage = ""
                let originalTagName = pendingTag.name

                return .run { @MainActor send in
                    do {
                        let context = self.modelContext()
                        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
                        var updatedRoutineCount = 0

                        for task in tasks where RoutineTag.contains(originalTagName, in: task.tags) {
                            let updatedTags = RoutineTag.replacing(
                                originalTagName,
                                with: cleanedName,
                                in: task.tags
                            )
                            if updatedTags != task.tags {
                                task.tags = updatedTags
                                updatedRoutineCount += 1
                            }
                        }

                        try context.save()
                        NotificationCenter.default.postRoutineDidUpdate()
                        NotificationCenter.default.postRoutineTagDidRename(from: originalTagName, to: cleanedName)
                        let summaries = try self.fetchTagSummaries(in: context)
                        send(.tagsLoaded(summaries))
                        send(
                            .tagOperationFinished(
                                success: true,
                                message: self.renameTagSuccessMessage(
                                    updatedTagName: cleanedName,
                                    updatedRoutineCount: updatedRoutineCount
                                )
                            )
                        )
                    } catch {
                        send(
                            .tagOperationFinished(
                                success: false,
                                message: "Updating tag failed: \(error.localizedDescription)"
                            )
                        )
                    }
                }

            case let .deletePlaceTapped(placeID):
                guard !state.isPlaceOperationInProgress else {
                    return .none
                }

                guard let place = state.savedPlaces.first(where: { $0.id == placeID }) else {
                    return .none
                }

                state.placePendingDeletion = place
                state.isDeletePlaceConfirmationPresented = true
                return .none

            case let .deleteTagTapped(tagName):
                guard !state.isTagOperationInProgress,
                      let tag = self.tagSummary(named: tagName, in: state.savedTags)
                else {
                    return .none
                }

                state.tagPendingDeletion = tag
                state.tagStatusMessage = ""
                state.isDeleteTagConfirmationPresented = true
                return .none

            case .deletePlaceConfirmed:
                guard !state.isPlaceOperationInProgress else {
                    return .none
                }
                guard let pendingPlace = state.placePendingDeletion else {
                    return .none
                }

                state.isDeletePlaceConfirmationPresented = false
                state.placePendingDeletion = nil
                state.isPlaceOperationInProgress = true
                state.placeStatusMessage = ""
                let placeID = pendingPlace.id

                return .run { @MainActor send in
                    do {
                        let context = self.modelContext()
                        let placeDescriptor = FetchDescriptor<RoutinePlace>(
                            predicate: #Predicate { place in
                                place.id == placeID
                            }
                        )

                        if let place = try context.fetch(placeDescriptor).first {
                            context.delete(place)
                        }

                        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
                        for task in tasks where task.placeID == placeID {
                            task.placeID = nil
                        }

                        try context.save()
                        NotificationCenter.default.postRoutineDidUpdate()
                        let summaries = try self.fetchPlaceSummaries(in: context)
                        send(.placesLoaded(summaries))
                        send(.placeOperationFinished(success: true, message: "Place deleted."))
                    } catch {
                        send(
                            .placeOperationFinished(
                                success: false,
                                message: "Deleting place failed: \(error.localizedDescription)"
                            )
                        )
                    }
                }

            case .deleteTagConfirmed:
                guard !state.isTagOperationInProgress else {
                    return .none
                }
                guard let pendingTag = state.tagPendingDeletion else {
                    return .none
                }

                state.isDeleteTagConfirmationPresented = false
                state.tagPendingDeletion = nil
                state.isTagOperationInProgress = true
                state.tagStatusMessage = ""
                let tagName = pendingTag.name

                return .run { @MainActor send in
                    do {
                        let context = self.modelContext()
                        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
                        var updatedRoutineCount = 0

                        for task in tasks where RoutineTag.contains(tagName, in: task.tags) {
                            let updatedTags = RoutineTag.removing(tagName, from: task.tags)
                            if updatedTags != task.tags {
                                task.tags = updatedTags
                                updatedRoutineCount += 1
                            }
                        }

                        try context.save()
                        NotificationCenter.default.postRoutineDidUpdate()
                        NotificationCenter.default.postRoutineTagDidDelete(tagName)
                        let summaries = try self.fetchTagSummaries(in: context)
                        send(.tagsLoaded(summaries))
                        send(
                            .tagOperationFinished(
                                success: true,
                                message: self.deleteTagSuccessMessage(
                                    deletedTagName: tagName,
                                    updatedRoutineCount: updatedRoutineCount
                                )
                            )
                        )
                    } catch {
                        send(
                            .tagOperationFinished(
                                success: false,
                                message: "Deleting tag failed: \(error.localizedDescription)"
                            )
                        )
                    }
                }

            case let .placeOperationFinished(success, message):
                state.isPlaceOperationInProgress = false
                state.placeStatusMessage = message
                if success {
                    state.placeDraftName = ""
                    state.placeDraftCoordinate = nil
                }
                return .none

            case let .tagOperationFinished(_, message):
                state.isTagOperationInProgress = false
                state.tagStatusMessage = message
                return .none

            case .exportRoutineDataTapped:
#if os(macOS)
                guard !state.isDataTransferInProgress else {
                    return .none
                }

                state.isDataTransferInProgress = true
                state.dataTransferStatusMessage = "Saving routine data..."
                return .run { @MainActor send in
                    do {
                        guard let destinationURL = await PlatformSupport.selectRoutineDataExportURL(
                            suggestedFileName: defaultRoutineDataBackupFileName()
                        ) else {
                            await send(
                                .routineDataTransferFinished(
                                    success: false,
                                    message: "Save canceled."
                                )
                            )
                            return
                        }

                        let context = modelContext()
                        if context.hasChanges {
                            try context.save()
                        }

                        let backupData = try buildRoutineDataBackupJSON(from: context)
                        try withSecurityScopedAccess(to: destinationURL) {
                            try backupData.write(to: destinationURL, options: .atomic)
                        }

                        await send(
                            .routineDataTransferFinished(
                                success: true,
                                message: "Saved to \(destinationURL.lastPathComponent)."
                            )
                        )
                    } catch {
                        await send(
                            .routineDataTransferFinished(
                                success: false,
                                message: "Save failed: \(error.localizedDescription)"
                            )
                        )
                    }
                }
#else
                return .none
#endif

            case .importRoutineDataTapped:
#if os(macOS)
                guard !state.isDataTransferInProgress else {
                    return .none
                }

                state.isDataTransferInProgress = true
                state.dataTransferStatusMessage = "Loading routine data..."
                return .run { @MainActor send in
                    do {
                        guard let sourceURL = await PlatformSupport.selectRoutineDataImportURL() else {
                            await send(
                                .routineDataTransferFinished(
                                    success: false,
                                    message: "Load canceled."
                                )
                            )
                            return
                        }

                        let jsonData = try withSecurityScopedAccess(to: sourceURL) {
                            try Data(contentsOf: sourceURL)
                        }
                        let context = modelContext()
                        let importedSummary = try replaceAllRoutineData(with: jsonData, in: context)
                        try await rescheduleNotificationsAfterImport(in: context)

                        NotificationCenter.default.postRoutineDidUpdate()
                        await send(
                            .routineDataTransferFinished(
                                success: true,
                                message: "Loaded \(importedSummary.tasks) routines, \(importedSummary.places) places, and \(importedSummary.logs) logs."
                            )
                        )
                    } catch {
                        await send(
                            .routineDataTransferFinished(
                                success: false,
                                message: "Load failed: \(error.localizedDescription)"
                            )
                        )
                    }
                }
#else
                return .none
#endif

            case let .appIconSelected(option):
                state.appIconStatusMessage = ""
                return .run { send in
                    let errorMessage = await self.appIconClient.requestChange(option)
                    await send(.appIconChangeFinished(requestedOption: option, errorMessage: errorMessage))
                }

            case let .appIconChangeFinished(option, errorMessage):
                if let errorMessage {
                    state.appIconStatusMessage = "App icon update failed: \(errorMessage)"
                } else {
                    state.selectedAppIcon = option
                    AppIconOption.persist(option)
                }
                return .none

            case let .routineDataTransferFinished(_, message):
                state.isDataTransferInProgress = false
                state.dataTransferStatusMessage = message
                return .none

            case let .cloudSyncFinished(_, message):
                state.isCloudSyncInProgress = false
                state.cloudStatusMessage = message
                return .none

            case let .cloudDataResetFinished(_, message):
                state.isCloudDataResetInProgress = false
                state.cloudStatusMessage = message
                return .none
            }
        }
    }

    private func cloudDataResetErrorMessage(for error: Error) -> String {
        guard let cloudError = error as? CKError else {
            return "Data reset failed: \(error.localizedDescription)"
        }

        switch cloudError.code {
        case .notAuthenticated:
            return "Please sign in to iCloud and try again."
        case .networkUnavailable, .networkFailure:
            return "Network issue while deleting iCloud data. Please try again."
        case .serviceUnavailable, .requestRateLimited:
            return "iCloud is temporarily unavailable. Please try again shortly."
        default:
            return "Data reset failed: \(cloudError.localizedDescription)"
        }
    }

    @MainActor
    private func fetchPlaceSummaries(in context: ModelContext) throws -> [RoutinePlaceSummary] {
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        return RoutinePlace.summaries(from: places, linkedTo: tasks)
    }

    @MainActor
    private func fetchTagSummaries(in context: ModelContext) throws -> [RoutineTagSummary] {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        return RoutineTag.summaries(from: tasks)
    }

    private func hasDuplicatePlaceName(_ name: String, in context: ModelContext) throws -> Bool {
        guard let normalizedName = RoutinePlace.normalizedName(name) else { return false }
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        return places.contains { place in
            RoutinePlace.normalizedName(place.name) == normalizedName
        }
    }

    private func tagSummary(named name: String, in tags: [RoutineTagSummary]) -> RoutineTagSummary? {
        guard let normalizedTagName = RoutineTag.normalized(name) else { return nil }
        return tags.first { RoutineTag.normalized($0.name) == normalizedTagName }
    }

    private func renameTagSuccessMessage(updatedTagName: String, updatedRoutineCount: Int) -> String {
        switch updatedRoutineCount {
        case ..<1:
            return "Updated tag to \(updatedTagName)."
        case 1:
            return "Updated tag to \(updatedTagName) in 1 routine."
        default:
            return "Updated tag to \(updatedTagName) in \(updatedRoutineCount) routines."
        }
    }

    private func deleteTagSuccessMessage(deletedTagName: String, updatedRoutineCount: Int) -> String {
        switch updatedRoutineCount {
        case ..<1:
            return "Deleted \(deletedTagName)."
        case 1:
            return "Deleted \(deletedTagName) from 1 routine."
        default:
            return "Deleted \(deletedTagName) from \(updatedRoutineCount) routines."
        }
    }

    private struct RoutineDataBackup: Codable {
        var schemaVersion: Int
        var exportedAt: Date
        var places: [Place]?
        var tasks: [Task]
        var logs: [Log]

        struct Place: Codable {
            var id: UUID
            var name: String
            var latitude: Double
            var longitude: Double
            var radiusMeters: Double
            var createdAt: Date?
        }

        struct Task: Codable {
            var id: UUID
            var name: String?
            var emoji: String?
            var placeID: UUID?
            var tags: [String]?
            var steps: [RoutineStep]?
            var checklistItems: [RoutineChecklistItem]?
            var scheduleMode: RoutineScheduleMode?
            var interval: Int
            var lastDone: Date?
            var scheduleAnchor: Date?
            var pausedAt: Date?
            var completedStepCount: Int?
            var sequenceStartedAt: Date?
        }

        struct Log: Codable {
            var id: UUID
            var timestamp: Date?
            var taskID: UUID
        }
    }

    private struct ImportSummary {
        var places: Int
        var tasks: Int
        var logs: Int
    }

    private enum RoutineDataTransferError: LocalizedError {
        case unsupportedSchema(Int)

        var errorDescription: String? {
            switch self {
            case let .unsupportedSchema(version):
                return "Unsupported backup format version: \(version)."
            }
        }
    }

    private func defaultRoutineDataBackupFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "routina-backup-\(formatter.string(from: Date())).json"
    }

    @MainActor
    private func buildRoutineDataBackupJSON(from context: ModelContext) throws -> Data {
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        let backup = RoutineDataBackup(
            schemaVersion: 5,
            exportedAt: Date(),
            places: places.map {
                .init(
                    id: $0.id,
                    name: $0.displayName,
                    latitude: $0.latitude,
                    longitude: $0.longitude,
                    radiusMeters: $0.radiusMeters,
                    createdAt: $0.createdAt
                )
            },
            tasks: tasks.map {
                .init(
                    id: $0.id,
                    name: $0.name,
                    emoji: $0.emoji,
                    placeID: $0.placeID,
                    tags: $0.tags,
                    steps: $0.steps,
                    checklistItems: $0.checklistItems,
                    scheduleMode: $0.scheduleMode,
                    interval: max(Int($0.interval), 1),
                    lastDone: $0.lastDone,
                    scheduleAnchor: $0.scheduleAnchor,
                    pausedAt: $0.pausedAt,
                    completedStepCount: $0.completedSteps,
                    sequenceStartedAt: $0.sequenceStartedAt
                )
            },
            logs: logs.map {
                .init(
                    id: $0.id,
                    timestamp: $0.timestamp,
                    taskID: $0.taskID
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    @MainActor
    private func replaceAllRoutineData(
        with jsonData: Data,
        in context: ModelContext
    ) throws -> ImportSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(RoutineDataBackup.self, from: jsonData)

        guard (1...5).contains(backup.schemaVersion) else {
            throw RoutineDataTransferError.unsupportedSchema(backup.schemaVersion)
        }

        do {
            let existingLogs = try context.fetch(FetchDescriptor<RoutineLog>())
            for log in existingLogs {
                context.delete(log)
            }

            let existingTasks = try context.fetch(FetchDescriptor<RoutineTask>())
            for task in existingTasks {
                context.delete(task)
            }

            let existingPlaces = try context.fetch(FetchDescriptor<RoutinePlace>())
            for place in existingPlaces {
                context.delete(place)
            }

            var importedPlaceIDs = Set<UUID>()
            var importedPlaceCount = 0
            for place in backup.places ?? [] {
                guard importedPlaceIDs.insert(place.id).inserted else { continue }

                let importedPlace = RoutinePlace(
                    id: place.id,
                    name: place.name,
                    latitude: place.latitude,
                    longitude: place.longitude,
                    radiusMeters: place.radiusMeters,
                    createdAt: place.createdAt ?? Date()
                )
                context.insert(importedPlace)
                importedPlaceCount += 1
            }

            var importedTaskIDs = Set<UUID>()
            var importedTaskCount = 0
            for task in backup.tasks {
                guard importedTaskIDs.insert(task.id).inserted else { continue }

                let clampedInterval = min(max(task.interval, 1), Int(Int16.max))
                let importedTask = RoutineTask(
                    id: task.id,
                    name: task.name,
                    emoji: task.emoji,
                    placeID: task.placeID.flatMap { importedPlaceIDs.contains($0) ? $0 : nil },
                    tags: task.tags ?? [],
                    steps: task.steps ?? [],
                    checklistItems: task.checklistItems ?? [],
                    scheduleMode: task.scheduleMode,
                    interval: Int16(clampedInterval),
                    lastDone: task.lastDone,
                    scheduleAnchor: task.scheduleAnchor,
                    pausedAt: task.pausedAt,
                    completedStepCount: Int16(clamping: task.completedStepCount ?? 0),
                    sequenceStartedAt: task.sequenceStartedAt
                )
                context.insert(importedTask)
                importedTaskCount += 1
            }

            var importedLogIDs = Set<UUID>()
            var importedLogCount = 0
            for log in backup.logs {
                guard importedTaskIDs.contains(log.taskID) else { continue }
                guard importedLogIDs.insert(log.id).inserted else { continue }

                let importedLog = RoutineLog(
                    id: log.id,
                    timestamp: log.timestamp,
                    taskID: log.taskID
                )
                context.insert(importedLog)
                importedLogCount += 1
            }

            try context.save()
            return ImportSummary(places: importedPlaceCount, tasks: importedTaskCount, logs: importedLogCount)
        } catch {
            context.rollback()
            throw error
        }
    }

    @MainActor
    private func rescheduleNotificationsAfterImport(in context: ModelContext) async throws {
        try await rescheduleNotificationsIfNeeded(in: context)
    }

    private func withSecurityScopedAccess<T>(
        to url: URL,
        _ operation: () throws -> T
    ) throws -> T {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try operation()
    }

    @MainActor
    private func rescheduleNotificationsIfNeeded(in context: ModelContext) async throws {
        await notificationClient.cancelAll()

        guard SharedDefaults.app[.appSettingNotificationsEnabled] else { return }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard isSystemNotificationAuthorizationEnabled(settings.authorizationStatus) else { return }

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        for task in tasks {
            guard !task.isPaused else { continue }
            await notificationClient.schedule(NotificationCoordinator.notificationPayload(for: task))
        }
    }

    private func isSystemNotificationAuthorizationEnabled(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }
}
