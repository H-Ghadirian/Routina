#!/bin/sh
#
# Blocks a production archive when the SwiftData model has changed since the
# last schema deployment that was explicitly acknowledged in CloudKit
# Production. CloudKit has no local API that can prove the remote Production
# schema matches Development, so the acknowledgement is deliberately manual
# and records that the Dashboard deployment was completed.

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
manifest_path="$project_root/Config/CloudKit/production-schema.manifest"
model_directory="$project_root/SharedCore/Models"

usage() {
    cat <<'EOF'
Usage:
  script/cloudkit_schema_guard.sh --check
  script/cloudkit_schema_guard.sh --print-current
  script/cloudkit_schema_guard.sh --acknowledge-production-deployment --yes-i-deployed-to-production

`--check` compares the current SwiftData CloudKit schema contract with the
last acknowledged Production deployment. The Xcode production archive phase
uses the same check automatically.

Only run the acknowledgement command after CloudKit Dashboard confirms that
the Development schema changes were deployed to Production.
EOF
}

generate_current_schema() {
    find "$model_directory" -type f -name '*.swift' -print \
        | LC_ALL=C sort \
        | while IFS= read -r source_file; do
            awk '
                /^@Model[[:space:]]*$/ {
                    awaiting_model_class = 1
                    next
                }

                awaiting_model_class && /^final class[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/ {
                    model_name = $3
                    sub(/\{.*/, "", model_name)
                    collecting_properties = 1
                    model_brace_depth = 1
                    awaiting_model_class = 0
                    next
                }

                collecting_properties {
                    property_line = $0

                    # Stored SwiftData properties are direct members of an
                    # @Model class. Ignore computed properties, static helpers,
                    # and local variables inside methods, which are not part of
                    # the persisted schema.
                    if (model_brace_depth == 1 && property_line ~ /(^|[[:space:]])var[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*:/ && property_line !~ /[[:space:]]static[[:space:]]/ && property_line !~ /\{/) {
                        declaration = property_line
                        sub(/^.*var[[:space:]]+/, "", declaration)
                        property_name = declaration
                        sub(/[[:space:]]*:.*/, "", property_name)
                        property_type = declaration
                        sub(/^[^:]*:[[:space:]]*/, "", property_type)
                        sub(/[[:space:]]*=.*/, "", property_type)
                        sub(/[[:space:]]*\/\/.*$/, "", property_type)
                        gsub(/[[:space:]]/, "", property_type)

                        if (property_name != "" && property_type != "") {
                            print model_name "." property_name ":" property_type
                        }
                    }

                    brace_line = property_line
                    opening_brace_count = gsub(/\{/, "{", brace_line)
                    closing_brace_count = gsub(/\}/, "}", brace_line)
                    model_brace_depth += opening_brace_count - closing_brace_count

                    if (model_brace_depth <= 0) {
                        collecting_properties = 0
                        model_name = ""
                    }
                }
            ' "$source_file"
        done \
        | LC_ALL=C sort -u
}

check_schema() {
    if [ ! -f "$manifest_path" ]; then
        echo "error: CloudKit Production schema manifest is missing: $manifest_path" >&2
        echo "Create it only after deploying the current Development schema to Production." >&2
        exit 1
    fi

    current_schema=$(mktemp "${TMPDIR:-/tmp}/routina-cloudkit-schema.XXXXXX")
    trap 'rm -f "$current_schema"' EXIT HUP INT TERM
    generate_current_schema > "$current_schema"

    if cmp -s "$manifest_path" "$current_schema"; then
        echo "CloudKit Production schema acknowledgement is current."
        return
    fi

    deployed_field_count=$(grep -cv '^[[:space:]]*\(#\|$\)' "$manifest_path" || true)

    echo "error: CloudKit Production schema acknowledgement is stale." >&2
    if [ "$deployed_field_count" -eq 0 ]; then
        echo "No CloudKit Production schema deployment has been acknowledged for this project yet." >&2
    else
        echo "The SwiftData schema in this archive differs from the last Production deployment." >&2
    fi
    echo >&2
    echo "Before uploading this build to TestFlight:" >&2
    echo "  1. Open CloudKit Dashboard and select this container's Development environment." >&2
    echo "  2. Review and deploy the schema changes to Production." >&2
    echo "  3. After the Dashboard reports success, run:" >&2
    echo "     script/cloudkit_schema_guard.sh --acknowledge-production-deployment --yes-i-deployed-to-production" >&2
    echo "  4. Archive again." >&2
    echo >&2
    if [ "$deployed_field_count" -gt 0 ]; then
        echo "Detected contract difference:" >&2
        diff -u "$manifest_path" "$current_schema" >&2 || true
    fi
    exit 1
}

acknowledge_production_deployment() {
    if [ "${1:-}" != "--yes-i-deployed-to-production" ] || [ "$#" -ne 1 ]; then
        echo "error: Refusing to acknowledge Production without explicit confirmation." >&2
        echo "After a successful Dashboard deployment, run:" >&2
        echo "  script/cloudkit_schema_guard.sh --acknowledge-production-deployment --yes-i-deployed-to-production" >&2
        exit 2
    fi

    mkdir -p "$(dirname -- "$manifest_path")"
    pending_manifest=$(mktemp "${TMPDIR:-/tmp}/routina-cloudkit-production-schema.XXXXXX")
    trap 'rm -f "$pending_manifest"' EXIT HUP INT TERM
    generate_current_schema > "$pending_manifest"
    mv "$pending_manifest" "$manifest_path"
    trap - EXIT HUP INT TERM

    echo "Recorded the current SwiftData schema as deployed to CloudKit Production."
}

case "${1:---check}" in
    --print-current)
        [ "$#" -eq 1 ] || { usage >&2; exit 2; }
        generate_current_schema
        ;;
    --check)
        [ "$#" -eq 1 ] || { usage >&2; exit 2; }
        check_schema
        ;;
    --xcode-build)
        [ "$#" -eq 1 ] || { usage >&2; exit 2; }
        if [ "${ACTION:-}" = "install" ] || [ "${DEPLOYMENT_POSTPROCESSING:-}" = "YES" ] || [ -n "${ARCHIVE_PATH:-}" ]; then
            check_schema
        else
            echo "CloudKit Production schema check will run when this target is archived."
        fi
        ;;
    --acknowledge-production-deployment)
        shift
        acknowledge_production_deployment "$@"
        ;;
    --help|-h)
        usage
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
