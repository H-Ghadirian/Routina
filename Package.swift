// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RoutinaModules",
    platforms: [
        .iOS("18.0"),
        .macOS("15.0"),
        .watchOS("11.0"),
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
        .library(
            name: "RoutinaWatchSupport",
            targets: ["RoutinaWatchSupport"]
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
                "Routina/Screens/App/RoutinaTCAApp.swift",
                "RoutinaMacApp/Commands",
                "RoutinaMacApp/RoutinaMacApp.swift",
                "RoutinaMacApp/Utilities/MacMenuCleanup.swift",
                "RoutinaWatchApp",
                "RoutinaWatchExtension",
                "RoutinaTests",
                "RoutinaUITests",
                "Modules/RoutinaMacSupport",
                "Modules/RoutinaWatchSupport",
                "build",
                "mac+watch+ios",
                "tmp-routina-unit.xcresult",
            ],
            sources: [
                "Routina/Models",
                "Routina/Screens",
                "Routina/Utilities",
                "RoutinaMacApp/Screens",
                "RoutinaMacApp/Utilities/PlatformSupport+AppKit.swift",
                "Modules/RoutinaAppSupport",
            ]
        ),
        .target(
            name: "RoutinaMacSupport",
            dependencies: [
                "RoutinaAppSupport",
            ],
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
                "Modules/RoutinaAppSupport",
                "Modules/RoutinaWatchSupport",
                "build",
                "mac+watch+ios",
                "tmp-routina-unit.xcresult",
            ],
            sources: [
                "RoutinaMacApp/Commands",
                "RoutinaMacApp/Utilities/MacMenuCleanup.swift",
                "Modules/RoutinaMacSupport",
            ]
        ),
        .target(
            name: "RoutinaWatchSupport",
            path: ".",
            exclude: [
                ".git",
                ".xcresulttmp",
                "Routina",
                "Routina.xcworkspace",
                "Routina.xcodeproj",
                "RoutinaMac.xcodeproj",
                "RoutinaMacApp",
                "RoutinaWatchApp",
                "RoutinaWatchExtension/Info.plist",
                "RoutinaWatchExtension/RoutinaWatchExtensionApp.swift",
                "RoutinaTests",
                "RoutinaUITests",
                "Modules/RoutinaAppSupport",
                "Modules/RoutinaMacSupport",
                "build",
                "mac+watch+ios",
                "tmp-routina-unit.xcresult",
            ],
            sources: [
                "RoutinaWatchExtension/WatchHomeView.swift",
                "RoutinaWatchExtension/WatchRoutineSyncStore.swift",
                "Modules/RoutinaWatchSupport",
            ]
        ),
    ]
)
