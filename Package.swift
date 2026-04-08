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
                "Routina/SharedCore/Models",
                "FeatureTestSupport/Features/AddRoutine/AddRoutineFeature.swift",
                "FeatureTestSupport/Features/App/AppFeature.swift",
                "FeatureTestSupport/Features/Home/HomeFeature.swift",
                "FeatureTestSupport/Features/Home/HomeFeature+Display.swift",
                "FeatureTestSupport/Features/Home/HomeFeature+Deduplication.swift",
                "FeatureTestSupport/Features/Home/HomeFeature+ReloadGuard.swift",
                "FeatureTestSupport/Features/RoutineDetail/RoutineDetailFeature.swift",
                "FeatureTestSupport/Features/RoutineDetail/RoutineDetailFeature+FormSync.swift",
                "FeatureTestSupport/Features/RoutineDetail/RoutineDetailFeature+Helpers.swift",
                "FeatureTestSupport/Features/RoutineDetail/RoutineDetailFeature+Effects.swift",
                "FeatureTestSupport/Features/RoutineDetail/RoutineDetailFeature+StateDerivation.swift",
                "FeatureTestSupport/Features/RoutineDetail/RoutinePauseArchivePresentation.swift",
                "FeatureTestSupport/Features/Settings/SettingsFeature.swift",
                "FeatureTestSupport/Features/Settings/SettingsFeature+FeatureTestSupport.swift",
                "FeatureTestSupport/Features/Settings/SettingsMacSection.swift",
                "FeatureTestSupport/Features/Settings/SettingsViewSupport.swift",
                "FeatureTestSupport/Utilities/PlaceLocationPickerCameraConfiguration.swift",
                "FeatureTestSupport/Utilities/PlatformSupport+FeatureTestSupport.swift",
                "Routina/SharedCore/Utilities/AppEnvironment.swift",
                "Routina/SharedCore/Utilities/AppIconClient.swift",
                "Routina/SharedCore/Utilities/CloudDataResetService.swift",
                "Routina/SharedCore/Utilities/CloudKitDirectPullService.swift",
                "Routina/SharedCore/Utilities/CloudKitPushSubscriptionService.swift",
                "Routina/SharedCore/Utilities/CloudKitSyncDiagnostics.swift",
                "Routina/SharedCore/Utilities/CloudSyncClient.swift",
                "Routina/SharedCore/Utilities/DependencyValues+.swift",
                "Routina/SharedCore/Utilities/EmojiCatalog.swift",
                "Routina/SharedCore/Utilities/LocationClient.swift",
                "Routina/SharedCore/Utilities/NotificationClient.swift",
                "Routina/SharedCore/Utilities/NotificationCoordinator.swift",
                "Routina/SharedCore/Utilities/NotificationPreferences.swift",
                "Routina/SharedCore/Utilities/PersistenceController.swift",
                "Routina/SharedCore/Utilities/PlatformSupport.swift",
                "Routina/SharedCore/Utilities/RoutineCompletionStats.swift",
                "Routina/SharedCore/Utilities/RoutineDateMath.swift",
                "Routina/SharedCore/Utilities/RoutineListFilter.swift",
                "Routina/SharedCore/Utilities/RoutineLogHistory.swift",
                "Routina/SharedCore/Utilities/RoutineTag.swift",
                "Routina/SharedCore/Utilities/Tab.swift",
                "Routina/SharedCore/Utilities/TabFilterStateManager.swift",
                "Routina/SharedCore/Utilities/TaskImageProcessor.swift",
                "Routina/SharedCore/Utilities/TimelineLogic.swift",
                "Routina/SharedCore/Utilities/UserDefaultsProtocol.swift",
                "Routina/SharedCore/Utilities/RoutinaAppBootstrap.swift",
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
