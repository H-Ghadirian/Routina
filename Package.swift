// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RoutinaModules",
    platforms: [
        .iOS("18.0"),
        .macOS("15.0"),
    ],
    products: [
        .library(
            name: "RoutinaAppSupport",
            targets: ["RoutinaAppSupport"]
        ),
        .library(
            name: "RoutinaMacSupport",
            targets: ["RoutinaMacSupport"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.24.1"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-dependencies",
            from: "1.4.0"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-case-paths",
            from: "1.5.4"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-perception",
            from: "1.3.4"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-concurrency-extras",
            from: "1.2.0"
        ),
    ],
    targets: [
        .target(
            name: "RoutinaAppSupport",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "Perception", package: "swift-perception"),
                .product(name: "PerceptionCore", package: "swift-perception"),
                .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
            ],
            path: ".",
            exclude: [
                ".build",
                ".claude",
                ".git",
                ".gitignore",
                ".swiftpm",
                ".xcresulttmp",
                ".DS_Store",
                "Package.resolved",
                "Package.swift",
                "Routina.xcworkspace",
                "RoutinaiOS.xcodeproj",
                "RoutinaMacOS.xcodeproj",
                "Config",
                "AppResources",
                "iOS",
                "RoutinaMacApp",
                "RoutinaWatchApp",
                "RoutinaWatchExtension",
                "Tests",
                "mac+watch+ios",
                // Files that live in SharedCore but cannot yet be compiled as
                // part of the RoutinaAppSupport package target. Each needs a
                // dedicated migration step before it can move in.
                //
                // Blocked on AppFeature (top-level TCA reducer still lives in
                // the per-app Xcode targets):
                "SharedCore/App/RoutinaAppBootstrap.swift",
                "SharedCore/App/RoutinaAppSceneBootstrap.swift",
                "SharedCore/Features/Settings/SettingsFeature.swift",
                "SharedCore/Features/Settings/SettingsViewSupport.swift",
                // TODO(styling-injection): These reference TaskDetailPlatformStyle,
                // a per-app enum of UI constants (fonts/colors/padding). The two
                // per-app copies share an API but no implementation, so a naive
                // `#if canImport(UIKit/AppKit)` merge is copy-paste dressed up as
                // sharing and inverts layering (SharedCore picking platform UI
                // tokens). Design a proper injection path — e.g. a
                // `TaskDetailStyling` protocol with per-app conforming values
                // injected via TCA dependency or SwiftUI environment — then move
                // these files in and drop the per-app TaskDetailPlatformStyle.swift
                // copies under iOS/ and RoutinaMacApp/.
                "SharedCore/Screens/TaskDetail/TaskDetailPresentation.swift",
                "SharedCore/Screens/TaskDetail/Graph/RelationshipGraphNodeCard.swift",
                // Blocked on per-app view modifiers (routinaInlineTitleDisplayMode,
                // routinaGraphSheetFrame) plus TaskDetailPlatformStyle above:
                "SharedCore/Screens/TaskDetail/Graph/TaskRelationshipGraphSheet.swift",
                // Not yet audited:
                "SharedCore/Screens/TaskDetail/TaskDetailHeaderViews.swift",
            ],
            sources: [
                "SharedCore/App/AppEnvironment.swift",
                "SharedCore/Models",
                "SharedCore/Dependencies/AppIconClient.swift",
                "SharedCore/Dependencies/DependencyValues+.swift",
                "SharedCore/Dependencies/LocationClient.swift",
                "SharedCore/Dependencies/NotificationClient.swift",
                "SharedCore/Dependencies/PlatformSupport.swift",
                "SharedCore/Dependencies/UserDefaultsProtocol.swift",
                "SharedCore/Domain/EmojiCatalog.swift",
                "SharedCore/Domain/NotificationPreferences.swift",
                "SharedCore/Domain/RoutineCompletionStats.swift",
                "SharedCore/Domain/RoutineDateMath.swift",
                "SharedCore/Domain/RoutineListFilter.swift",
                "SharedCore/Domain/RoutineListSectioningMode.swift",
                "SharedCore/Domain/RoutineLogHistory.swift",
                "SharedCore/Domain/RoutineTag.swift",
                "SharedCore/Domain/TagCounterDisplayMode.swift",
                "SharedCore/Domain/TagCounterFormatting.swift",
                "SharedCore/Domain/Tab.swift",
                "SharedCore/Domain/TabFilterStateManager.swift",
                "SharedCore/Domain/TaskImageProcessor.swift",
                "SharedCore/Domain/TimelineLogic.swift",
                "SharedCore/Features/AddRoutine/AddRoutineFeature.swift",
                "SharedCore/Features/TaskDetail/RoutinePauseArchivePresentation.swift",
                "SharedCore/Features/TaskDetail/TaskDetailFeature.swift",
                "SharedCore/Features/TaskDetail/TaskDetailFeature+Effects.swift",
                "SharedCore/Features/TaskDetail/TaskDetailFeature+FormSync.swift",
                "SharedCore/Features/TaskDetail/TaskDetailFeature+Helpers.swift",
                "SharedCore/Features/TaskDetail/TaskDetailFeature+Presentation.swift",
                "SharedCore/Features/TaskDetail/TaskDetailFeature+StateDerivation.swift",
                "SharedCore/Persistence/PersistenceController.swift",
                "SharedCore/Screens/TaskDetail/Graph/RelationshipGraphEdge.swift",
                "SharedCore/Screens/TaskDetail/Graph/TaskRelationshipGraphLayout.swift",
                "SharedCore/Services/NotificationCoordinator.swift",
                "SharedCore/Sync/CloudDataResetService.swift",
                "SharedCore/Sync/CloudKitDirectPullService.swift",
                "SharedCore/Sync/CloudKitPushSubscriptionService.swift",
                "SharedCore/Sync/CloudKitSyncDiagnostics.swift",
                "SharedCore/Sync/CloudSyncClient.swift",
                "SharedCore/Views/ImportanceUrgencyMatrixPicker.swift",
            ]
        ),
        .target(
            name: "RoutinaMacSupport",
            path: "RoutinaMacApp",
            exclude: [
                "AddEditFormCoordinator.swift",
                "Features",
                "RoutinaMacApp.swift",
                "Screens",
                "Utilities/LocationProvider.swift",
                "Utilities/PlatformClients.swift",
                "Utilities/PlatformSupport+AppKit.swift",
                "Utilities/PlatformSupportBase.swift",
                "Utilities/RemoteNotificationMacDelegate.swift",
                "Utilities/RoutinaMacGlobalHotKey.swift",
            ],
            sources: [
                "Commands",
                "Utilities/MacMenuCleanup.swift",
            ]
        ),
        .testTarget(
            name: "RoutinaAppSupportTests",
            dependencies: [
                "RoutinaAppSupport",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
            path: "Tests/Shared"
        ),
    ]
)
