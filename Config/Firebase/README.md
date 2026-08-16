# Firebase Crashlytics configuration

Routina links Crashlytics in the iOS and macOS development and production app
targets. Crash reporting stays disabled when the matching configuration file is
absent, so cloning and building the repository does not require Firebase access.

Create three Apple apps in one Firebase project and download each app's
`GoogleService-Info.plist` using these exact bundle IDs and local filenames:

| Platforms | Variant | Bundle ID | Local filename |
| --- | --- | --- | --- |
| iOS + macOS | Production | `ir.hamedgh.Routinam` | `GoogleService-Info-Prod.plist` |
| iOS | Development | `ir.hamedgh.Routinam.dev` | `GoogleService-Info-iOS-Dev.plist` |
| macOS | Development | `ir.hamedgh.Routinam.mac.dev` | `GoogleService-Info-macOS-Dev.plist` |

Place the files in this directory. They are intentionally ignored by Git. A
build phase validates each plist's bundle ID and copies it into the matching app
bundle as `GoogleService-Info.plist`. Builds that produce dSYMs upload them
through Firebase's supported Crashlytics script.

Each app target declares its exact variant plist as an Xcode script input. This
is required because the user-script sandbox does not grant child-file access
when only this containing directory is declared. A missing declared plist still
follows the script's intentional no-configuration path.

Google Analytics is not linked. Routina sends Crashlytics' standard crash data,
the app variant and platform, and a throttled trail of fixed interaction
categories. It does not set a Crashlytics user ID or add task titles, search
text, record identifiers, account details, locations, or other user content.

After adding the files, edit the development scheme's Run environment variables
in Xcode and add `ROUTINA_CRASHLYTICS_TEST_CRASH=1`. Run the app and wait three
seconds for the deliberate Debug-only crash. Disable the variable, then relaunch
the app so Crashlytics can upload the pending report. The trigger is compiled out
of Release builds.
