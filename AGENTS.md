# Routina Agent Notes

## Build Verification

- iOS CLI build:
  `xcodebuild build -quiet -project /Users/ghadirianh/Routina/RoutinaiOS.xcodeproj -scheme RoutinaiOSDev -destination 'generic/platform=iOS'`
- macOS CLI build:
  `xcodebuild build -quiet -project /Users/ghadirianh/Routina/RoutinaMacOS.xcodeproj -scheme RoutinaMacOSDev -destination 'generic/platform=macOS'`
- If the macOS CLI build fails with a provisioning profile error like `profile doesn't include signing certificate`, retry once with `-allowProvisioningUpdates`:
  `xcodebuild build -quiet -allowProvisioningUpdates -project /Users/ghadirianh/Routina/RoutinaMacOS.xcodeproj -scheme RoutinaMacOSDev -destination 'generic/platform=macOS'`
- After a successful `-allowProvisioningUpdates` build, run the normal macOS build again to confirm the refreshed Xcode managed profiles are now valid without the extra flag.
- Prefer the quiet build commands for routine verification. Verbose Xcode 26.4 Swift builds can print internal `DecodingError.dataCorrupted` / `Corrupted JSON` messages while the build still succeeds; `-quiet` keeps real compiler errors visible without that noisy parseable-output decoder issue.
