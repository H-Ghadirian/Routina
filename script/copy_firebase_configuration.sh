#!/bin/sh

set -eu

case "${PLATFORM_NAME:-}" in
    iphoneos|iphonesimulator)
        firebase_platform="iOS"
        ;;
    macosx)
        firebase_platform="macOS"
        ;;
    *)
        echo "warning: Routina Crashlytics skipped for unsupported platform ${PLATFORM_NAME:-unknown}"
        exit 0
        ;;
esac

case "${PRODUCT_BUNDLE_IDENTIFIER:-}" in
    ir.hamedgh.Routinam)
        firebase_variant="Prod"
        firebase_configuration_name="GoogleService-Info-Prod.plist"
        ;;
    ir.hamedgh.Routinam.dev)
        firebase_variant="Dev"
        firebase_configuration_name="GoogleService-Info-iOS-Dev.plist"
        ;;
    ir.hamedgh.Routinam.mac.dev)
        firebase_variant="Dev"
        firebase_configuration_name="GoogleService-Info-macOS-Dev.plist"
        ;;
    *)
        echo "warning: Routina Crashlytics skipped for unregistered bundle ${PRODUCT_BUNDLE_IDENTIFIER:-unknown}"
        exit 0
        ;;
esac

configuration_path="$SRCROOT/Config/Firebase/$firebase_configuration_name"
destination_directory="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
destination_path="$destination_directory/GoogleService-Info.plist"

# An incremental build must not retain credentials for a configuration file
# that has since been removed or renamed.
if [ -e "$destination_path" ]; then
    rm -f "$destination_path"
fi

if [ ! -f "$configuration_path" ]; then
    echo "warning: Routina Crashlytics disabled; add $configuration_path"
    exit 0
fi

configured_bundle_id=$(/usr/libexec/PlistBuddy -c "Print :BUNDLE_ID" "$configuration_path" 2>/dev/null || true)
google_app_id=$(/usr/libexec/PlistBuddy -c "Print :GOOGLE_APP_ID" "$configuration_path" 2>/dev/null || true)

if [ "$configured_bundle_id" != "$PRODUCT_BUNDLE_IDENTIFIER" ]; then
    echo "error: Firebase BUNDLE_ID '$configured_bundle_id' does not match '$PRODUCT_BUNDLE_IDENTIFIER'"
    exit 1
fi

if [ -z "$google_app_id" ]; then
    echo "error: Firebase configuration is missing GOOGLE_APP_ID"
    exit 1
fi

mkdir -p "$destination_directory"
cp "$configuration_path" "$destination_path"
chmod 0644 "$destination_path"
echo "Routina Crashlytics configuration: ${firebase_platform} ${firebase_variant}"
