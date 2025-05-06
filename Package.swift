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
                ".git",
                ".xcresulttmp",
                "Routina.xcworkspace",
                "Routina.xcodeproj",
                "RoutinaMac.xcodeproj",
                "Routina/Info.plist",
                "Routina/Preview Content",
                "Routina/Resources",
                "Routina/Routina.entitlements",
                "Routina/RoutinaDev.entitlements",
                "Routina/RoutinaMac.entitlements",
                "Routina/RoutinaMacDev.entitlements",
                "Routina/RoutinaMacProd.entitlements",
                "iOS",
                "RoutinaWatchApp",
                "RoutinaWatchExtension",
                "RoutinaTests",
                "RoutinaUITests",
                "Modules",
                "build",
                "mac+watch+ios",
                "tmp-routina-unit.xcresult",
            ],
            sources: [
                "Routina/Models",
                "Routina/Screens/AddRoutine/AddRoutineFeature.swift",
                "Routina/Screens/App/AppFeature.swift",
                "Routina/Screens/Home/HomeFeature.swift",
                "Routina/Screens/Home/HomeFeature+Display.swift",
                "Routina/Screens/Home/HomeFeature+Deduplication.swift",
                "Routina/Screens/Home/HomeFeature+ReloadGuard.swift",
                "Routina/Screens/RoutineDetail/RoutineDetailFeature.swift",
                "Routina/Screens/RoutineDetail/RoutineDetailFeature+FormSync.swift",
                "Routina/Screens/RoutineDetail/RoutineDetailFeature+Helpers.swift",
                "Routina/Screens/RoutineDetail/RoutineDetailFeature+Effects.swift",
                "Routina/Screens/RoutineDetail/RoutineDetailFeature+StateDerivation.swift",
                "Routina/Screens/RoutineDetail/RoutinePauseArchivePresentation.swift",
                "Routina/Screens/Settings/PlaceLocationPickerCameraConfiguration.swift",
                "Routina/Screens/Settings/SettingsFeature.swift",
                "Routina/Screens/Settings/SettingsViewSupport.swift",
                "Routina/Utilities/AppEnvironment.swift",
                "Routina/Utilities/AppIconClient.swift",
                "Routina/Utilities/CloudDataResetService.swift",
                "Routina/Utilities/CloudKitDirectPullService.swift",
                "Routina/Utilities/CloudKitPushSubscriptionService.swift",
                "Routina/Utilities/CloudKitSyncDiagnostics.swift",
                "Routina/Utilities/CloudSyncClient.swift",
                "Routina/Utilities/DependencyValues+.swift",
                "Routina/Utilities/EmojiCatalog.swift",
                "Routina/Utilities/LocationClient.swift",
                "Routina/Utilities/NotificationClient.swift",
                "Routina/Utilities/NotificationCoordinator.swift",
                "Routina/Utilities/NotificationPreferences.swift",
                "Routina/Utilities/PersistenceController.swift",
                "Routina/Utilities/PlatformSupport+Fallback.swift",
                "Routina/Utilities/PlatformSupport.swift",
                "Routina/Utilities/RoutinaAppBootstrap.swift",
                "Routina/Utilities/RoutineCompletionStats.swift",
                "Routina/Utilities/RoutineDateMath.swift",
                "Routina/Utilities/RoutineListFilter.swift",
                "Routina/Utilities/RoutineLogHistory.swift",
                "Routina/Utilities/RoutineTag.swift",
                "Routina/Utilities/Tab.swift",
                "Routina/Utilities/TabFilterStateManager.swift",
                "Routina/Utilities/TaskImageProcessor.swift",
                "Routina/Utilities/TaskImageView.swift",
                "Routina/Utilities/TimelineLogic.swift",
                "Routina/Utilities/UserDefaultsProtocol.swift",
                "RoutinaMacApp/Utilities/LocationClient+macOS.swift",
                "RoutinaMacApp/Screens/Settings/SettingsFeature+macOS.swift",
            ]
        ),
        .target(
            name: "RoutinaMacSupport",
            path: ".",
            exclude: [
                ".git",
                ".xcresulttmp",
                "Routina",
                "Routina.xcworkspace",
                "Routina.xcodeproj",
                "RoutinaMac.xcodeproj",
                "RoutinaMacApp/RoutinaMacApp.swift",
                "RoutinaMacApp/Screens",
                "RoutinaMacApp/Utilities/PlatformSupport+AppKit.swift",
                "RoutinaWatchApp",
                "RoutinaWatchExtension",
                "RoutinaTests",
                "RoutinaUITests",
                "Modules",
                "build",
                "mac+watch+ios",
                "tmp-routina-unit.xcresult",
            ],
            sources: [
                "RoutinaMacApp/Commands",
                "RoutinaMacApp/Utilities/MacMenuCleanup.swift",
            ]
        ),
        .testTarget(
            name: "RoutinaTests",
            dependencies: [
                "RoutinaAppSupport",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            path: "RoutinaTests"
        ),
    ]
)
