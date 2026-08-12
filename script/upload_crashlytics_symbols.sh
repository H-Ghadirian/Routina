#!/bin/sh

set -eu

if [ "${DEBUG_INFORMATION_FORMAT:-}" != "dwarf-with-dsym" ]; then
    exit 0
fi

configuration_path="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/GoogleService-Info.plist"
if [ ! -f "$configuration_path" ]; then
    echo "warning: Routina Crashlytics dSYM upload skipped because Firebase is not configured"
    exit 0
fi

firebase_checkout="${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk"
crashlytics_run="$firebase_checkout/Crashlytics/run"
if [ ! -x "$crashlytics_run" ]; then
    echo "error: Firebase Crashlytics run script not found at $crashlytics_run"
    exit 1
fi

"$crashlytics_run"
