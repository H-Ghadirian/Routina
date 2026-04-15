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
                "SharedCore/Domain/Tab.swift",
                "SharedCore/Domain/TabFilterStateManager.swift",
                "SharedCore/Domain/TaskImageProcessor.swift",
                "SharedCore/Domain/TimelineLogic.swift",
                "SharedCore/Features/TaskDetail/RoutinePauseArchivePresentation.swift",
                "SharedCore/Features/TaskDetail/TaskDetailFeature.swift",
                "SharedCore/Features/TaskDetail/TaskDetailFeature+Effects.swift",
                "SharedCore/Features/TaskDetail/TaskDetailFeature+FormSync.swift",
                "SharedCore/Features/TaskDetail/TaskDetailFeature+Helpers.swift",
                "SharedCore/Features/TaskDetail/TaskDetailFeature+Presentation.swift",
                "SharedCore/Features/TaskDetail/TaskDetailFeature+StateDerivation.swift",
                "SharedCore/Persistence/PersistenceController.swift",
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
            path: "Tests/Shared",
            exclude: [
                // Tests app-level `HomeFeature.matches...` helpers that live
                // outside `RoutinaAppSupport`. Kept in the iOS/Mac app test
                // targets only until those helpers move into SharedCore.
                "ExcludeTagsTests.swift",
            ]
        ),
    ]
)
