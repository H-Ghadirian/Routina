#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
cd "$project_root"

main_catalog="AppResources/Localizable.xcstrings"
widget_catalog="RoutinaWidget/Localizable.xcstrings"
watch_catalog="RoutinaWatchExtension/Localizable.xcstrings"
mac_objects=".build/xcode-derived-data/macos-dev/Build/Intermediates.noindex/RoutinaMacOS.build/Debug/RoutinaMacOSDev.build/Objects-normal"
ios_objects=".build/xcode-derived-data/ios-simulator-dev/Build/Intermediates.noindex/RoutinaiOS.build/Debug-iphonesimulator/RoutinaiOSDev.build/Objects-normal"
widget_objects=".build/xcode-derived-data/ios-simulator-dev/Build/Intermediates.noindex/RoutinaiOS.build/Debug-iphonesimulator/RoutinaWidgetDevExtension.build/Objects-normal"
watch_objects=".build/xcode-derived-data/watch-simulator-dev/Build/Intermediates.noindex/RoutinaiOS.build/Debug-watchsimulator/RoutinaWatchExtension.build/Objects-normal"

require_stringsdata() {
    label=$1
    shift
    files=$(find "$@" -type f -name '*.stringsdata' -print 2>/dev/null || true)
    if [ -z "$files" ]; then
        echo "error: No $label compiler localization output was found. Build that target first." >&2
        return 1
    fi
    printf '%s\n' "$files"
}

sync_catalog() {
    catalog=$1
    shift
    # Intentional word splitting: Derived Data paths are newline-delimited and
    # the project-local build roots contain no spaces.
    # shellcheck disable=SC2086
    xcrun xcstringstool sync "$catalog" --stringsdata $*
    key_count=$(xcrun xcstringstool print "$catalog" | wc -l | tr -d ' ')
    printf '%-42s %s keys\n' "$catalog" "$key_count"
}

mac_data=$(require_stringsdata "macOS app" "$mac_objects")
ios_data=$(require_stringsdata "iOS app" "$ios_objects")
widget_data=$(require_stringsdata "Widget" "$widget_objects")
watch_data=$(require_stringsdata "Watch" "$watch_objects")

sync_catalog "$main_catalog" $mac_data $ios_data
sync_catalog "$widget_catalog" $widget_data
sync_catalog "$watch_catalog" $watch_data
