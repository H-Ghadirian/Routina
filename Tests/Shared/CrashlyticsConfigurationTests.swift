import Foundation
import Testing

struct CrashlyticsConfigurationTests {
    @Test
    func appleAppTargetsLinkCrashlyticsWithoutAnalytics() throws {
        for projectPath in [
            "RoutinaiOS.xcodeproj/project.pbxproj",
            "RoutinaMacOS.xcodeproj/project.pbxproj",
        ] {
            let project = try Self.sourceFile(projectPath)
            #expect(project.contains("https://github.com/firebase/firebase-ios-sdk.git"))
            #expect(project.components(separatedBy: "FirebaseCrashlytics in Frameworks").count >= 5)
            #expect(project.contains("Copy Firebase Configuration"))
            #expect(project.contains("Upload Crashlytics Symbols"))
            #expect(project.contains("script/copy_firebase_configuration.sh"))
            #expect(project.contains("script/upload_crashlytics_symbols.sh"))
            #expect(!project.contains("FirebaseAnalytics"))
        }
    }

    @Test
    func configurationCopyIsOptionalAndValidatesBundleIdentity() throws {
        let script = try Self.sourceFile("script/copy_firebase_configuration.sh")
        #expect(script.contains("GoogleService-Info-Prod.plist"))
        #expect(script.contains("GoogleService-Info-iOS-Dev.plist"))
        #expect(script.contains("GoogleService-Info-macOS-Dev.plist"))
        #expect(script.contains("BUNDLE_ID"))
        #expect(script.contains("GOOGLE_APP_ID"))
        #expect(script.contains("Crashlytics disabled"))
        #expect(script.contains("exit 0"))

        let ignoreFile = try Self.sourceFile(".gitignore")
        #expect(ignoreFile.contains("Config/Firebase/GoogleService-Info-*.plist"))
    }

    @Test
    func configurationCopyRemovesQuarantineFromBundledPlist() throws {
        let script = try Self.sourceFile("script/copy_firebase_configuration.sh")
        #expect(script.contains(
            "xattr -d com.apple.quarantine \"$destination_path\" 2>/dev/null || true"
        ))
    }

    @Test
    func configurationCopyDeclaresExactInputsForXcodeScriptSandboxing() throws {
        let iOSProject = try Self.sourceFile("RoutinaiOS.xcodeproj/project.pbxproj")
        #expect(iOSProject.contains(
            "$(SRCROOT)/Config/Firebase/GoogleService-Info-Prod.plist"
        ))
        #expect(iOSProject.contains(
            "$(SRCROOT)/Config/Firebase/GoogleService-Info-iOS-Dev.plist"
        ))
        #expect(!iOSProject.contains("\"$(SRCROOT)/Config/Firebase\","))

        let macOSProject = try Self.sourceFile("RoutinaMacOS.xcodeproj/project.pbxproj")
        #expect(macOSProject.contains(
            "$(SRCROOT)/Config/Firebase/GoogleService-Info-Prod.plist"
        ))
        #expect(macOSProject.contains(
            "$(SRCROOT)/Config/Firebase/GoogleService-Info-macOS-Dev.plist"
        ))
        #expect(!macOSProject.contains("\"$(SRCROOT)/Config/Firebase\","))
    }

    @Test
    func symbolUploadDeclaresNormalAndArchivePackageExecutablesForSandboxing() throws {
        let requiredInputs = [
            "$(BUILD_DIR)/../../SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run",
            "$(BUILD_DIR)/../../SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols",
            "$(BUILD_DIR)/../../../../../SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run",
            "$(BUILD_DIR)/../../../../../SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols",
        ]

        for projectPath in [
            "RoutinaiOS.xcodeproj/project.pbxproj",
            "RoutinaMacOS.xcodeproj/project.pbxproj",
        ] {
            let project = try Self.sourceFile(projectPath)
            for input in requiredInputs {
                #expect(project.components(separatedBy: "\"\(input)\",").count == 3)
            }
        }

        let uploadScript = try Self.sourceFile("script/upload_crashlytics_symbols.sh")
        #expect(uploadScript.contains(
            "firebase_checkout=\"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk\""
        ))
    }

    @Test
    func crashContextCannotAcceptUserOwnedStrings() throws {
        let reporter = try Self.sourceFile("SharedCore/Services/RoutinaCrashReporter.swift")
        #expect(reporter.contains(
            "static func recordInteraction(_ interaction: RoutinaPerformanceInteraction)"
        ))
        #expect(!reporter.contains("setUserID"))
        #expect(!reporter.contains("FirebaseAnalytics"))
        #expect(reporter.contains("#if DEBUG"))
        #expect(reporter.contains("ROUTINA_CRASHLYTICS_TEST_CRASH"))
    }

    @Test
    func macAppsCrashOnUncaughtObjectiveCExceptionsForCrashlytics() throws {
        for path in [
            "Config/macOS/RoutinaMacOSDev-Info.plist",
            "Config/macOS/RoutinaMacOSProd-Info.plist",
        ] {
            let data = try Data(contentsOf: Self.projectRoot.appendingPathComponent(path))
            let object = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            )
            let dictionary = try #require(object as? [String: Any])
            #expect(dictionary["NSApplicationCrashOnExceptions"] as? Bool == true)
        }
    }

    @Test
    func swiftUIAppsDisableFirebaseAppDelegateSwizzling() throws {
        for path in [
            "Config/iOS/RoutinaiOSDev-Info.plist",
            "Config/iOS/RoutinaiOSProd-Info.plist",
            "Config/macOS/RoutinaMacOSDev-Info.plist",
            "Config/macOS/RoutinaMacOSProd-Info.plist",
        ] {
            let data = try Data(contentsOf: Self.projectRoot.appendingPathComponent(path))
            let object = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            )
            let dictionary = try #require(object as? [String: Any])
            #expect(dictionary["FirebaseAppDelegateProxyEnabled"] as? Bool == false)
        }
    }

    @Test
    func macAppsShareTheirOwnFirebaseInstallationKeychainItems() throws {
        for path in [
            "Config/macOS/RoutinaMacOSDev.entitlements",
            "Config/macOS/RoutinaMacOSProd.entitlements",
            "Config/macOS/RoutinaMacOSProdRelease.entitlements",
        ] {
            let data = try Data(contentsOf: Self.projectRoot.appendingPathComponent(path))
            let object = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            )
            let dictionary = try #require(object as? [String: Any])
            #expect(
                dictionary["keychain-access-groups"] as? [String] == [
                    "$(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)",
                ]
            )
        }
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        try SourceInspectionSupport.readProjectFile(relativePath)
    }

    private static let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
