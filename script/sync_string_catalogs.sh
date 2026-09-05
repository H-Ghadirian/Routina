#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
cd "$project_root"

if ! command -v jq >/dev/null 2>&1; then
    echo "error: Required catalog tool 'jq' is not installed." >&2
    exit 1
fi

mode=${1:-sync}
case "$mode" in
    sync|--check) ;;
    *)
        echo "usage: $0 [--check]" >&2
        exit 1
        ;;
esac

main_catalog="AppResources/Localizable.xcstrings"
widget_catalog="RoutinaWidget/Localizable.xcstrings"
watch_catalog="RoutinaWatchExtension/Localizable.xcstrings"
build_architecture=${ROUTINA_LOCALIZATION_ARCH:-$(uname -m)}
mac_objects=".build/xcode-derived-data/macos-dev/Build/Intermediates.noindex/RoutinaMacOS.build/Debug/RoutinaMacOSDev.build/Objects-normal/$build_architecture"
ios_objects=".build/xcode-derived-data/ios-simulator-dev/Build/Intermediates.noindex/RoutinaiOS.build/Debug-iphonesimulator/RoutinaiOSDev.build/Objects-normal/$build_architecture"
widget_objects=".build/xcode-derived-data/ios-simulator-dev/Build/Intermediates.noindex/RoutinaiOS.build/Debug-iphonesimulator/RoutinaWidgetDevExtension.build/Objects-normal/$build_architecture"
watch_objects=".build/xcode-derived-data/watch-simulator-dev/Build/Intermediates.noindex/RoutinaiOS.build/Debug-watchsimulator/RoutinaWatchExtension.build/Objects-normal/$build_architecture"

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
    label=$2
    shift 2
    # Intentional word splitting: Derived Data paths are newline-delimited and
    # the project-local build roots contain no spaces.
    # shellcheck disable=SC2086
    xcrun xcstringstool sync "$catalog" --stringsdata $*
    key_count=$(jq '.strings | length' "$catalog")
    printf '%-42s %s keys\n' "$label" "$key_count"
}

cleanup_check_directory() {
    [ -n "${check_directory:-}" ] || return
    rm -f \
        "$check_directory/main/Localizable.xcstrings" \
        "$check_directory/widget/Localizable.xcstrings" \
        "$check_directory/watch/Localizable.xcstrings" \
        "$check_directory/source-normalized.json" \
        "$check_directory/synchronized-normalized.json"
    rmdir \
        "$check_directory/main" \
        "$check_directory/widget" \
        "$check_directory/watch" \
        2>/dev/null || true
    rmdir "$check_directory" 2>/dev/null || true
}

check_catalog_matches() {
    source_catalog=$1
    synchronized_catalog=$2
    jq -S . "$source_catalog" > "$check_directory/source-normalized.json"
    jq -S . "$synchronized_catalog" > "$check_directory/synchronized-normalized.json"
    if ! cmp -s \
        "$check_directory/source-normalized.json" \
        "$check_directory/synchronized-normalized.json"; then
        echo "error: $source_catalog is out of sync with compiler localization output." >&2
        return 1
    fi
}

mac_data=$(require_stringsdata "macOS app" "$mac_objects")
ios_data=$(require_stringsdata "iOS app" "$ios_objects")
widget_data=$(require_stringsdata "Widget" "$widget_objects")
watch_data=$(require_stringsdata "Watch" "$watch_objects")

if [ "$mode" = "--check" ]; then
    check_directory=$(mktemp -d "${TMPDIR:-/tmp}/routina-catalog-check.XXXXXX")
    trap cleanup_check_directory EXIT HUP INT TERM
    mkdir "$check_directory/main" "$check_directory/widget" "$check_directory/watch"
    main_output="$check_directory/main/Localizable.xcstrings"
    widget_output="$check_directory/widget/Localizable.xcstrings"
    watch_output="$check_directory/watch/Localizable.xcstrings"
    cp "$main_catalog" "$main_output"
    cp "$widget_catalog" "$widget_output"
    cp "$watch_catalog" "$watch_output"
else
    main_output=$main_catalog
    widget_output=$widget_catalog
    watch_output=$watch_catalog
fi

sync_catalog "$main_output" "$main_catalog" $mac_data $ios_data
sync_catalog "$widget_output" "$widget_catalog" $widget_data
sync_catalog "$watch_output" "$watch_catalog" $watch_data

if [ "$mode" = "--check" ]; then
    check_catalog_matches "$main_catalog" "$main_output"
    check_catalog_matches "$widget_catalog" "$widget_output"
    check_catalog_matches "$watch_catalog" "$watch_output"
    echo "String catalogs match compiler localization output."
    cleanup_check_directory
    check_directory=
    trap - EXIT HUP INT TERM
fi
