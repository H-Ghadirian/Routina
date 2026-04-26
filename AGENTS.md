# Routina Agent Notes

## Build Verification

- iOS CLI build:
  `xcodebuild build -project /Users/ghadirianh/Routina/RoutinaiOS.xcodeproj -scheme RoutinaiOSDev -destination 'generic/platform=iOS'`
- macOS CLI build:
  `xcodebuild build -project /Users/ghadirianh/Routina/RoutinaMacOS.xcodeproj -scheme RoutinaMacOSDev -destination 'generic/platform=macOS'`
- If the macOS CLI build fails with a provisioning profile error like `profile doesn't include signing certificate`, retry once with `-allowProvisioningUpdates`:
  `xcodebuild build -allowProvisioningUpdates -project /Users/ghadirianh/Routina/RoutinaMacOS.xcodeproj -scheme RoutinaMacOSDev -destination 'generic/platform=macOS'`
- After a successful `-allowProvisioningUpdates` build, run the normal macOS build again to confirm the refreshed Xcode managed profiles are now valid without the extra flag.

