#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
cd "$project_root"

production_roots="SharedCore RoutinaMacApp iOS RoutinaWidget RoutinaWatchExtension Tools"
app_roots="SharedCore RoutinaMacApp iOS RoutinaWidget RoutinaWatchExtension"
test_roots="Tests"

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "error: Required quality tool '$1' is not installed." >&2
        exit 1
    fi
}

count_matching_swift_files() {
    pattern=$1
    shift
    find "$@" -type f -name '*.swift' -print0 \
        | xargs -0 grep -E -l "$pattern" 2>/dev/null \
        | wc -l \
        | tr -d ' '
}

count_matching_lines() {
    pattern=$1
    shift
    find "$@" -type f -name '*.swift' -print0 \
        | xargs -0 grep -E -h "$pattern" 2>/dev/null \
        | wc -l \
        | tr -d ' '
}

assert_at_most() {
    label=$1
    actual=$2
    maximum=$3
    if [ "$actual" -gt "$maximum" ]; then
        echo "error: $label increased from its quality budget of $maximum to $actual." >&2
        return 1
    fi
    printf '%-42s %s/%s\n' "$label" "$actual" "$maximum"
}

assert_at_least() {
    label=$1
    actual=$2
    minimum=$3
    if [ "$actual" -lt "$minimum" ]; then
        echo "error: $label decreased below its quality floor of $minimum to $actual." >&2
        return 1
    fi
    printf '%-42s %s/%s minimum\n' "$label" "$actual" "$minimum"
}

check_swiftlint_budget() {
    baseline_file=".swiftlint-baseline.json"
    current_baseline=$(mktemp "${TMPDIR:-/tmp}/routina-swiftlint-baseline.XXXXXX")
    trap 'rm -f "$current_baseline"' EXIT HUP INT TERM

    lint_status=0
    swiftlint lint \
        --quiet \
        --no-cache \
        --config .swiftlint.yml \
        --write-baseline "$current_baseline" \
        >/dev/null 2>&1 || lint_status=$?
    if [ "$lint_status" -ne 0 ] && [ "$lint_status" -ne 2 ]; then
        echo "error: SwiftLint failed before producing its current findings." >&2
        return 1
    fi

    # SwiftLint's native baseline includes source locations, so unrelated line
    # movement can invalidate every later entry in a file. Compare stable
    # file/rule/source-text identities instead while preserving duplicate counts.
    overages=$(jq -r \
        --arg project_prefix "$project_root/" \
        --slurpfile budget "$baseline_file" \
        --slurpfile actual "$current_baseline" '
            def normalized_file($file): $file | ltrimstr($project_prefix);
            def identity($entry):
                normalized_file($entry.violation.location.file)
                + "\u001f" + $entry.violation.ruleIdentifier
                + "\u001f" + $entry.text;
            ($budget[0]
                | group_by(identity(.))
                | map({key: identity(.[0]), value: length})
                | from_entries) as $allowed
            | ($actual[0]
                | group_by(identity(.))
                | map({key: identity(.[0]), value: length, sample: .[0]}))[]
            | select(.value > ($allowed[.key] // 0))
            | .sample.violation.location as $location
            | "\(normalized_file($location.file)):\($location.line):\($location.character): "
                + "error: SwiftLint \(.sample.violation.ruleIdentifier) finding exceeds its stable budget "
                + "(\(.value)/\($allowed[.key] // 0)): \(.sample.text)"
        ')
    if [ -n "$overages" ]; then
        printf '%s\n' "$overages" >&2
        return 1
    fi

    current_count=$(jq 'length' "$current_baseline")
    baseline_count=$(jq 'length' "$baseline_file")
    printf '%-42s %s/%s\n' "Stable SwiftLint findings" "$current_count" "$baseline_count"

    rm -f "$current_baseline"
    trap - EXIT HUP INT TERM
}

check_size_budget() {
    measurements=$(find $app_roots -type f -name '*.swift' -print0 | xargs -0 wc -l | sed '$d')
    over_500=$(printf '%s\n' "$measurements" | awk '$1 > 500 { count += 1 } END { print count + 0 }')
    over_1000=$(printf '%s\n' "$measurements" | awk '$1 > 1000 { count += 1 } END { print count + 0 }')
    over_2000=$(printf '%s\n' "$measurements" | awk '$1 > 2000 { count += 1 } END { print count + 0 }')
    largest=$(printf '%s\n' "$measurements" | awk 'BEGIN { maximum = 0 } $1 > maximum { maximum = $1 } END { print maximum }')

    assert_at_most "Production Swift files over 500 lines" "$over_500" 106
    assert_at_most "Production Swift files over 1,000 lines" "$over_1000" 27
    assert_at_most "Production Swift files over 2,000 lines" "$over_2000" 0
    assert_at_most "Largest production Swift file" "$largest" 1477
}

check_concurrency_budget() {
    unchecked=$(count_matching_lines '@unchecked[[:space:]]+Sendable' $production_roots)
    unsafe=$(count_matching_lines 'nonisolated\(unsafe\)' $production_roots)
    preconcurrency=$(count_matching_lines '@preconcurrency' $production_roots)

    assert_at_most "@unchecked Sendable uses" "$unchecked" 12
    assert_at_most "nonisolated(unsafe) uses" "$unsafe" 0
    assert_at_most "@preconcurrency uses" "$preconcurrency" 4
}

check_source_inspection_budget() {
    source_inspection_files=$(count_matching_swift_files 'SourceInspectionSupport\.(readProjectFile|readProjectSwiftFiles)' $test_roots)
    direct_source_reads=$(rg -l -U 'String\(\s*contentsOf:' Tests \
        --glob '*.swift' \
        --glob '!**/SourceInspectionSupport.swift' \
        --glob '!**/PersistenceControllerTests.swift' \
        | wc -l \
        | tr -d ' ')

    assert_at_most "Tests with architecture source checks" "$source_inspection_files" 53
    assert_at_most "Direct source reads outside helper" "$direct_source_reads" 0
}

check_raw_print_budget() {
    raw_prints=$(count_matching_lines '(^|[^A-Za-z0-9_])print\(' $app_roots)
    legacy_nslog_calls=$(count_matching_lines '(^|[^A-Za-z0-9_])NSLog\(' $app_roots)
    assert_at_most "Raw app print calls" "$raw_prints" 0
    assert_at_most "Legacy direct NSLog calls" "$legacy_nslog_calls" 139
}

check_cross_platform_duplicates() {
    duplicate_count=0
    for ios_file in $(find iOS -type f -name '*.swift'); do
        basename_value=$(basename "$ios_file")
        for mac_file in $(find RoutinaMacApp -type f -name "$basename_value"); do
            if cmp -s "$ios_file" "$mac_file"; then
                echo "error: Byte-identical platform files should live in SharedCore:" >&2
                echo "  $ios_file" >&2
                echo "  $mac_file" >&2
                duplicate_count=$((duplicate_count + 1))
            fi
        done
    done
    [ "$duplicate_count" -eq 0 ]
    printf '%-42s %s\n' "Byte-identical iOS/macOS file pairs" "$duplicate_count"
}

check_package_boundary() {
    if ! grep -q 'path: "SharedCore"' Package.swift; then
        echo "error: RoutinaAppSupport must remain rooted at SharedCore." >&2
        return 1
    fi
    if grep -A 20 'name: "RoutinaAppSupport"' Package.swift | grep -q 'path: "\."'; then
        echo "error: RoutinaAppSupport must not scan the repository root." >&2
        return 1
    fi
    echo "RoutinaAppSupport source boundary is scoped to SharedCore."
}

check_localized_content_boundaries() {
    main_catalog="AppResources/Localizable.xcstrings"
    widget_catalog="RoutinaWidget/Localizable.xcstrings"
    watch_catalog="RoutinaWatchExtension/Localizable.xcstrings"
    help_content="SharedCore/Help/Resources/en.lproj/RoutinaHelpCatalog.json"
    settings_content="SharedCore/Resources/en.lproj/SettingsContentCatalog.json"
    achievement_content="SharedCore/Resources/en.lproj/StatsAchievementContentCatalog.json"
    adventure_content="RoutinaMacApp/Resources/en.lproj/HomeAdventureCatalog.json"

    for resource in \
        "$main_catalog" \
        "$widget_catalog" \
        "$watch_catalog" \
        "$help_content" \
        "$settings_content" \
        "$achievement_content" \
        "$adventure_content"
    do
        if [ ! -f "$resource" ]; then
            echo "error: Required localized content resource is missing: $resource" >&2
            return 1
        fi
    done

    require_command xcrun
    main_catalog_keys=$(jq '.strings | length' "$main_catalog")
    widget_catalog_keys=$(jq '.strings | length' "$widget_catalog")
    watch_catalog_keys=$(jq '.strings | length' "$watch_catalog")
    assert_at_least "Main app localization catalog keys" "$main_catalog_keys" 1578
    assert_at_least "Widget localization catalog keys" "$widget_catalog_keys" 21
    assert_at_least "Watch localization catalog keys" "$watch_catalog_keys" 22

    if rg -q 'static let topics: \[RoutinaHelpTopic\] = \[' SharedCore/Help/RoutinaHelpCatalog.swift; then
        echo "error: Product Help content must remain in its localized JSON resource." >&2
        return 1
    fi
    if rg -q '^\s+(title|subtitle): "|unit: \.count\(' \
        SharedCore/Domain/FocusAchievementStats.swift \
        SharedCore/Domain/PersonalRecordAchievementStats.swift; then
        echo "error: Stats achievement copy must remain in its localized JSON resource." >&2
        return 1
    fi
    if rg -q '(WorldTemplate|ItemTemplate)\(' RoutinaMacApp/Features/Home/HomeAdventureProgression.swift; then
        echo "error: Adventure content must remain in its localized JSON resource." >&2
        return 1
    fi
    if rg -q 'Water plants every Saturday at 9am' SharedCore/Features/Settings --glob '*.swift'; then
        echo "error: Quick Add guide content must remain in its localized JSON resource." >&2
        return 1
    fi
    echo "Localized catalogs and structured content boundaries are present."
}

added_swift_files() {
    base_ref=${QUALITY_BASE_REF:-HEAD}
    if ! git rev-parse --verify "$base_ref^{commit}" >/dev/null 2>&1; then
        # A repository's first push reports an all-zero "before" SHA. Diffing
        # against Git's empty tree keeps the added-file formatter deterministic.
        base_ref=4b825dc642cb6eb9a060e54bf8d69288fbee4904
    fi
    {
        git diff --name-only --diff-filter=A "$base_ref" -- '*.swift'
        git diff --cached --name-only --diff-filter=A -- '*.swift'
        git ls-files --others --exclude-standard -- '*.swift'
    } | awk '!seen[$0]++' | while IFS= read -r path; do
        [ -f "$path" ] && printf '%s\n' "$path"
    done
}

format_added_files() {
    require_command swift
    files=$(added_swift_files)
    if [ -z "$files" ]; then
        echo "No added Swift files require formatting validation."
        return
    fi

    # Intentional word splitting: every repository path is newline-delimited
    # and the current Swift source tree contains no paths with spaces.
    # shellcheck disable=SC2086
    swift format lint --strict --configuration .swift-format $files
}

require_command swiftlint
require_command rg
require_command jq
check_swiftlint_budget
format_added_files
check_size_budget
check_concurrency_budget
check_source_inspection_budget
check_raw_print_budget
check_cross_platform_duplicates
check_package_boundary
check_localized_content_boundaries

echo "Code quality checks passed."
